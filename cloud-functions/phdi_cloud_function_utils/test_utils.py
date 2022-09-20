import copy
import json
from phdi_cloud_function_utils import (
    make_response,
    validate_fhir_bundle_or_resource,
    validate_request_body_json,
    validate_request_header,
    check_for_environment_variables,
    log_error_and_generate_response,
    log_info_and_generate_response,
    get_sample_single_patient_bundle,
    get_sample_multi_patient_obs_bundle,
)
from unittest import mock
import pytest
import flask

test_request_body = get_sample_single_patient_bundle()


def test_make_response():
    status_code = 200
    message = "some message"
    json_payload = {"some-key": "some-value"}

    with pytest.raises(ValueError):
        make_response(
            status_code=status_code, message=message, json_payload=json_payload
        )
    with pytest.raises(ValueError):
        make_response(status_code=status_code)

    expected_response = flask.Response()
    expected_response.response = message
    expected_response.status_code = status_code

    actual_response = make_response(status_code=status_code, message=message)
    assert actual_response.response == expected_response.response
    assert actual_response.status_code == expected_response.status_code

    expected_response = flask.Response(
        response=json.dumps(json_payload),
        mimetype="application/json",
        headers={"Content-Type": "application/json"},
    )
    expected_response.status_code = status_code

    actual_response = make_response(status_code=status_code, json_payload=json_payload)
    assert actual_response.response == expected_response.response
    assert actual_response.status_code == expected_response.status_code
    assert actual_response.mimetype == expected_response.mimetype
    assert actual_response.headers == expected_response.headers


def test_utils_bad_header():
    request = mock.Mock(headers={"Content-Type": "not-application/json"})
    expected_result = make_response(
        status_code=400,
        message="Header must include: 'Content-Type:application/json'.",
    )

    actual_result = validate_request_header(request, "application/json")
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


def test_utils_good_header():
    request = mock.Mock(headers={"Content-Type": "application/json"})
    expected_result = make_response(status_code=200, message="Validation Succeeded!")

    actual_result = validate_request_header(request, "application/json")
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


def test_utils_good_body():
    request = mock.Mock(headers={"Content-Type": "application/json"})
    request.get_json.return_value = test_request_body
    expected_result = make_response(status_code=200, message="Validation Succeeded!")
    actual_result = validate_request_body_json(request)
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


def test_utils_bad_body():
    request = mock.Mock(headers={"Content-Type": "application/json"})
    request.is_json.return_value = False
    expected_result = make_response(
        status_code=400, message="Invalid request body - Invalid JSON"
    )
    actual_result = validate_request_body_json(request)
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


def test_utils_bad_resource_type():
    mock_request = mock.Mock(headers={"Content-Type": "application/json"})
    body_with_wrong_resource_type = copy.deepcopy(test_request_body)
    body_with_wrong_resource_type["resourceType"] = None

    error_message = (
        "FHIR Resource Type not specified. "
        + "The request body must contain a valid FHIR bundle or resource."
    )
    mock_request.get_json.return_value = body_with_wrong_resource_type
    expected_result = make_response(status_code=400, message=error_message)
    actual_result = validate_fhir_bundle_or_resource(request=mock_request)
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


def test_utils_request():
    request = mock.Mock(headers={"Content-Type": "application/json"})

    expected_result = make_response(status_code=200, message="Validation Succeeded!")
    request.get_json.return_value = test_request_body
    actual_result = validate_fhir_bundle_or_resource(request)

    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


@mock.patch("os.environ")
def test_check_for_environment_variables_success(patched_environ):
    environment_variables = ["SOME-ENV-VAR"]
    patched_environ.get.return_value = "some-value"
    actual_response = check_for_environment_variables(environment_variables)
    expected_response = make_response(
        status_code=200, message="All environment variables were found."
    )
    assert actual_response.response == expected_response.response
    assert actual_response.status_code == expected_response.status_code


@mock.patch("os.environ")
def test_check_for_environment_variables_failure(patched_environ):
    environment_variables = ["SOME-ENV-VAR"]
    patched_environ.get.return_value = None
    actual_response = check_for_environment_variables(environment_variables)
    expected_response = make_response(
        status_code=500,
        message=(
            "Environment variable 'SOME-ENV-VAR' not set. "
            "The environment variable must be set."
        ),
    )
    assert actual_response.response == expected_response.response
    assert actual_response.status_code == expected_response.status_code


def test_log_info_and_generate_response():
    actual_response = log_info_and_generate_response(200, "my-response")
    expected_response = flask.Response()
    expected_response.response = "my-response"
    expected_response.status_code = 200

    assert actual_response.response == expected_response.response
    assert actual_response.status_code == expected_response.status_code


def test_log_error_and_generate_response():
    actual_response = log_error_and_generate_response(400, "my-response")
    expected_response = flask.Response()
    expected_response.response = "my-response"
    expected_response.status_code = 400

    assert actual_response.response == expected_response.response
    assert actual_response.status_code == expected_response.status_code


def test_get_single_patient_bundle():
    test_bundle = get_sample_single_patient_bundle()
    assert test_bundle is not None
    assert test_bundle.get("resourceType") is not None


def test_get_multi_patient_obs_bundle():
    test_bundle = get_sample_multi_patient_obs_bundle()
    assert test_bundle is not None
    assert test_bundle.get("resourceType") is not None


"""
def test_get_upload_response():
    test_bundle = test_get_upload_response()
    assert test_bundle is not None
    assert test_bundle.get("resourceType") is not None"""
