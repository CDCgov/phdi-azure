import functions_framework
import flask
import os
from datetime import datetime
from google.cloud import storage
from phdi_cloud_function_utils import (
    check_for_environment_variables,
    make_response,
    validate_request_header,
    validate_fhir_bundle_or_resource,
)


def get_timestamp():
    return datetime.now().isoformat()


@functions_framework.http
def failed_fhir_upload(request: flask.Request) -> flask.Response:
    """
    When a FHIR bundle fails to be uploaded to the FHIR server, this
    function is called. The FHIR bundle along with a reason for failure
    will be uploaded to a storage bucket.

    :param request: A Flask POST request object. The header must contain
        'Content-Type:application/json' and the body must contain a valid
        FHIR bundle.
    :return: Returns a flask.Response object
    """

    content_type = "application/json"
    # Validate request header.
    header_response = validate_request_header(request, content_type)

    if header_response.status_code == 400:
        return header_response

    # Check that the request body contains a FHIR bundle or resource.
    body_response = validate_fhir_bundle_or_resource(request)
    if body_response.status_code == 400:
        return body_response

    # Check for the required environment variables.
    environment_check_response = check_for_environment_variables(["PHI_STORAGE_BUCKET"])
    if environment_check_response.status_code == 500:
        return environment_check_response

    # Check to see if any entries in the FHIR bundle failed to upload.
    # If so, upload the FHIR bundle to a storage bucket.
    fhir_bundle = request.get_json()
    failed_entries = [
        entry
        for entry in fhir_bundle["entry"]
        if entry["response"]["status"] != "201 Created"
    ]
    if failed_entries:
        timestamp = get_timestamp()
        data = {
            "entry": failed_entries,
            "resourceType": "Bundle",
            "type": "transaction-response",
        }
        storage_client = storage.Client()
        bucket = storage_client.bucket(os.environ.get("PHI_STORAGE_BUCKET"))
        destination_blob_name = f"failed_fhir_upload_{timestamp}.json"
        blob = bucket.blob(destination_blob_name)
        blob.upload_from_string(data=data, content_type=content_type)

        return make_response(
            status_code=200,
            message=f"Failed entries found. File uploaded to {destination_blob_name}.",
        )

    return make_response(status_code=200, message="No failed entries found!")
