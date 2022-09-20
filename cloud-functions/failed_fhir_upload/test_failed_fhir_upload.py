import copy
import pytest
from main import failed_fhir_upload
from unittest import mock
from phdi_cloud_function_utils import make_response, get_upload_response

test_request_body = get_upload_response()


@mock.patch("main.storage.Client")
def test_failed_fhir_upload_bad_header(mock_storage_client):
    request = mock.Mock(headers={"Content-Type": "not-application/json"})

    actual_result = failed_fhir_upload(request)
    expected_result = make_response(
        status_code=400, message="Header must include: 'Content-Type:application/json'."
    )
    expected_result.status_code = 400
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


def test_failed_fhir_upload_bad_body():
    request = mock.Mock(headers={"Content-Type": "application/json"})
    request.get_json.return_value = ""
    with pytest.raises(AttributeError):
        failed_fhir_upload(request=request)


def test_failed_fhir_upload_bad_resource_type():
    request = mock.Mock(headers={"Content-Type": "application/json"})
    body_with_wrong_resource_type = copy.deepcopy(test_request_body)
    body_with_wrong_resource_type["resourceType"] = None
    error_message = (
        "FHIR Resource Type not specified. "
        + "The request body must contain a valid FHIR bundle or resource."
    )
    request.get_json.return_value = body_with_wrong_resource_type
    expected_result = make_response(status_code=400, message=error_message)
    actual_result = failed_fhir_upload(request=request)
    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_failed_fhir_upload_missing_environment_variables(
    patched_environ, mock_storage_client
):
    request = mock.Mock(headers={"Content-Type": "application/json"})
    request.get_json.return_value = test_request_body
    patched_environ.get.return_value = None
    actual_response = failed_fhir_upload(request)
    assert actual_response.response == (
        "Environment variable 'PHI_STORAGE_BUCKET' not set. "
        + "The environment variable must be set."
    )


@mock.patch("main.get_timestamp")
@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_failed_fhir_upload_good_request_with_failed_entries(
    patched_os_environ, mock_storage_client, mock_get_timestamp
):
    patched_os_environ.get.return_value = "test_bucket"
    mock_get_timestamp.return_value = "2022-01-01T00:00:00"
    request = mock.Mock(headers={"Content-Type": "application/json"})

    expected_result = (
        "Failed entries found. "
        + "File uploaded to failed_fhir_upload_2022-01-01T00:00:00.json."
    )
    request_with_failed_entries = copy.deepcopy(test_request_body)
    request_with_failed_entries["entry"][0]["response"]["status"] = "400 Bad Request"
    request.get_json.return_value = request_with_failed_entries
    actual_result = failed_fhir_upload(request)

    assert actual_result.get_data().decode("utf-8") == expected_result


@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_failed_fhir_upload_good_request_without_failed_entries(
    patched_os_environ, mock_storage_client
):
    patched_os_environ.get.return_value = "test_bucket"
    request = mock.Mock(headers={"Content-Type": "application/json"})

    expected_result = "No failed entries found!"
    request.get_json.return_value = test_request_body
    actual_result = failed_fhir_upload(request)

    assert actual_result.get_data().decode("utf-8") == expected_result
