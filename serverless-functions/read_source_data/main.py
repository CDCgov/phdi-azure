import functions_framework
import logging
from phdi.conversion import convert_batch_messages_to_list
import os
from google.cloud import pubsub_v1
from google.cloud import storage
import json
import flask
from cloudevents.http import CloudEvent
from phdi_cloud_function_utils import (
    log_error_and_generate_response,
    log_info_and_generate_response,
)


@functions_framework.cloud_event
def read_source_data(cloud_event: CloudEvent) -> flask.Response:
    """
    When this function is triggered with a CloudEvent payload read the new file if its
    name begins with 'source-data/', identify each individual messsage
    (ELR, VXU, or eCR) contained in the file, and publish each one to a GCP pubsub
    topic. PROJECT_ID and INGESTION_TOPIC must be set as environment variables
    specifying the pubsub topic to publish to and the GCP project it is located in.

    :param cloud_event: A CloudEvent object provided by GCP whenever a new file is
        written to the storage bucket containing source data to be ingested.
    :return: A flask.Response object containing a message describing the function's
        outcome and associated HTTP status code.
    """

    # Extract buck and file names.
    try:
        filename = cloud_event.data["name"]
        bucket_name = cloud_event.data["bucket"]
    except AttributeError:
        response = "Bad CloudEvent payload - 'data' attribute missing."
        response = log_error_and_generate_response(message=response, status_code="400")
        return response

    except KeyError:
        response = "Bad CloudEvent payload - 'name' or 'bucket' name was not included."
        response = log_error_and_generate_response(message=response, status_code="400")
        return response

    # Determine data type and root template.
    filename_parts = filename.split("/")
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
            response = (
                f"Unknown message type: {filename_parts[1]}. Messages should be "
                "ELR, VXU, or eCR."
            )
            response = log_error_and_generate_response(
                message=response, status_code="400"
            )
            return response
    else:
        response = (
            f"{filename} was not read because it does not begin with 'source-data/'."
        )
        response = log_info_and_generate_response(message=response, status_code="200")
        return response

    # Load environment variables.
    try:
        project_id = os.environ["PROJECT_ID"]
        ingestion_topic = os.environ["INGESTION_TOPIC"]

    except KeyError:
        response = (
            "Missing required environment variables. Values for PROJECT_ID and "
            "TOPIC_ID must be set."
        )
        response = log_error_and_generate_response(message=response, status_code="400")
        return response

    # Read file.
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(bucket_name)
    blob = bucket.blob(filename)
    file_contents = blob.download_as_text(encoding="utf-8")

    # Handle batch Hl7v2 messages.
    if message_type == "hl7v2":
        messages = convert_batch_messages_to_list(file_contents)

    else:
        messages = [file_contents]

    # Publish messages to pub/sub topic
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(project_id, ingestion_topic)
    failure_count = 0
    message_count = messages.__len__()
    for idx, message in enumerate(messages):
        pubsub_message = {
            "message": message,
            "message_type": message_type,
            "root_template": root_template,
            "filename": filename,
        }

        pubsub_message = json.dumps(pubsub_message).encode("utf-8")
        future = publisher.publish(
            topic_path, pubsub_message, origin="read_source_data"
        )
        try:
            message_id = future.result()
            logging.info(
                f"Message {idx} in {filename} was published to {topic_path} with"
                f"message ID {message_id}."
            )
        except Exception as error:
            error_message = str(error)
            logging.warning(
                f"First attempt to publish message {idx} in {filename} failed because "
                "{error_message}. Trying again..."
            )
            # Retry publishing.
            try:
                future = publisher.publish(
                    topic_path, pubsub_message, origin="read_source_data"
                )
                message_id = future.result()
                logging.info(
                    f"Message {idx} in {filename} was published to {topic_path} with "
                    f"message ID {message_id}."
                )
            # On second failure write the message to storage and continue.
            except Exception as error:
                error_message = str(error)
                logging.error(
                    f"Publishing message {idx} in {filename} failed because"
                    f"{error_message}."
                )
                failure_filename = filename.split("/")
                failure_filename[0] = "publishing-failures"
                failure_filename[-1] = (
                    ".".join(failure_filename[-1].split(".")[0:-1]) + f"-{idx}.txt"
                )
                failure_filename = "/".join(failure_filename)
                blob = bucket.blob(failure_filename)
                blob.upload_from_string(message)
                logging.info(
                    f"Message {idx} in {filename} was written to {failure_filename} in "
                    f"{bucket_name}."
                )
                failure_count += 1

    response = (
        f"Processed {filename}, which contained {message_count} messages, of which "
        f"{message_count-failure_count} were successfully published, "
        f"and {failure_count} could not be published."
    )
    response = log_info_and_generate_response(message=response, status_code="200")
    return response
