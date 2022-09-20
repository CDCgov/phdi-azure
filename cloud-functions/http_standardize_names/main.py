import functions_framework
import flask
from phdi.fhir.harmonization.standardization import standardize_names
from phdi_cloud_function_utils import (
    validate_fhir_bundle_or_resource,
    validate_request_header,
    make_response,
)


@functions_framework.http
def http_standardize_names(request: flask.Request) -> flask.Response:
    """Given either a FHIR bundle or a FHIR resource, transform all names
    contained in any resource in the input.  The default standardization
    behavior is our defined non-numeric, space-trimming, full
    capitalization standardization, but other modes may be specified.

    :param request: A Flask POST request object. The header must contain
        'Content-Type:application/json' and the body must contain a valid
        FHIR bundle.
    :return flask.Response: A Flask response that contains The bundle or resource
        with names standardized
    """
    content_type = "application/json"
    # Validate request header.
    header_response = validate_request_header(request, content_type)

    # Check that the request body contains a FHIR bundle or resource.
    if header_response.status_code == 400:
        return header_response

    body_response = validate_fhir_bundle_or_resource(request)
    if body_response.status_code != 400:
        request_json = request.get_json(silent=False)
        # Perform the name standardization
        body_response = make_response(
            status_code=200, json_payload=standardize_names(request_json)
        )

    return body_response
