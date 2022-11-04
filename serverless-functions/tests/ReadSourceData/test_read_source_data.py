from ReadSourceData import main as read_source_data
from unittest import mock
import pytest


@mock.patch("ReadSourceData.requests")
@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
def test_handle_batch_hl7(patched_batch_converter, patched_os, patched_requests):
    patched_os.environ = {
        "SUBSCRIPTION_ID": "some-subscription-id",
        "RESOURCE_GROUP_NAME": "some-resource-group",
        "FACTORY_NAME": "some-adf",
        "PIPELINE_NAME": "some-pipeline",
    }

    good_response = mock.Mock()
    good_response.status_code = 200
    patched_requests.post.return_value = good_response

    blob = mock.MagicMock()
    blob.name = "source-data/elr/some-filename.hl7"
    blob.read.return_value = b"some-blob-contents"

    patched_batch_converter.return_value = ["some-message"]

    read_source_data(blob)
    patched_batch_converter.assert_called()


@mock.patch("ReadSourceData.requests")
@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
def test_pipeline_trigger_success(
    patched_batch_converter, patched_os, patched_requests
):
    patched_os.environ = {
        "SUBSCRIPTION_ID": "some-subscription-id",
        "RESOURCE_GROUP_NAME": "some-resource-group",
        "FACTORY_NAME": "some-adf",
        "PIPELINE_NAME": "some-pipeline",
    }

    good_response = mock.Mock()
    good_response.status_code = 200
    patched_requests.post.return_value = good_response

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

        blob = mock.MagicMock()
        blob.name = f"source-data/{source_data_subdirectory}/some-filename.hl7"
        blob.read.return_value = b"some-message"
        queue = mock.MagicMock()
        patched_batch_converter.return_value = ["some-message"]

        adf_url = (
            "https://management.azure.com/subscriptions/"
            f"{patched_os.environ['SUBSCRIPTION_ID']}/resourceGroups/"
            f"{patched_os.environ['RESOURCE_GROUP_NAME']}/providers/Microsoft"
            f".DataFactory/factories/{patched_os.environ['FACTORY_NAME']}/pipelines/"
            f"{patched_os.environ['PIPELINE_NAME']}/createRun?api-version=2018-06-01"
        )

        parameters = {
            "message": "some-message",
            "message_type": message_type,
            "root_template": root_template,
            "filename": f"source-data/{source_data_subdirectory}/some-filename.hl7",
        }

        read_source_data(blob)
        patched_requests.post.assert_called_with(url=adf_url, json=parameters)


@mock.patch("ReadSourceData.requests")
@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
def test_publishing_failure(patched_batch_converter, patched_os, patched_requests):

    patched_os.environ = {
        "SUBSCRIPTION_ID": "some-subscription-id",
        "RESOURCE_GROUP_NAME": "some-resource-group",
        "FACTORY_NAME": "some-adf",
        "PIPELINE_NAME": "some-pipeline",
    }

    bad_response = mock.Mock()
    bad_response.status_code = 400
    patched_requests.post.return_value = bad_response

    blob = mock.MagicMock()
    blob.name = "source-data/elr/some-filename.hl7"
    blob.read.return_value = b"some-blob-contents"

    patched_batch_converter.return_value = ["some-message"]

    with pytest.raises(Exception) as e:
        read_source_data(blob)
        assert str(e) == (
            "The ingestion pipeline was not triggered for some messages in "
            f"{blob.name}."
        )
