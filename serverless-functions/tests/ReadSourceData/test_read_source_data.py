from ReadSourceData import main as read_source_data
from ReadSourceData import get_reportability_response
from ReadSourceData import rr_to_ecr as rr_to_ecr
from azure.core.exceptions import ResourceNotFoundError
from unittest import mock
from lxml import etree
import pytest


@mock.patch("ReadSourceData.DataFactoryManagementClient")
@mock.patch("ReadSourceData.AzureCredentialManager")
@mock.patch("ReadSourceData.AzureCloudContainerConnection")
@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
def test_handle_batch_hl7(
    patched_batch_converter,
    patched_os,
    patched_cloud_container_connection,
    patched_azure_cred_manager,
    patched_adf_management_client,
):
    patched_os.environ = {
        "AZURE_SUBSCRIPTION_ID": "some-subscription-id",
        "RESOURCE_GROUP_NAME": "some-resource-group",
        "FACTORY_NAME": "some-adf",
        "PIPELINE_NAME": "some-pipeline",
    }

    good_response = mock.Mock()
    good_response.status_code = 200

    patched_azure_cred_manager.return_value.get_credentials.return_value = (
        "some-credentials"
    )

    patched_cloud_container_connection.return_value.download_object.return_value = (
        "some-blob-contents"
    )

    adf_client = mock.MagicMock()
    adf_client.pipelines.create_run.return_value = good_response
    patched_adf_management_client.return_value = adf_client

    event = mock.MagicMock()
    event.get_json.return_value = {
        "url": (
            "https://phdidevphi87b9f133.blob.core.windows.net/"
            "source-data/elr/some-filename.hl7"
        )
    }

    patched_batch_converter.return_value = ["some-message"]

    read_source_data(event)
    patched_batch_converter.assert_called()


@mock.patch("ReadSourceData.DataFactoryManagementClient")
@mock.patch("ReadSourceData.AzureCredentialManager")
@mock.patch("ReadSourceData.AzureCloudContainerConnection")
@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
def test_pipeline_trigger_success(
    patched_batch_converter,
    patched_os,
    patched_cloud_container_connection,
    patched_azure_cred_manager,
    patched_adf_management_client,
):
    patched_os.environ = {
        "AZURE_SUBSCRIPTION_ID": "some-subscription-id",
        "RESOURCE_GROUP_NAME": "some-resource-group",
        "FACTORY_NAME": "some-adf",
        "PIPELINE_NAME": "some-pipeline",
    }

    good_response = mock.Mock()
    good_response.status_code = 200
    patched_azure_cred_manager.return_value.get_credentials.return_value = (
        "some-credentials"
    )

    patched_cloud_container_connection.return_value.download_object.return_value = (
        "<some-message/>"
    )

    adf_client = mock.MagicMock()
    adf_client.pipelines.create_run.return_value = good_response
    patched_adf_management_client.return_value = adf_client
    for source_data_subdirectory in ["elr", "vxu", "ecr"]:
        if source_data_subdirectory == "elr":
            message_type = "elr"
            root_template = "ORU_R01"

        elif source_data_subdirectory == "vxu":
            message_type = "vxu"
            root_template = "VXU_V04"

        elif source_data_subdirectory == "ecr":
            message_type = "ecr"
            root_template = "EICR"

        event = mock.MagicMock()
        event.get_json.return_value = {
            "url": (
                "https://phdidevphi87b9f133.blob.core.windows.net/"
                f"source-data/{source_data_subdirectory}/some-filename.hl7"
            )
        }
        patched_batch_converter.return_value = ["<some-message/>"]

        parameters = {
            "message": '"<some-message/>"',
            "message_type": message_type,
            "root_template": root_template,
            "filename": f"source-data/{source_data_subdirectory}/some-filename.hl7",
            "include_error_types": "fatal, errors",
        }

        read_source_data(event)
        adf_client.pipelines.create_run.assert_called_with(
            patched_os.environ["RESOURCE_GROUP_NAME"],
            patched_os.environ["FACTORY_NAME"],
            patched_os.environ["PIPELINE_NAME"],
            parameters=parameters,
        )


