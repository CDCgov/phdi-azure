from ReadSourceData import main as read_source_data
from unittest import mock
import json
import pytest


@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
def test_handle_batch_hl7(
    patched_batch_converter,
):
    blob = mock.MagicMock()
    blob.name = "source-data/elr/some-filename.hl7"
    blob.read.return_value = b"some-blob-contents"
    queue = mock.MagicMock()
    patched_batch_converter.return_value = ["some-message"]
    read_source_data(blob, queue)
    patched_batch_converter.assert_called()


@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
def test_publishing_initial_success(
    patched_batch_converter,
):
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

        queue_message = {
            "message": "some-message",
            "message_type": message_type,
            "root_template": root_template,
            "filename": f"source-data/{source_data_subdirectory}/some-filename.hl7",
        }
        queue_message = json.dumps(queue_message)

        read_source_data(blob, queue)
        queue.set.assert_called_with(queue_message)


@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
def test_publishing_failure(
    patched_batch_converter,
):

    blob = mock.MagicMock()
    blob.name = f"some-other-container/elr/some-filename.hl7"
    blob.read.return_value = b"some-message"
    queue = mock.MagicMock()
    patched_batch_converter.return_value = ["some-message"]

    with pytest.raises(Exception) as e:
        read_source_data(blob, queue)
        assert str(e) == "Invalid file type."
