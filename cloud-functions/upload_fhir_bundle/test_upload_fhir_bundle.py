from main import RequestBody, upload_fhir_bundle
from pydantic import ValidationError
import pytest
from unittest import mock
from phdi_cloud_function_utils import make_response, get_sample_multi_patient_obs_bundle


test_request_body = get_sample_multi_patient_obs_bundle()


def test_request_body():
    with pytest.raises(ValidationError):
        RequestBody(
            dataset_id=None,
            location="location",
            fhir_store_id="fhir_store_id",
            bundle={"resourceType": "Bundle"},
        )
    with pytest.raises(ValidationError):
        RequestBody(
            dataset_id="dataset_id",
            location=None,
            fhir_store_id="fhir_store_id",
            bundle={"resourceType": "Bundle"},
        )
    with pytest.raises(ValidationError):
        RequestBody(
            dataset_id="dataset_id",
            location="location",
            fhir_store_id=None,
            bundle={"resourceType": "Bundle"},
        )
    with pytest.raises(ValidationError):
        RequestBody(
            dataset_id="dataset_id",
            location="location",
            fhir_store_id="fhir_store_id",
            bundle={"resourceType": "Not-Bundle"},
        )


def test_upload_fhir_bundle_bad_header():
    request = mock.Mock(headers={"Content-Type": "not-application/json"})
    actual_result = upload_fhir_bundle(request)
    expected_result = make_response(
        status_code=400, message="Header must include: 'Content-Type:application/json'."
    )

    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code
    assert actual_result.response == expected_result.response


def test_upload_fhir_bundle_bad_body():
    request = mock.Mock(headers={"Content-Type": "application/json"})

    request.get_json.return_value = {
        "dataset_id": ["dataset_id"],
        "location": "location",
        "fhir_store_id": "fhir_store_id",
        "bundle": {"resourceType": "Bundle"},
    }

    actual_result = upload_fhir_bundle(request)
    expected_result = make_response(status_code=400, message="Unknown Error")

    assert actual_result.status == expected_result.status
    assert actual_result.status_code == expected_result.status_code


@mock.patch("main.upload_bundle_to_fhir_server")
@mock.patch("main.GcpCredentialManager")
@mock.patch("main.make_response")
def test_upload_fhir_bundle_good_request(
    patched_make_response,
    patched_credential_manager,
    patched_upload_bundle_to_fhir_server,
):
    request = mock.Mock(headers={"Content-Type": "application/json"})
    patched_credential_manager.return_value.get_project_id.return_value = "project_id"
    request.get_json.return_value = {
        "dataset_id": "dataset_id",
        "location": "location",
        "fhir_store_id": "fhir_store_id",
        "bundle": {"resourceType": "Bundle"},
    }
    base_url = "https://healthcare.googleapis.com/v1/projects"
    fhir_store_url = [
        base_url,
        "project_id",
        "locations",
        request.get_json()["location"],
        "datasets",
        request.get_json()["dataset_id"],
        "fhirStores",
        request.get_json()["fhir_store_id"],
        "fhir",
    ]

    fhir_store_url = "/".join(fhir_store_url)
    patched_make_response.return_value = mock.Mock()
    upload_fhir_bundle(request)

    patched_upload_bundle_to_fhir_server.assert_called_with(
        request.get_json()["bundle"], patched_credential_manager(), fhir_store_url
    )
