import json
import azure.functions as func
import logging

from phdi.harmonization.hl7 import (
    convert_hl7_batch_messages_to_list,
)


def main(blob: func.InputStream, queue: func.Out[str]) -> None:
    """
    When this function is triggered with a blob payload, read the new file if its
    name begins with 'source-data/', identify each individual messsage
    (ELR, VXU, or eCR) contained in the file, and publish each one to a service bus
    queue.
    :param blob: An input stream of the blob that was uploaded to the blob storage
    :param queue: A service bus queue to which each individual message will be posted
    :return: None
    """
    try:
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

        for message in messages:
            queue_message = {
                "message": message,
                "message_type": message_type,
                "root_template": root_template,
                "filename": blob.name,
            }

            queue_message = json.dumps(queue_message)
            queue.set(queue_message)

    except Exception:
        logging.exception("Exception occurred during read_source_data processing.")