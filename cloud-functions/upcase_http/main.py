import functions_framework
from google.cloud import storage


@functions_framework.http
def upcase_http(request):
    """
    A Simple HTTP Cloud Function that reads a file from a GCP bucket specified in the
    request, shifts the contents to upper case, and writes a new file with the up cased
    contents. Ultimately this function is trivial and intended for learning purposes.

    :param request: A request POSTed to this function containing a file name
    along withthe name of the GCP bucket where the file is stored.
    """
    # Step 1: Parse filename, bucket, and project from name from request.
    request_json = request.get_json(silent=True)
    request_args = request.args

    file_identifiers = {"filename": "", "bucket_name": ""}

    for identifier in file_identifiers:
        if request_json and identifier in file_identifiers:
            file_identifiers[identifier] = request_json[identifier]
        elif request_args and identifier in file_identifiers:
            file_identifiers[identifier] = request_args[identifier]

    # Step 2: Ensure we have a file name and a bucket name before continuing.
    if "" in file_identifiers.values():
        return "Please provide both a file name and a bucket name."

    # Step 3: Read file.
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(file_identifiers["bucket_name"])
    blob = bucket.blob(file_identifiers["filename"])
    file_contents = blob.download_as_text(encoding="utf-8")

    # Step 4: Write upcase file
    upcase_filename = "upcase_" + file_identifiers["filename"]
    upcase_file = bucket.blob(upcase_filename)
    upcase_contents = file_contents.upper()
    upcase_file.upload_from_string(upcase_contents)

    return f"Read {file_identifiers['filename']} from {file_identifiers['bucket_name']} and created {upcase_filename}."  # noqa
