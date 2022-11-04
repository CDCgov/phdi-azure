import json
import os
import azure.functions as func
import logging
import requests

from phdi.harmonization.hl7 import (
    convert_hl7_batch_messages_to_list,
)


def main(blob: func.InputStream) -> None:
    """
    When this function is triggered with a blob payload, read the new file if its
    name begins with 'source-data/', identify each individual messsage
    (ELR, VXU, or eCR) contained in the file, and trigger in an Azure Data Factory
    ingestion pipeline for each of them. An exception is raised if pipeline triggering
    fails for any message.
    :param blob: An input stream of the blob that was uploaded to the blob storage
    :return: None
    """

    # Determine data type and root template.
    filename_parts = blob.name.split("/")
    if filename_parts[0] == "source-data":

        if filename_parts[1] == "elr":
            message_type = "hl7v2"
            root_template = "ORU_R01"

        elif filename_parts[1] == "vxu":
            message_type = "hl7v2"
            root_template = "VXU_V04"

        elif filename_parts[1] == "ecr":
            message_type = "ccda"
            root_template = "CCD"

    else:
        raise Exception("Invalid file type.")

    blob_contents = blob.read().decode("utf-8", errors="ignore")

    # Handle batch Hl7v2 messages.
    if message_type == "hl7v2":
        messages = convert_hl7_batch_messages_to_list(blob_contents)

    else:
        messages = [blob_contents]

    adf_url = (
        "https://management.azure.com/subscriptions/"
        f"{os.environ['SUBSCRIPTION_ID']}/resourceGroups/"
        f"{os.environ['RESOURCE_GROUP_NAME']}/providers/Microsoft.DataFactory/"
        f"factories/{os.environ['FACTORY_NAME']}/pipelines/"
        f"{os.environ['PIPELINE_NAME']}/createRun?api-version=2018-06-01"
    )

    failed_pipeline_executions = []
    for message in messages:
        pipeline_parameters = {
            "message": message,
            "message_type": message_type,
            "root_template": root_template,
            "filename": blob.name,
        }

        adf_response = requests.post(url=adf_url, json=pipeline_parameters)
        if adf_response.status_code != 200:
            failed_pipeline_executions.append(pipeline_parameters)

    if failed_pipeline_executions != []:
        raise Exception(
            f"The ingestion pipeline was not triggered for some messages in {blob.name}."
        )
