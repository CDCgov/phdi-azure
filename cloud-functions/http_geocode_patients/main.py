import os
import functions_framework
import flask
from phdi.geo import get_smartystreets_client, geocode_patients
from phdi_cloud_function_utils import (
    validate_fhir_bundle_or_resource,
    validate_request_header,
    make_response,
    check_for_environment_variables,
    log_error_and_generate_response,
)


@functions_framework.http
def http_geocode_patients(request: flask.Request) -> flask.Response:
    """
    Given a FHIR bundle and a SmartyStreets client, geocode all patient addresses
    across all patient resources in the bundle.

    :param request: A Flask POST request object. The header must contain
        'Content-Type:application/json' and the body must contain a valid
        FHIR bundle.
    :return flask.Response: A Flask response that contains The bundle or resource
        with addresses appropriately geocoded
    """
    content_type = "application/json"
    # Validate request header.
    header_response = validate_request_header(request, content_type)

    if header_response.status_code == 400:
        return header_response

    # Check that the request body contains a FHIR bundle or resource
    body_response = validate_fhir_bundle_or_resource(request)
    if body_response.status_code != 400:
        # Ensure that the environment variables for the SMARTY app are set
        environment_check_response_id = check_for_environment_variables(
            ["SMARTY_AUTH_ID"]
        )
        environment_check_response_token = check_for_environment_variables(
            ["SMARTY_AUTH_TOKEN"]
        )
        if environment_check_response_id.status_code == 500:
            return environment_check_response_id
        elif environment_check_response_token.status_code == 500:
            return environment_check_response_token
        try:
            # Using the environment variable values create a SMARTY client
            geocoder = get_smartystreets_client(
                os.environ.get("SMARTY_AUTH_ID"),
                os.environ.get("SMARTY_AUTH_TOKEN"),
            )

            request_json = request.get_json(silent=False)
            # Perform the address standardization and geocoding and
            # store results in flask response
            body_response = make_response(
                status_code=200,
                json_payload=geocode_patients(bundle=request_json, client=geocoder),
            )
        except Exception as error:
            error_response = log_error_and_generate_response(
                status_code=400, message=error
            )
            return error_response

    return body_response
