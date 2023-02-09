from ReadSourceData import main as read_source_data
from ReadSourceData import get_reportability_response
from azure.core.exceptions import ResourceNotFoundError
from unittest import mock
import pytest


@mock.patch("ReadSourceData.DataFactoryManagementClient")
@mock.patch("ReadSourceData.AzureCredentialManager")
@mock.patch("ReadSourceData.AzureCloudContainerConnection")
@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
def test_handle_batch_hl7(
    patched_batch_converter,
    patched_os,
    patched_cloud_container_connection,
    patched_azure_cred_manager,
    patched_adf_management_client,
):
    patched_os.environ = {
        "AZURE_SUBSCRIPTION_ID": "some-subscription-id",
        "RESOURCE_GROUP_NAME": "some-resource-group",
        "FACTORY_NAME": "some-adf",
        "PIPELINE_NAME": "some-pipeline",
    }

    good_response = mock.Mock()
    good_response.status_code = 200

    patched_azure_cred_manager.return_value.get_credentials.return_value = (
        "some-credentials"
    )

    patched_cloud_container_connection.return_value.download_object.return_value = (
        "some-blob-contents"
    )

    adf_client = mock.MagicMock()
    adf_client.pipelines.create_run.return_value = good_response
    patched_adf_management_client.return_value = adf_client

    event = mock.MagicMock()
    event.get_json.return_value = {
        "url": (
            "https://phdidevphi87b9f133.blob.core.windows.net/"
            "source-data/elr/some-filename.hl7"
        )
    }

    patched_batch_converter.return_value = ["some-message"]

    read_source_data(event)
    patched_batch_converter.assert_called()


@mock.patch("ReadSourceData.DataFactoryManagementClient")
@mock.patch("ReadSourceData.AzureCredentialManager")
@mock.patch("ReadSourceData.AzureCloudContainerConnection")
@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
def test_pipeline_trigger_success(
    patched_batch_converter,
    patched_os,
    patched_cloud_container_connection,
    patched_azure_cred_manager,
    patched_adf_management_client,
):
    patched_os.environ = {
        "AZURE_SUBSCRIPTION_ID": "some-subscription-id",
        "RESOURCE_GROUP_NAME": "some-resource-group",
        "FACTORY_NAME": "some-adf",
        "PIPELINE_NAME": "some-pipeline",
    }

    good_response = mock.Mock()
    good_response.status_code = 200
    patched_azure_cred_manager.return_value.get_credentials.return_value = (
        "some-credentials"
    )

    patched_cloud_container_connection.return_value.download_object.return_value = (
        "some-message"
    )

    adf_client = mock.MagicMock()
    adf_client.pipelines.create_run.return_value = good_response
    patched_adf_management_client.return_value = adf_client
    for source_data_subdirectory in ["elr", "vxu", "ecr"]:
        if source_data_subdirectory == "elr":
            message_type = "hl7v2"
            root_template = "ORU_R01"

        elif source_data_subdirectory == "vxu":
            message_type = "hl7v2"
            root_template = "VXU_V04"

        elif source_data_subdirectory == "ecr":
            message_type = "ccda"
            root_template = "CCD"

        event = mock.MagicMock()
        event.get_json.return_value = {
            "url": (
                "https://phdidevphi87b9f133.blob.core.windows.net/"
                f"source-data/{source_data_subdirectory}/some-filename.hl7"
            )
        }
        patched_batch_converter.return_value = ["some-message"]

        parameters = {
            "message": '"some-message"',
            "message_type": message_type,
            "root_template": root_template,
            "filename": f"source-data/{source_data_subdirectory}/some-filename.hl7",
        }

        read_source_data(event)
        adf_client.pipelines.create_run.assert_called_with(
            patched_os.environ["RESOURCE_GROUP_NAME"],
            patched_os.environ["FACTORY_NAME"],
            patched_os.environ["PIPELINE_NAME"],
            parameters=parameters,
        )


@mock.patch("ReadSourceData.DataFactoryManagementClient")
@mock.patch("ReadSourceData.AzureCredentialManager")
@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
@mock.patch("ReadSourceData.logging")
def test_publishing_failure(
    patched_logging,
    patched_batch_converter,
    patched_os,
    patched_azure_cred_manager,
    patched_adf_management_client,
):
    patched_os.environ = {
        "AZURE_SUBSCRIPTION_ID": "some-subscription-id",
        "RESOURCE_GROUP_NAME": "some-resource-group",
        "FACTORY_NAME": "some-adf",
        "PIPELINE_NAME": "some-pipeline",
    }

    bad_response = mock.Mock()
    bad_response.status_code = 400
    patched_azure_cred_manager.return_value.get_credentials.return_value = (
        "some-credentials"
    )

    adf_client = mock.MagicMock()
    adf_client.pipelines.create_run.return_value = bad_response
    patched_adf_management_client.return_value = adf_client

    blob = mock.MagicMock()
    blob.name = "source-data/elr/some-filename.hl7"
    blob.read.return_value = b"some-blob-contents"

    patched_batch_converter.return_value = ["some-message"]

    with pytest.raises(Exception) as e:
        read_source_data(blob)
        error_message = "The ingestion pipeline was not triggered for some messages in "
        f"{blob.name}."
        patched_logging.error.assert_called_with(error_message)
        assert str(e) == (error_message)


def test_get_reportability_response_success():
    cloud_container_connection = mock.Mock()
    cloud_container_connection.download_object.return_value = "rr contents"
    container_name = "ecr"
    filename = "source-data/ecr/12345eICR.html"

    assert (
        get_reportability_response(cloud_container_connection, container_name, filename)
        == "rr contents"
    )


def test_get_reportability_response_failure():
    cloud_container_connection = mock.Mock()
    cloud_container_connection.download_object.side_effect = ResourceNotFoundError
    container_name = "ecr"
    filename = "source-data/ecr/12345eICR.html"

    assert (
        get_reportability_response(cloud_container_connection, container_name, filename)
        == ""
    )


@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.AzureCredentialManager")
@mock.patch("ReadSourceData.AzureCloudContainerConnection")
@mock.patch("ReadSourceData.get_reportability_response")
@mock.patch("ReadSourceData.logging")
def test_handle_ecr_with_no_rr(
    patched_logging,
    patched_get_reportability_response,
    patched_cloud_container_connection,
    patched_azure_cred_manager,
    patched_os,
):
    patched_os.environ = {"WAIT_TIME": 0.1, "SLEEP_TIME": 0.05}
    patched_azure_cred_manager.return_value.get_credentials.return_value = (
        "some-credentials"
    )

    patched_cloud_container_connection.return_value.download_object.return_value = (
        "some-message"
    )

    patched_get_reportability_response.return_value = ""

    event = mock.MagicMock()
    event.get_json.return_value = {
        "url": (
            "https://phdidevphi87b9f133.blob.core.windows.net/"
            "source-data/ecr/12345eICR.xml"
        )
    }

    blob = mock.MagicMock()
    blob.name = "source-data/ecr/12345eICR.xml"
    blob.read.return_value = b"some-blob-contents"

    warning_message = (
        "The ingestion pipeline was not triggered for this eCR, "
        "because a reportability response was not found for filename "
        f"{blob.name}."
    )

    read_source_data(event)
    patched_logging.warning.assert_called_with(warning_message)
