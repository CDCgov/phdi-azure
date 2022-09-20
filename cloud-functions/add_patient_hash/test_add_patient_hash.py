import copy
from main import add_patient_hash
from unittest import mock
import pytest
from phdi_cloud_function_utils import make_response, get_sample_single_patient_bundle


test_request_body = get_sample_single_patient_bundle()


def test_add_patient_hash_bad_header():
    request = mock.Mock(headers={"Content-Type": "not-application/json"})

    actual_result = add_patient_hash(request)
    expected_result = make_response(
        status_code=400, message="Header must include: 'Content-Type:application/json'."
    )
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


def test_add_patient_hash_bad_body():
    request = mock.Mock(headers={"Content-Type": "application/json"})
    request.get_json.return_value = ""
    with pytest.raises(AttributeError):
        add_patient_hash(request=request)


def test_add_patient_hash_bad_resource_type():
    request = mock.Mock(headers={"Content-Type": "application/json"})
    body_with_wrong_resource_type = copy.deepcopy(test_request_body)
    body_with_wrong_resource_type["resourceType"] = None
    error_message = (
        "FHIR Resource Type not specified. "
        + "The request body must contain a valid FHIR bundle or resource."
    )
    request.get_json.return_value = body_with_wrong_resource_type
    expected_result = make_response(status_code=400, message=error_message)
    actual_result = add_patient_hash(request=request)
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


@mock.patch("main.os.environ")
def test_add_patient_hash_good_request(patched_os_environ):
    patched_os_environ.get.return_value = "test_hash"
    request = mock.Mock(headers={"Content-Type": "application/json"})

    expected_result = copy.deepcopy(test_request_body)
    expected_result["entry"][0]["resource"]["identifier"] = [
        {
            "system": "urn:ietf:rfc:3986",
            "use": "temp",
            "value": "699d8585efcf84d1a03eb58e84cd1c157bf7b718d9257d7436e2ff0bd14b2834",
        }
    ]
    request.get_json.return_value = test_request_body
    actual_result = add_patient_hash(request)

    assert actual_result.get_json() == expected_result


@mock.patch("phdi_cloud_function_utils.check_for_environment_variables")
def test_add_patient_hash_missing_environment(patched_environ_check):
    error_message = (
        "Environment variable 'PATIENT_HASH_SALT' not set."
        + " The environment variable must be set."
    )
    expected_result = make_response(status_code=500, message=error_message)
    patched_environ_check.return_value = expected_result

    request = mock.Mock(headers={"Content-Type": "application/json"})

    request.get_json.return_value = test_request_body
    actual_result = add_patient_hash(request)

    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response
