import json
import functions_framework
import flask
import os
from google.cloud import storage
from phdi_cloud_function_utils import (
    check_for_environment_variables,
    make_response,
    validate_request_body_json,
    validate_request_header,
)


@functions_framework.http
def failed_fhir_conversion(request: flask.Request) -> flask.Response:
    """
    When the FHIR Converter fails to convert a message, this function is called.
    The output JSON, including the original input data and parameters,
    are saved to a file in a storage bucket.

    :param request: A Flask POST request object. The header must contain
        'Content-Type:application/json' and the body must be valid JSON.
    :return: Returns a flask.Response object
    """

    content_type = "application/json"
    # Validate request header.
    header_response = validate_request_header(request, content_type)
    if header_response.status_code == 400:
        return header_response

    # Validate request body.
    body_response = validate_request_body_json(request)
    if body_response.status_code == 400:
        return body_response

    # Check for the required environment variables.
    environment_check_response = check_for_environment_variables(["PHI_STORAGE_BUCKET"])
    if environment_check_response.status_code == 500:
        return environment_check_response

    # Upload file to storage bucket.
    storage_client = storage.Client()
    bucket = storage_client.bucket(os.environ.get("PHI_STORAGE_BUCKET"))
    original_filename = (
        json.loads(request.get_json()).get("original_request").get("filename")
    )
    destination_blob_name = f"failed_fhir_conversion_{original_filename}.json"
    blob = bucket.blob(destination_blob_name)

    blob.upload_from_string(data=request, content_type=content_type)

    return make_response(
        status_code=200, message=f"File uploaded to {destination_blob_name}."
    )
