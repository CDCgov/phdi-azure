import os
import json
import logging
import azure.functions as func
from time import sleep
from datetime import datetime
from azure.core.exceptions import ResourceNotFoundError
from azure.mgmt.datafactory import DataFactoryManagementClient
from phdi.cloud.azure import AzureCredentialManager, AzureCloudContainerConnection
from phdi.harmonization.hl7 import (
    convert_hl7_batch_messages_to_list,
)
from lxml import etree
from typing import Tuple, Union

MESSAGE_TO_TEMPLATE_MAP = {
    "elr": "ORU_R01",
    "vxu": "VXU_V04",
    "ecr": "EICR",
    "fhir": "",
}


def main(event: func.EventGridEvent) -> None:
    """
    When this function is triggered with a blob payload, read the new file if its
    name begins with 'source-data/', identify each individual message
    (ELR, VXU, or eCR) contained in the file, and trigger in an Azure Data Factory
    ingestion pipeline for each of them. An exception is raised if pipeline triggering
    fails for any message.
    When handling eCR data, this function looks for a related RR, and polls until it
    finds one. By default, this function polls for 10 seconds with 1 second of sleep.
    These values may be set with the environment variables: WAIT_TIME, SLEEP_TIME
    :param blob: An input stream of the blob that was uploaded to the blob storage
    :return: None
    """

    # Get blob info
    container_name = "source-data"
    blob_url = event.get_json()["url"]
    storage_account_url, filename = blob_url.split(f"/{container_name}/")

    # Determine message type and root template.
    filename_parts = filename.split("/")
    message_type = filename_parts[0]

    if message_type not in MESSAGE_TO_TEMPLATE_MAP:
        logging.warning(
            "The read source data function was triggered. We expected a file in the "
            "elr, vxu, or ecr folders, but something else was provided."
        )
        return

    if message_type == "ecr":
        if any([name for name in ["_RR", ".html"] if name in filename_parts[1]]):
            logging.info(
                "The read source data function was triggered. Processing will not "
                "continue as the file uploaded was not a currently handled type."
            )
            return

    root_template = MESSAGE_TO_TEMPLATE_MAP.get(message_type)

    # Download blob contents.
    cred_manager = AzureCredentialManager(resource_location=storage_account_url)
    cloud_container_connection = AzureCloudContainerConnection(
        storage_account_url=storage_account_url, cred_manager=cred_manager
    )
    blob_contents = cloud_container_connection.download_object(
        container_name=container_name, filename=filename
    )

    external_patient_id = None

    # Handle eICR + Reportability Response messages
    if message_type == "ecr":
        ecr = blob_contents
        wait_time = float(os.environ.get("WAIT_TIME", 10))
        sleep_time = float(os.environ.get("SLEEP_TIME", 1))

        start_time = datetime.now()
        time_elapsed = 0

        reportability_response = get_reportability_response(
            cloud_container_connection, container_name, filename
        )
        while reportability_response == "" and time_elapsed < wait_time:
            sleep(sleep_time)
            time_elapsed = (datetime.now() - start_time).seconds
            reportability_response = get_reportability_response(
                cloud_container_connection, container_name, filename
            )

        if reportability_response == "":
            # If no RR is found, check if we should continue processing the eICR and
            # trigger the pipeline.
            require_rr = os.environ.get("REQUIRE_RR", "true").lower()
            if require_rr == "true":
                require_rr = True
            elif require_rr == "false":
                require_rr = False
            else:
                error_message = (
                    "The environment variable REQUIRE_RR must be set to either 'true' "
                    "or 'false'."
                )
                logging.error(error_message)
                raise Exception(error_message)

            if require_rr:
                missing_rr_message = (
                    "A reportability response could not be found for filename "
                    f"{container_name}/{filename} after searching for {wait_time} "
                    "seconds. The ingestion pipeline was not triggered. To search "
                    "for a longer period of time, increase the value of the WAIT_TIME "
                    "environment variable (default: 10 seconds). To allow processing of"
                    " eICRs to continue without a reportability response, set the "
                    "REQUIRE_RR environment variable to 'false' (default: 'true')."
                )
                logging.error(missing_rr_message)
                raise Exception(missing_rr_message)
            else:
                missing_rr_message = (
                    "A reportability response could not be found for filename "
                    f"{container_name}/{filename} after searching for {wait_time} "
                    "seconds. The ingestion pipeline was triggered for this eICR "
                    "without inclusion of the reportability response. To search for a "
                    "longer period of time, increase the value of the WAIT_TIME "
                    "environment variable (default: 10 seconds). To prevent further "
                    "processing of eICRs to continue without a reportability response, "
                    "set the REQUIRE_RR environment variable to 'true' "
                    "(default: 'true')."
                )
                logging.warning(missing_rr_message)
        else:
            # Extract RR fields and put them in the ecr
            ecr = rr_to_ecr(reportability_response, ecr)

        messages = [ecr]

    # Handle batch Hl7v2 messages.
    elif message_type == "vxu" or message_type == "elr":
        messages = convert_hl7_batch_messages_to_list(blob_contents)

    # Handle FHIR messages.
    elif message_type == "fhir":
        fhir_bundle, external_patient_id = get_external_patient_id(blob_contents)
        messages = [fhir_bundle]

    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    resource_group_name = os.environ["RESOURCE_GROUP_NAME"]
    factory_name = os.environ["FACTORY_NAME"]
    pipeline_name = os.environ["PIPELINE_NAME"]

    adf_url = (
        "https://management.azure.com/subscriptions/"
        f"{subscription_id}/resourceGroups/"
        f"{resource_group_name}/providers/Microsoft.DataFactory/"
        f"factories/{factory_name}/pipelines/{pipeline_name}"
    )

    cred_manager = AzureCredentialManager(resource_location=adf_url)
    credentials = cred_manager.get_credential_object()
    adf_client = DataFactoryManagementClient(credentials, subscription_id)

    include_error_types = "fatal, errors"

    failed_pipeline_executions = {}
    for idx, message in enumerate(messages):
        pipeline_parameters = {
            "message": json.dumps(message),
            "message_type": message_type,
            "root_template": root_template,
            "filename": f"{container_name}/{filename}",
            "include_error_types": include_error_types,
            "external_patient_id": external_patient_id,
        }

        try:
            adf_client.pipelines.create_run(
                resource_group_name,
                factory_name,
                pipeline_name,
                parameters=pipeline_parameters,
            )
        except Exception as e:
            failed_pipeline_executions[idx] = e

    if failed_pipeline_executions != {}:
        exception_message = (
            "The ingestion pipeline was not triggered for some messages in "
        )
        f"{container_name}/{filename}. "
        f"Failed messages: {failed_pipeline_executions}"

        logging.error(exception_message)
        raise Exception(exception_message)


