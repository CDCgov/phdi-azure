import os
import json
import azure.functions as func

from azure.mgmt.datafactory import DataFactoryManagementClient
from phdi.cloud.azure import AzureCredentialManager, AzureCloudContainerConnection
from phdi.harmonization.hl7 import (
    convert_hl7_batch_messages_to_list,
)


def main(event: func.EventGridEvent) -> None:
    """
    When this function is triggered with a blob payload, read the new file if its
    name begins with 'source-data/', identify each individual messsage
    (ELR, VXU, or eCR) contained in the file, and trigger in an Azure Data Factory
    ingestion pipeline for each of them. An exception is raised if pipeline triggering
    fails for any message.
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

    else:
        raise Exception("Invalid file type.")
    
    # Download blob contents.
    cred_manager = AzureCredentialManager(resource_location=storage_account_url)
    cloud_container_connection = AzureCloudContainerConnection(
        storage_account_url=storage_account_url, cred_manager=cred_manager
    )
    blob_contents = cloud_container_connection.download_object(
        container_name=container_name, filename=filename
    )

    # Handle batch Hl7v2 messages.
    if message_type == "hl7v2":
        messages = convert_hl7_batch_messages_to_list(blob_contents)

    else:
        messages = [blob_contents]

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
        raise Exception(
            (
                "The ingestion pipeline was not triggered for some messages in "
                f"{container_name}/{filename}". Failed messages: {failed_pipeline_executions}"
            )
        )