@mock.patch("ReadSourceData.DataFactoryManagementClient")
@mock.patch("ReadSourceData.AzureCredentialManager")
@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.convert_hl7_batch_messages_to_list")
@mock.patch("ReadSourceData.logging")
def test_publishing_failure(
    patched_logging,
    patched_batch_converter,
    patched_os,
    patched_azure_cred_manager,
    patched_adf_management_client,
):
    patched_os.environ = {
        "AZURE_SUBSCRIPTION_ID": "some-subscription-id",
        "RESOURCE_GROUP_NAME": "some-resource-group",
        "FACTORY_NAME": "some-adf",
        "PIPELINE_NAME": "some-pipeline",
    }

    bad_response = mock.Mock()
    bad_response.status_code = 400
    patched_azure_cred_manager.return_value.get_credentials.return_value = (
        "some-credentials"
    )

    adf_client = mock.MagicMock()
    adf_client.pipelines.create_run.return_value = bad_response
    patched_adf_management_client.return_value = adf_client

    blob = mock.MagicMock()
    blob.name = "source-data/elr/some-filename.hl7"
    blob.read.return_value = b"some-blob-contents"

    patched_batch_converter.return_value = ["some-message"]

    with pytest.raises(Exception) as e:
        read_source_data(blob)
        error_message = "The ingestion pipeline was not triggered for some messages in "
        f"{blob.name}."
        patched_logging.error.assert_called_with(error_message)
        assert str(e) == (error_message)


def test_get_reportability_response_success():
    cloud_container_connection = mock.Mock()
    cloud_container_connection.download_object.return_value = "rr contents"
    container_name = "ecr"
    filename = "source-data/ecr/12345eICR.html"

    assert (
        get_reportability_response(cloud_container_connection, container_name, filename)
        == "rr contents"
    )


def test_get_reportability_response_failure():
    cloud_container_connection = mock.Mock()
    cloud_container_connection.download_object.side_effect = ResourceNotFoundError
    container_name = "ecr"
    filename = "source-data/ecr/12345eICR.html"

    assert (
        get_reportability_response(cloud_container_connection, container_name, filename)
        == ""
    )


@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.AzureCredentialManager")
@mock.patch("ReadSourceData.AzureCloudContainerConnection")
@mock.patch("ReadSourceData.get_reportability_response")
@mock.patch("ReadSourceData.logging")
def test_missing_rr_when_not_required(
    patched_logging,
    patched_get_reportability_response,
    patched_cloud_container_connection,
    patched_azure_cred_manager,
    patched_os,
):
    patched_os.environ = {"WAIT_TIME": 0.1, "SLEEP_TIME": 0.05, "REQUIRE_RR": "false"}
    patched_azure_cred_manager.return_value.get_credentials.return_value = (
        "some-credentials"
    )

    patched_cloud_container_connection.return_value.download_object.return_value = (
        "some-message"
    )

    patched_get_reportability_response.return_value = ""

    event = mock.MagicMock()
    event.get_json.return_value = {
        "url": (
            "https://phdidevphi87b9f133.blob.core.windows.net/"
            "source-data/ecr/12345eICR.xml"
        )
    }

    blob = mock.MagicMock()
    blob.name = "source-data/ecr/12345eICR.xml"
    blob.read.return_value = b"some-blob-contents"
    wait_time = patched_os.environ["WAIT_TIME"]
    warning_message = (
                    "A reportability response could not be found for filename "
                    f"{blob.name} after searching for {wait_time} "  
                    "seconds. The ingestion pipeline was triggered for this eICR "
                    "without inclusion of the reportability response. To search for a "
                    "longer period of time, increase the value of the WAIT_TIME "
                    "environment variable (default: 10 seconds). To prevent further "
                    "processing of eICRs to continue without a reportability response, "
                    "set the REQUIRE_RR environment variable to 'true' " 
                    "(default: 'true')."
                )

    read_source_data(event)
    patched_logging.warning.assert_called_with(warning_message)

