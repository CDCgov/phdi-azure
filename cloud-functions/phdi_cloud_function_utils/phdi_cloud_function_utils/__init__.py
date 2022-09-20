import logging
import json
import os
from pathlib import Path
from flask import Request, Response


def make_response(
    status_code: int, message: str = None, json_payload: dict = None
) -> Response:
    """
    Make a flask.Response object given an HTTP status code and a response message
    provided as either a string or a dictionary.

    :param status_code: The HTTP status code of the response.
    :param message: A string response message, cannot be provided in addition to
        json_payload.
    :param json_payload: A dictionary to be included as a JSON response, cannot be
        provided in addition to message.
    :return: A flask.Response object containing the specified HTTP status code and
        response message.
    """
    if message is not None and json_payload is not None:
        raise ValueError(
            "Both message and json_payload were provided, but only one is allowed."
        )
    elif message is None and json_payload is None:
        raise ValueError(
            "Neither message nor json_payload were provided, but one is required."
        )

    if json_payload is not None:
        result = Response(
            response=json.dumps(json_payload),
            mimetype="application/json",
            headers={"Content-Type": "application/json"},
        )
    else:
        result = Response(response=message)
        result.response = message
    result.status_code = status_code
    return result


def validate_request_header(request: Request, content_type: str) -> Response:
    """
    Validate that the request header is of the correct type specified
    as one of the parameters.

    :param request: flask.Request that shoud contain the header being evaluated
    :param content_type: The specified content type expected to be in the header
    :return: A flask.Response object containing the error if the header is missing
        or will return a generic 200 flask.Response
    """
    if request.headers.get("Content-Type") != content_type:
        logging.error("Header must include: 'Content-Type:{}'.".format(content_type))
        return make_response(
            status_code=400,
            message="Header must include: 'Content-Type:{}'.".format(content_type),
        )

    return make_response(status_code=200, message="Validation Succeeded!")


def validate_request_body_json(request: Request) -> Response:
    """
    Validate that the request body is proper JSON

    :param request: flask.Request that shoud contain the JSON in the body
    :return: A flask.Response object containing the error if the body is not
        proper JSON or will return a generic 200 flask.Response
    """

    if request.is_json():
        return make_response(status_code=200, message="Validation Succeeded!")
    else:
        return make_response(
            status_code=400, message="Invalid request body - Invalid JSON"
        )


def validate_fhir_bundle_or_resource(request: Request) -> Response:
    """
    Validate that the request body is proper JSON with either a
    FHIR Bundle or other FHIR resource

    :param request: flask.Request that shoud contain the FHIR Bundle or resource
    as a JSON response in the body
    :return: A flask.Response object containing the error if the body is not
        proper JSON or a Bundle or resource
        otherwise will return a generic 200 flask.Response
    """

    request_json = request.get_json()
    # Check that the request body contains a FHIR bundle or resource.
    if request_json.get("resourceType") is None:
        error_message = (
            "FHIR Resource Type not specified. "
            + "The request body must contain a valid FHIR bundle or resource."
        )
        return log_error_and_generate_response(status_code=400, message=error_message)

    return make_response(status_code=200, message="Validation Succeeded!")


def check_for_environment_variables(environment_variables: list) -> Response:
    """
    Check that the environment variables are set.
    :param environment_variables: A list of environment variables to check
    :return: A flask.Response object containing the error if the environment
        variables are not set or will return a generic 200 flask.Response
    """
    for environment_variable in environment_variables:
        if os.environ.get(environment_variable) is None:
            error_message = (
                "Environment variable '{}' not set. "
                + "The environment variable must be set."
            ).format(environment_variable)
            return log_error_and_generate_response(
                status_code=500, message=error_message
            )

    return make_response(
        status_code=200, message="All environment variables were found."
    )


def log_error_and_generate_response(status_code: int, message: str) -> Response:
    """
    Given an error message and and HTTP status code log the error and create a
    flask. Response object containing the satus code and message.
    :param response: An error message to be logged and included in the
        returned flask.Response object.
    :param status: An HTTP status code to be included in the returned flask.Response
        object.
    :return: A flask.Response object containing the specified response message and HTTP
        status code.
    """
    logging.error(message)
    response = make_response(status_code=status_code, message=message)
    return response


def log_info_and_generate_response(status_code: int, message: str) -> Response:
    """
    Given an info level message and and HTTP status code log the message and create a
    flask. Response object containing the satus code and message.
    :param response: An info level message to be logged and included in the
        returned flask.Response object.
    :param status: An HTTP status code to be included in the returned flask.Response
        object.
    :return: A flask.Response object containing the specified response message and HTTP
        status code.
    """
    logging.info(message)
    response = make_response(status_code=status_code, message=message)
    return response


def get_sample_single_patient_bundle() -> dict:
    """
    Function to return a simple sample patient bundle
    for a single patient
    :return: A Json object of the single patient FHIR bundle
    """
    file_path = Path(__file__).with_name("single_patient_bundle.json")

    single_patient_bundle = json.load(file_path.open("r"))
    return single_patient_bundle


def get_sample_multi_patient_obs_bundle() -> dict:
    """
    Function to return a simple sample patient and observation bundle
    for a multiple patients and multiple observations
    :return: A Json object of the multiple patients and observations FHIR bundle
    """
    file_path = Path(__file__).with_name("multi_patient_obs_bundle.json")
    multi_patient_obs_bundle = json.load(file_path.open("r"))
    return multi_patient_obs_bundle


def get_upload_response() -> dict:
    """
    Function to return a simple sample of a valid upload response
    for adding several resources to the FHIR Store
    :return: A Json object of the flask response of multiple resource additions to the
        FHIR Store
    """
    file_path = Path(__file__).with_name("upload_response.json")
    upload_response = json.load(file_path.open("r"))
    return upload_response
