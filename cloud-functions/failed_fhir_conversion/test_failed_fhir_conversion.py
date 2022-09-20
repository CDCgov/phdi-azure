import json
from main import failed_fhir_conversion
from unittest import mock
from phdi_cloud_function_utils import make_response


@mock.patch("main.storage.Client")
def test_failed_fhir_conversion_bad_header(mock_storage_client):
    request = mock.Mock(headers={"Content-Type": "not-application/json"})

    result = failed_fhir_conversion(request)
    expected_result = make_response(
        status_code=400, message="Header must include: 'Content-Type:application/json'."
    )
    expected_result.status_code = 400
    assert result.status == expected_result.status
    assert result.status_code == expected_result.status_code
    assert result.response == expected_result.response


@mock.patch("main.storage.Client")
def test_failed_fhir_conversion_bad_body(mock_storage_client):
    request = mock.Mock(headers={"Content-Type": "application/json"})
    request.is_json.return_value = False
    result = failed_fhir_conversion(request=request)
    expected_result = make_response(
        status_code=400, message="Invalid request body - Invalid JSON"
    )
    expected_result.status_code = 400
    assert result.status == expected_result.status
    assert result.status_code == expected_result.status_code
    assert result.response == expected_result.response


@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_failed_fhir_conversion_missing_environment_variables(
    patched_environ, mock_storage_client
):
    request = mock.Mock(headers={"Content-Type": "application/json"})
    patched_environ.get.return_value = None
    response = failed_fhir_conversion(request)
    assert response.response == (
        "Environment variable 'PHI_STORAGE_BUCKET' not set. "
        + "The environment variable must be set."
    )


@mock.patch("main.storage.Client")
@mock.patch("main.os.environ")
def test_failed_fhir_conversion_good_request(patched_os_environ, mock_storage_client):
    patched_os_environ.get.return_value = "test_bucket"
    request = mock.Mock(headers={"Content-Type": "application/json"})

    expected_result = "File uploaded to failed_fhir_conversion_test_hash.hl7.json."
    request.get_json.return_value = json.dumps(
        {
            "args": "dotnet run --project /build/FHIR-Converter/src/Microsoft"
            + ".Health.Fhir.Liquid.Converter.Tool convert -- --TemplateDirectory"
            + "/build/FHIR-Converter/data/Templates/Hl7v2 --RootTemplate ADT_A01"
            + "--InputDataFile /tmp/hl7v2-input.txt --OutputDataFile /tmp/output.json",
            "returncode": 255,
            "stdout": "",
            "stderr": "Process failed: The input data could not be parsed correctly: "
            + "The HL7 v2 message is invalid, first segment id = bad.\n",
            "original_request": {
                "input_data": "bad data",
                "input_type": "hl7v2",
                "filename": "test_hash.hl7",
                "root_template": "ADT_A01",
            },
        }
    )
    actual_result = failed_fhir_conversion(request)

    assert actual_result.get_data().decode("utf-8") == expected_result