def get_reportability_response(
    cloud_container_connection: AzureCloudContainerConnection,
    container_name: str,
    filename: str,
) -> str:
    try:
        reportability_response = cloud_container_connection.download_object(
            container_name=container_name, filename=filename.replace("eICR", "RR")
        )
    except ResourceNotFoundError:
        reportability_response = ""

    return reportability_response


# extract rr fields and insert them into the ecr
def rr_to_ecr(rr: str, ecr: str) -> str:
    """
    Extracts relevant fields from an RR document, and inserts them into a
    given eICR document. Ensures that the eICR contains properly formatted
    RR fields, including templateId, id, code, title, effectiveTime,
    confidentialityCode, and corresponding entries; and required format tags.

    :param rr: A serialized xml format reportability response (RR) document.
    :param ecr: A serialized xml format electronic initial case report (eICR) document.
    :return: An xml format eICR document with additional fields extracted from the RR.
    """
    # add xmlns:xsi attribute if not there
    lines = ecr.splitlines()
    xsi_tag = "xmlns:xsi"
    if xsi_tag not in lines[0]:
        lines[0] = lines[0].replace(
            'xmlns="urn:hl7-org:v3"',
            'xmlns="urn:hl7-org:v3" '
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"',
        )
        ecr = "\n".join(lines)

    rr = etree.fromstring(rr)
    ecr = etree.fromstring(ecr)

    # Create the tags for elements we'll be looking for
    rr_tags = [
        "templateId",
        "id",
        "code",
        "title",
        "effectiveTime",
        "confidentialityCode",
    ]
    rr_tags = ["{urn:hl7-org:v3}" + tag for tag in rr_tags]
    rr_elements = []

    # Find root-level elements and add them to a list
    for tag in rr_tags:
        rr_elements.append(rr.find(f"./{tag}", namespaces=rr.nsmap))

    # Find the nested entry element that we need
    entry_tag = "{urn:hl7-org:v3}" + "component/structuredBody/component/section/entry"
    rr_nestedEntries = rr.findall(f"./{entry_tag}", namespaces=rr.nsmap)

    organizer_tag = "{urn:hl7-org:v3}" + "organizer"

    # For now we assume there is only one matching entry
    rr_entry = None
    for entry in rr_nestedEntries:
        if entry.attrib and "DRIV" in entry.attrib["typeCode"]:
            organizer = entry.find(f"./{organizer_tag}", namespaces=entry.nsmap)
            if (
                organizer is not None
                and "CLUSTER" in organizer.attrib["classCode"]
                and "EVN" in organizer.attrib["moodCode"]
            ):
                rr_entry = entry
                exit

    # find the status in the RR utilizing the templateid root
    # codes specified from the APHL/LAC Spec
    base_tag_for_status = (
        "{urn:hl7-org:v3}" + "component/structuredBody/component/section"
    )
    templateId_tag = "{urn:hl7-org:v3}" + "templateId"
    entry_status_tag = "{urn:hl7-org:v3}" + "entry"
    act_status_tag = "{urn:hl7-org:v3}" + "act"
    sections_for_status = rr.findall(f"./{base_tag_for_status}", namespaces=rr.nsmap)
    rr_entry_for_status_codes = None
    for status_section in sections_for_status:
        templateId = status_section.find(
            f"./{templateId_tag}", namespaces=status_section.nsmap
        )
        if (
            templateId is not None
            and "2.16.840.1.113883.10.20.15.2.2.3" in templateId.attrib["root"]
        ):
            for entry in status_section.findall(
                f"./{entry_status_tag}", namespaces=status_section.nsmap
            ):
                for act in entry.findall(f"./{act_status_tag}", namespaces=entry.nsmap):
                    entry_act_templateId = act.find(
                        f"./{templateId_tag}", namespaces=act.nsmap
                    )
                    if (
                        entry_act_templateId is not None
                        and "2.16.840.1.113883.10.20.15.2.3.29"
                        in entry_act_templateId.attrib["root"]
                    ):
                        # only anticipating one status code
                        rr_entry_for_status_codes = entry
                        exit

    # Create the section element with root-level elements
    # and entry to insert in the eICR
    ecr_section = None
    if rr_entry is not None:
        ecr_section_tag = "{urn:hl7-org:v3}" + "section"
        ecr_section = etree.Element(ecr_section_tag)
        ecr_section.extend(rr_elements)
        if rr_entry_for_status_codes is not None:
            ecr_section.append(rr_entry_for_status_codes)
        ecr_section.append(rr_entry)

        # Append the ecr section into the eCR - puts it at the end
        ecr.append(ecr_section)

    ecr = etree.tostring(ecr, encoding="unicode", method="xml")

    return ecr


def get_external_patient_id(blob_contents: str) -> Tuple[str, Union[str, None]]:
    """
    FHIR data can be uploaded to the source-data container as a plain FHIR bundle, or
    it can be uploaded as JSON object containing a FHIR bundle and an external patient
    id with the form:

    {"bundle": <FHIR bundle>, "external_patient_id": <external patient id>}.

    Given the contents of a blob read from source-data/fhir, this function returns the
    the FHIR bundle and the external patient id. In the case that the data is simply a
    FHIR bundle and no patient id has been provided a null value is returned for
    external_patient_id.

    :param blob_contents: The contents of a blob read from source-data/fhir.
    :return: A tuple containing the FHIR bundle and the external patient id of the form
        [<fhir_bundle>, <external_patient_id>]. If no external patient id is provided
        the second element of the tuple is None.
    """

    blob_contents = json.loads(blob_contents)

    get_external_patient_id = blob_contents.get("external_patient_id", None)
    fhir_bundle = blob_contents.get("bundle", blob_contents)
    fhir_bundle = json.dumps(fhir_bundle)

    return fhir_bundle, get_external_patient_id