@mock.patch("ReadSourceData.os")
@mock.patch("ReadSourceData.AzureCredentialManager")
@mock.patch("ReadSourceData.AzureCloudContainerConnection")
@mock.patch("ReadSourceData.get_reportability_response")
@mock.patch("ReadSourceData.logging")
def test_missing_rr_when_required(
    patched_logging,
    patched_get_reportability_response,
    patched_cloud_container_connection,
    patched_azure_cred_manager,
    patched_os,
):
    patched_os.environ = {"WAIT_TIME": 0.1, "SLEEP_TIME": 0.05, "REQUIRE_RR": "true"}
    patched_azure_cred_manager.return_value.get_credentials.return_value = (
        "some-credentials"
    )

    patched_cloud_container_connection.return_value.download_object.return_value = (
        "some-message"
    )

    patched_get_reportability_response.return_value = ""

    event = mock.MagicMock()
    event.get_json.return_value = {
        "url": (
            "https://phdidevphi87b9f133.blob.core.windows.net/"
            "source-data/ecr/12345eICR.xml"
        )
    }

    blob = mock.MagicMock()
    blob.name = "source-data/ecr/12345eICR.xml"
    blob.read.return_value = b"some-blob-contents"
    wait_time = patched_os.environ["WAIT_TIME"]
    error_message = (
                    "A reportability response could not be found for filename "
                    f"{blob.name} after searching for {wait_time} "  
                    "seconds. The ingestion pipeline was not triggered. To search "
                    "for a longer period of time, increase the value of the WAIT_TIME " 
                    "environment variable (default: 10 seconds). To allow processing of"
                    " eICRs to continue without a reportability response, set the "
                    "REQUIRE_RR environment variable to 'false' (default: 'true')."
                )
    with pytest.raises(Exception) as error:
        read_source_data(event)
        patched_logging.error.assert_called_with(error_message)
        assert str(error) == (error_message)

    
def test_add_rr_to_ecr():
    with open("./tests/ReadSourceData/CDA_RR.xml", "r") as f:
        rr = f.read()

    with open("./tests/ReadSourceData/CDA_eICR.xml", "r") as f:
        ecr = f.read()

    # extract rr fields, insert to ecr
    ecr = rr_to_ecr(rr, ecr)

    # confirm root tag added
    ecr_root = ecr.splitlines()[0]
    xsi_tag = "xmlns:xsi"
    assert xsi_tag in ecr_root

    # confirm new section added
    ecr = etree.fromstring(ecr)
    tag = "{urn:hl7-org:v3}" + "section"
    section = ecr.find(f"./{tag}", namespaces=ecr.nsmap)
    assert section is not None

    # confirm required elements added
    rr_tags = [
        "templateId",
        "id",
        "code",
        "title",
        "effectiveTime",
        "confidentialityCode",
        "entry",
    ]
    rr_tags = ["{urn:hl7-org:v3}" + tag for tag in rr_tags]
    for tag in rr_tags:
        element = section.find(f"./{tag}", namespaces=section.nsmap)
        assert element is not None

    # ensure that status has been pulled over
    entry_tag = "{urn:hl7-org:v3}" + "entry"
    templateId_tag = "{urn:hl7-org:v3}" + "templateId"
    code_tag = "{urn:hl7-org:v3}" + "code"
    for entry in section.find(f"./{entry_tag}", namespaces=section.nsmap):
        for temps in entry.findall(f"./{templateId_tag}", namespaces=entry.nsmap):
            status_code = entry.find(f"./{code_tag}", namespaces=entry.nsmap)
            assert temps is not None
            assert temps.attrib["root"] == "2.16.840.1.113883.10.20.15.2.3.29"
            assert "RRVS19" in status_code.attrib["code"]
