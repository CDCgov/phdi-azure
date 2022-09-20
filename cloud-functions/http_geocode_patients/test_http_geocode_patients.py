import copy
from main import http_geocode_patients
from unittest import mock
from phdi_cloud_function_utils import make_response, get_sample_single_patient_bundle
import pytest


test_request_body = get_sample_single_patient_bundle()


def test_gecode_patients_bad_header():
    request = mock.Mock(headers={"Content-Type": "not-application/json"})
    actual_result = http_geocode_patients(request)
    expected_result = make_response(
        message="Header must include: 'Content-Type:application/json'.", status_code=400
    )
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


def test_geocode_patients_bad_body():
    request = mock.Mock(headers={"Content-Type": "application/json"})
    request.get_json.return_value = ""
    with pytest.raises(AttributeError):
        http_geocode_patients(request=request)


def test_geocode_patients_bad_resource_type():
    request = mock.Mock(headers={"Content-Type": "application/json"})
    body_with_wrong_resource_type = copy.deepcopy(test_request_body)
    body_with_wrong_resource_type["resourceType"] = None
    error_message = (
        "FHIR Resource Type not specified. "
        + "The request body must contain a valid FHIR bundle or resource."
    )
    request.get_json.return_value = body_with_wrong_resource_type
    expected_result = make_response(message=error_message, status_code=400)
    actual_result = http_geocode_patients(request=request)
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


@mock.patch("main.os.environ")
@mock.patch("main.geocode_patients")
@mock.patch("main.get_smartystreets_client")
@mock.patch("main.make_response")
def test_geocode_patients_good_request(
    patched_make_response,
    patched_get_geocoder,
    patched_address_standard,
    patched_os_environ,
):
    patched_os_environ.get("SMARTY_AUTH_ID").return_value = "TEST_ID"
    patched_os_environ.get("SMARTY_AUTH_TOKEN").return_value = "TEST_TOKEN"
    geocoder = mock.Mock()
    patched_get_geocoder.return_value = geocoder

    standardized_address_data = mock.Mock()
    patched_address_standard.return_value = standardized_address_data

    request = mock.Mock(headers={"Content-Type": "application/json"})

    # expected_result = make_response(status_code=200, json_payload=test_request_body)
    request.get_json.return_value = test_request_body
    http_geocode_patients(request)
    patched_address_standard.assert_called_with(
        bundle=test_request_body, client=geocoder
    )


@mock.patch("phdi_cloud_function_utils.check_for_environment_variables")
def test_geocode_patients_missing_environ_variables(patched_environ_check):
    error_message = (
        "Environment variable 'SMARTY_AUTH_ID' not set."
        + " The environment variable must be set."
    )
    expected_result = make_response(status_code=500, message=error_message)
    patched_environ_check.return_value = expected_result
    request = mock.Mock(headers={"Content-Type": "application/json"})

    actual_result = http_geocode_patients(request)

    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response
