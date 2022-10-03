import functions_framework
import flask
from phdi.fhir.harmonization.standardization import standardize_phones
from phdi_cloud_function_utils import (
    validate_fhir_bundle_or_resource,
    validate_request_header,
    make_response,
)


@functions_framework.http
def http_standardize_phones(request: flask.Request) -> flask.Response:
    """Via an HTTP Request from Google Cloud Functions:
    Given a FHIR bundle or a FHIR resource, standardize all phone
    numbers contained in any resources in the input data.
    Standardization is done according to the underlying
    standardize_phone function in phdi.harmonization, so for more
    information on country-coding and parsing, see the relevant
    docstring.
    :param request: A Flask POST request object. The header must contain
        'Content-Type:application/json' and the body must contain a valid
        FHIR bundle.
    :return flask.Response: A Flask response that contains The bundle or resource
        with phone numbers are standardized
    """

    content_type = "application/json"
    # Validate request header.
    header_response = validate_request_header(request, content_type)

    # Check that the request body contains a FHIR bundle or resource.
    if header_response.status_code == 400:
        return header_response

    body_response = validate_fhir_bundle_or_resource(request)

    if body_response.status_code != 400:
        # Perform the phone standardization
        request_json = request.get_json(silent=False)
        # breakpoint()
        body_response = make_response(
            status_code=200, json_payload=standardize_phones(request_json)
        )

    return body_response
