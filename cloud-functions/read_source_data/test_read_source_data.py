from main import read_source_data, log_info_and_generate_response
from unittest import mock
import json


def test_bad_cloud_event():
    cloud_event = mock.MagicMock()
    cloud_event.data.__getitem__.side_effect = AttributeError()
    actual_response = read_source_data(cloud_event)
    assert (
        actual_response.response == "Bad CloudEvent payload - 'data' attribute missing."
    )

    cloud_event = mock.MagicMock()
    cloud_event.data.__getitem__.side_effect = KeyError()
    actual_response = read_source_data(cloud_event)
    assert actual_response.response == (
        "Bad CloudEvent payload - 'name' or 'bucket' name was " "not included."
    )


def test_not_source_data():
    cloud_event = mock.MagicMock()
    cloud_event.data.__getitem__.side_effect = ["some-filename", "some-bucket"]
    actual_response = read_source_data(cloud_event)
    assert actual_response.response == (
        "some-filename was not read because it does not begin " "with 'source-data/'."
    )


def test_unknown_message():
    cloud_event = mock.MagicMock()
    cloud_event.data.__getitem__.side_effect = [
        "source-data/unknown-message-type",
        "some-bucket",
    ]
    actual_response = read_source_data(cloud_event)
    assert actual_response.response == (
        "Unknown message type: unknown-message-type. Messages "
        "should be ELR, VXU, or eCR."
    )


@mock.patch("main.pubsub_v1.PublisherClient")
@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_missing_environment_variables(
    patched_environ, patched_storage_client, patched_publisher_client
):
    patched_environ.__getitem__.side_effect = KeyError()
    cloud_event = mock.MagicMock()
    cloud_event.data.__getitem__.side_effect = [
        "source-data/elr/some-filename",
        "some-bucket",
    ]
    actual_response = read_source_data(cloud_event)
    assert actual_response.response == (
        "Missing required environment variables. Values for "
        "PROJECT_ID and TOPIC_ID must be set."
    )


@mock.patch("main.pubsub_v1.PublisherClient")
@mock.patch("main.convert_batch_messages_to_list")
@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_handle_batch_hl7(
    patched_environ,
    patched_storage_client,
    patched_batch_converter,
    patched_publisher_client,
):
    cloud_event = mock.MagicMock()
    cloud_event.data.__getitem__.side_effect = [
        "source-data/elr/some-filename",
        "some-bucket",
    ]
    patched_batch_converter.return_value = ["some-message"]
    read_source_data(cloud_event)
    patched_batch_converter.assert_called()


@mock.patch("main.pubsub_v1.PublisherClient")
@mock.patch("main.convert_batch_messages_to_list")
@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_publishing_initial_success(
    patched_environ,
    patched_storage_client,
    patched_batch_converter,
    patched_publisher_client,
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

        cloud_event = mock.MagicMock()
        cloud_event.data.__getitem__.side_effect = [
            f"source-data/{source_data_subdirectory}/some-filename",
            "some-bucket",
        ]
        patched_batch_converter.return_value = ["some-message"]

        patched_storage_client_instance = patched_storage_client.return_value
        patched_bucket = patched_storage_client_instance.get_bucket.return_value
        patched_blob = patched_bucket.blob.return_value
        patched_blob.download_as_text.return_value = "some-message"

        patched_publisher_client_instance = patched_publisher_client.return_value
        patched_publisher_client_instance.topic_path.return_value = "some-pubsub-topic"

        pubsub_message = {
            "message": "some-message",
            "message_type": message_type,
            "root_template": root_template,
            "filename": f"source-data/{source_data_subdirectory}/some-filename",
        }
        pubsub_message = json.dumps(pubsub_message).encode("utf-8")

        read_source_data(cloud_event)
        patched_publisher_client_instance.publish.assert_called_with(
            "some-pubsub-topic", pubsub_message, origin="read_source_data"
        )


@mock.patch("main.pubsub_v1.PublisherClient")
@mock.patch("main.convert_batch_messages_to_list")
@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_publishing_retry_success(
    patched_environ,
    patched_storage_client,
    patched_batch_converter,
    patched_publisher_client,
):

    cloud_event = mock.MagicMock()
    cloud_event.data.__getitem__.side_effect = [
        "source-data/elr/some-filename",
        "some-bucket",
    ]
    patched_batch_converter.return_value = ["some-message"]

    patched_storage_client_instance = patched_storage_client.return_value
    patched_bucket = patched_storage_client_instance.get_bucket.return_value
    patched_blob = patched_bucket.blob.return_value
    patched_blob.download_as_text.return_value = "some-message"

    patched_publisher_client_instance = patched_publisher_client.return_value
    patched_publisher_client_instance.topic_path.return_value = "some-pubsub-topic"
    first_future = mock.Mock()
    first_future.result.side_effect = Exception()
    second_future = mock.Mock()
    second_future.result.return_value = "some-message-id"
    patched_publisher_client_instance.publish.side_effect = [
        first_future,
        second_future,
    ]

    read_source_data(cloud_event)
    assert patched_publisher_client_instance.publish.call_count == 2
    assert not patched_blob.upload_from_string.called


@mock.patch("main.pubsub_v1.PublisherClient")
@mock.patch("main.convert_batch_messages_to_list")
@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_publishing_failure(
    patched_environ,
    patched_storage_client,
    patched_batch_converter,
    patched_publisher_client,
):

    cloud_event = mock.MagicMock()
    cloud_event.data.__getitem__.side_effect = [
        "source-data/elr/some-filename.txt",
        "some-bucket",
    ]
    patched_batch_converter.return_value = ["some-message"]

    patched_storage_client_instance = patched_storage_client.return_value
    patched_bucket = patched_storage_client_instance.get_bucket.return_value
    patched_blob = patched_bucket.blob.return_value
    patched_blob.download_as_text.return_value = "some-message"

    patched_publisher_client_instance = patched_publisher_client.return_value
    patched_publisher_client_instance.topic_path.return_value = "some-pubsub-topic"
    future = mock.Mock()
    future.result.side_effect = Exception()
    patched_publisher_client_instance.publish.side_effect = [future, future]

    read_source_data(cloud_event)
    assert patched_publisher_client_instance.publish.call_count == 2
    patched_bucket.blob.assert_called_with(
        "publishing-failures/elr/some-filename-0.txt"
    )
    patched_blob.upload_from_string.assert_called_with("some-message")


@mock.patch("main.pubsub_v1.PublisherClient")
@mock.patch("main.convert_batch_messages_to_list")
@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_read_source_data(
    patched_environ,
    patched_storage_client,
    patched_batch_converter,
    patched_publisher_client,
):

    cloud_event = mock.MagicMock()
    cloud_event.data.__getitem__.side_effect = [
        "source-data/elr/some-filename.txt",
        "some-bucket",
    ]
    patched_batch_converter.return_value = ["some-message"]

    patched_storage_client_instance = patched_storage_client.return_value
    patched_bucket = patched_storage_client_instance.get_bucket.return_value
    patched_blob = patched_bucket.blob.return_value
    patched_blob.download_as_text.return_value = "some-message"

    actual_response = read_source_data(cloud_event)
    expected_response = log_info_and_generate_response(
        200,
        (
            "Processed source-data/elr/some-filename.txt, which contained 1 "
            "messages, of which 1 were successfully published, and 0 could not be "
            "published."
        ),
    )
    assert actual_response.response == expected_response.response
    assert actual_response.status_code == expected_response.status_code
