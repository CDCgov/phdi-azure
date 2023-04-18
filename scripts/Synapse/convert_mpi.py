# This file converts a parquet file of patient data into tuples. Each row of patient
# data is returned a tuple of (iris_id, fhir_bundle)
from phdi.linkage.seed import convert_to_patient_fhir_resources
import pyarrow.parquet as pq
import pyarrow as pa
from azure.identity import ManagedIdentityCredential
from azure.storage.filedatalake import DataLakeFileClient
from azure.core.credentials import AccessToken
import time


# Set up authentication
class spoof_token:
    def get_token(*args, **kwargs):
        return AccessToken(
            token=mssparkutils.credentials.getToken(audience="storage"),
            expires_on=int(time.time())
            + 60 * 10,  # some random time in future;synapse doesn't document how to get
            # the actual time
        )


credential = ManagedIdentityCredential()
credential._credential = (
    spoof_token()
)  # monkey-patch the contents of the private `_credential`
# Create a file client for your ADLS Gen2 account
# abfss://source-data@phdidevphi9d194c64.dfs.core.windows.net/vxu/VXU-V04-01_success_single.hl7
account_name = "phdidevphi9d194c64"
file_system_name = "source-data"
file_path = "vxu/VXU-V04-01_success_single.hl7"
file_client = DataLakeFileClient(
    account_url=f"https://{account_name}.dfs.core.windows.net",
    file_system_name=file_system_name,
    file_path=file_path,
    credential=credential,
)
# Read the file contents
download = file_client.download_file()
contents = download.readall()
# Print the file contents
print(contents)


def convert(bytes):
    buffer = pa.BufferReader(bytes)
    parquet_file = pq.ParquetFile(buffer)
    converted_data = {}
    for row in parquet_file.iter_batches(batch_size=1):
        data = row.to_pylist()[0]
        iris_id, fhir_bundle = convert_to_patient_fhir_resources(data)
        converted_data[iris_id] = fhir_bundle

    return converted_data


def read_file(file_path):
    file_client = DataLakeFileClient(
        account_url=f"https://{account_name}.dfs.core.windows.net",
        file_system_name=file_system_name,
        file_path=file_path,
        credential=credential,
    )
    download = file_client.download_file()
    bytes = download.readall()
    return bytes


bytes_data = read_file(file_path)
converted_data = convert(bytes_data)
