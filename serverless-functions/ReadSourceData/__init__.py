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


def main(event: func.EventGridEvent) -> None:
    """
    When this function is triggered with a blob payload, read the new file if its
    name begins with 'source-data/', identify each individual messsage
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

    # Determine data type and root template.
    filename_parts = filename.split("/")

    if filename_parts[0] == "elr":
        message_type = "hl7v2"
        root_template = "ORU_R01"

    elif filename_parts[0] == "vxu":
        message_type = "hl7v2"
        root_template = "VXU_V04"

    elif filename_parts[0] == "ecr":
        message_type = "ccda"
        root_template = "CCD"

        if any([name for name in ["RR", "html"] if name in filename_parts[1]]):
            logging.info(
                "The read source data function was triggered. Processing will not "
                "continue as the file uploaded was not a currently handled type."
            )
            return

    else:
        logging.warning(
            "The read source data function was triggered. We expected a file in the "
            "elr, vxu, or ecr folders, but something else was provided."
        )
        return

    # Download blob contents.
    cred_manager = AzureCredentialManager(resource_location=storage_account_url)
    cloud_container_connection = AzureCloudContainerConnection(
        storage_account_url=storage_account_url, cred_manager=cred_manager
    )

    # Handle eICR + Reportability Response messages
    if message_type == "ccda":
        ecr = cloud_container_connection.download_object(
            container_name=container_name, filename=filename
        )

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
            logging.warning(
                "The ingestion pipeline was not triggered for this eCR, because a "
                "reportability response was not found for filename "
                f"{container_name}/{filename}."
            )
            return

        # Extract RR fields and put them in the ecr
        ecr = rr_to_ecr(reportability_response, ecr)

        messages = [ecr]

    # Handle batch Hl7v2 messages.
    elif message_type == "hl7v2":
        blob_contents = cloud_container_connection.download_object(
            container_name=container_name, filename=filename
        )
        messages = convert_hl7_batch_messages_to_list(blob_contents)

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

    failed_pipeline_executions = {}
    for idx, message in enumerate(messages):
        pipeline_parameters = {
            "message": json.dumps(message),
            "message_type": message_type,
            "root_template": root_template,
            "filename": f"{container_name}/{filename}",
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
def rr_to_ecr(rr, ecr):
    # add xmlns:xsi attribute if not there
    lines = ecr.splitlines()
    xsi_tag = "xmlns:xsi"
    if xsi_tag not in lines[0]:
        lines[0] = lines[0].replace(
            'xmlns="urn:hl7-org:v3"',
            'xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
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

    # Create the section element with root-level elements
    # and entry to insert in the eICR
    if rr_entry is not None:
        ecr_section_tag = "{urn:hl7-org:v3}" + "section"
        ecr_section = etree.Element(ecr_section_tag)
        ecr_section.extend(rr_elements)
        ecr_section.append(rr_entry)

    # Append the ecr section into the eCR - puts it at the end
    ecr.append(ecr_section)

    ecr = etree.tostring(ecr, encoding='unicode', method='xml')

    return ecr
