# Execution Guide: How to run data through the Azure Starter Kit

## Set Up: User requirements
First, please confirm that you meet the following user requirements:
1. Access to an Azure resource group where the starter kit has been deployed. Access must include the following roles:
    - `Storage Blob Data Contributor` on the PHI storage account
    - `FHIR Data Contributor` on the FHIR server
2. All of the files in the [sample-data/](../sample-data/) directory have been downloaded to your computer.
    - They can be downloaded as a zip file from [this link](https://github.com/CDCgov/phdi-azure/archive/refs/heads/main.zip).


If you have not implemented the pipeline, please follow the steps in this [Implementation Guide](https://github.com/CDCgov/phdi-azure/blob/main/docs/implementation-guide.md). 

If you or your organization, have deployed the starter kit, but you do not have sufficient access please contact your organization's Azure administrator.


## How to Use: Run an Hl7v2 vaccination message through the pipeline 
### Example: VXU Sample Message 
The `sample-data/` directory contains some dummy VXU messages that can be used to test the success and failure modes of the ingestion pipeline. To start, let's use `VXU_single_messy_demo.hl7` file that has a single VXU message. The PID segment of this message (shown below) contains some dirty data:
1. The patient's name is mixed case and contains a numeric character.
2. The patient's phone number is not in a standard format.
3. The patient's address is non-standard and has not been geocoded.

```diff
PID|1|7777555^4^M11^test^MR^University Hospital^19241011^19241012|PATID7755^5^M11^test1|PATID7758^^^test5|
- doe .^ John1 ^A.
|TEST^Mother, of^L|198505101126+0215|M||2106-3^White^HL70005|
- 555 E. 3065 S.^^Salt Lake CIty^ut^84106^USA
||
- 801-540-3661^^CP
|||M^Married||4880776||||N^NOT HISPANIC OR LATINO^HL70189||N||US^United States of America^ISO3166_1||||N|||20080110015014+0315|||||||
```

If you would like, feel free to confirm that this is the case by inspecting the file directly in the text editor of your choice. Below are steps on how to run a VXU message through the pipeline.

### Overview
This how-to guide is divided into 3 sections:
1. Accessing your Azure account
2. Running data through the pipeline
3. Viewing data in the FHIR server

### Access your Azure account 
> Tip: If this is your first time running data through the pipeline, we recommend having this guide and the Azure portal open side-by-side.  
1. Open [https://portal.azure.com/](https://portal.azure.com/) in your browser and log in with your username and password.![azure-portal](./images/azure-portal.png)
1. Make sure you're logged into the account that has access to the Azure resource group you have used so far. To check, click on 'Resource groups' under the "Azure services" heading.![azure-portal-resource-groups](./images/azure-portal-resource-groups.png) 
1. Click on the name of the appropriate Azure resource group.![azure-portal-resource-group](./images/azure-portal-resource-group.png) 

### Upload and run data through the pipeline
> Tip: If you prefer, you can upload data using the [Azure Storage Explorer Tool](https://azure.microsoft.com/en-us/products/storage/storage-explorer/). We don't provide instructions for using that tool here, but the broad strokes will be the same - you'll need to upload `sample-data/VXU-V04-01_success_single.hl7` to the `source-data` container in your PHI storage account.
1. Within your `Resource group`, filter down to view only `Storage account` type resources. To do so, click on the "Type" filter, then under "Value" select the "Storage account" option. Click apply.![azure-filter-storage-accounts](./images/azure-filter-storage-accounts.png)
1. Click on the name of the PHI storage account, which is where all Protected Health Information is stored outside of the FHIR server. The precise name of the storage bucket will have the form `phdi{environment}phi{clientId}`, e.g., `phdidevphi1667849158`.![azure-select-phi-bucket](./images/azure-select-phi-bucket.png)
1. After you've clicked into the storage bucket, go to the left sidebar and under the "Data storage" header click 'Containers'. ![azure-containers](./images/azure-containers.png)
1. Click on the name of the `source-data` container.![azure-select-source-data-container](./images/azure-select-source-data-container.png)
1. Then click into the `vxu` folder.![azure-select-vxu-folder](./images/azure-select-vxu-folder.png)
1. Now we're ready to run a VXU message through the pipeline! First, click the 'Upload' button in the toolbar.![azure-upload](./images/azure-upload.png)
1. Then click 'Browse for files' and navigate to the folder on your computer where you've downloaded or forked the `sample-data/` from this GitHub repository.![azure-browse](./images/azure-browse.png)     
1. Select the `VXU-V04-01_success_single.hl7` file to upload this file into the `source-data/vxu/` directory of your PHI bucket.![azure-upload-file](./images/azure-upload-file.png)    

     > Note: because the ingestion pipeline is event-driven, simply uploading the file is all that is required to trigger the pipeline. There is an event listener monitoring the PHI bucket for file creation events.

### Viewing the pipeline run

1. Congrats! You've run a VXU message through the pipeline. To check that the pipeline has executed, go to the search bar in the Azure Portal, and search for `Data factories`. Click on the 'Data factories' option in the search dropdown.![azure-search-data-factories](./images/azure-search-data-factories.png)
1. Click on the name of your data factory, which will be titled `phdi-{environment}-data-factory-{client-id}`.![azure-select-ingestion-pipeline](./images/azure-select-ingestion-pipeline.png)
1. Launch the Data Factory Studio by clicking the blue button that says `Launch studio` (Note: this will open a new tab)![azure-data-factory-launch-studio](./images/azure-data-factory-launch-studio.png)
1. In the left sidebar, click on the the 'Monitor' tab (radar icon, 3rd from top) to view the 'Pipeline runs'.![azure-pipeline-select-monitor](./images/azure-pipeline-select-monitor.png)
1. Click the name of your pipeline run, which will be titled `phdi-{environment}-ingestion`. If you see multiple pipline runs with this name, select the most recently run pipeline (the pipeline with the most recent run start time).![azure-ingestion-single-execution](./images/azure-ingestion-single-execution.png) 
     > Note: this pipeline may still have an "In progress" status.

1. After clicking into your pipeline run, you should see a diagram showing the steps of the pipeline in addition to a table with information about each activity. We should now see that the ingestion pipeline has processed one message successfully..![azure-pipeline-diagram](./images/azure-pipeline-diagram.png)

### View data in the FHIR server
1. Now we can view the cleaned and enriched data in the FHIR server using Cloud Shell. To do so, open another window/tab and open [https://shell.azure.com](https://shell.azure.com).
     > **Instructions for first time users**: 
     
     > A pop up will appear asking you to select either the Bash or PowerShell option. Select the Bash option.![azure-cloud-select-bash](./images/azure-cloud-select-bash.png) 
     
     > A second pop up will appear stating "You have no storage mounted". Click "Create storage".![azure-cloud-create-storage](./images/azure-cloud-create-storage.png)
1. Confirm that you're in Bash mode by checking that the dropdown in the top left under the "Microsoft Azure" header has "Bash" selected.![azure-cloud-shell](./images/azure-cloud-shell.png)
1. Then in the terminal, type the command `az login` and press enter.![azure-cloud-shell-login](./images/azure-cloud-shell-login.png)![azure-device-login](./images/azure-device-login.png)
1. Copy the authentication code provided.![azure-cloud-copy-code](./images/azure-cloud-copy-code)
1. then click the device login link, and paste in the authentication code. Then follow the prompts to complete login.
1. Now you'll need to update the URL in the code with the URL of your FHIR server. To get the URL of your FHIR server, go back to the tab with [portal.azure.com](portal.azure.com) open. Then in the search bar, type in "Azure API for FHIR" and select this option in the search dropdown.
1. On the Azure API for FHIR page, you should see your FHIR server which will have the following form: `{environment}fhir{client-id}`. Click on the name of your FHIR server. Within this sidebar, copy the name of your FHIR server (`{environment}fhir{client-id}`).
1. To search for a patient named John Doe, go back to the tab with Cloud Shell open. Copy and paste this command into the terminal and replace the "{FHIR_SERVER}" text with your FHIR server name you copied in the previous step:<pre>
token=$(az account get-access-token --resource=https://<b>{FHIR_SERVER}</b>.azurehealthcareapis.com --query accessToken --output tsv)</pre>
Hit enter to run this command.
1. Then, copy and paste this command into the terminal and replace the "{FHIR_SERVER}" text with your FHIR server name: <pre>RESPONSE=$(curl -X GET --header "Authorization: Bearer $token" "https://<b>{FHIR_SERVER}</b>.azurehealthcareapis.comPatient?family=DOE&given=JOHN)"</pre>
Hit enter to run this command.
1. Finally, copy and paste this command into the terminal: <pre>echo $RESPONSE | jq</pre> Hit enter to run this command.
![azure-fhir-api-response](./images/azure-fhir-api-response.png)

### Run another VXU message through the pipeline
1. The table below describes the contents and expected ingestion pipeline behavior for each of the other files included in `sample-data/`. Choose another message to run through the pipeline below to see what an expected error or a batch message will look like. 
1. Return to [https://portal.azure.com/](https://portal.azure.com/) and repeat steps 1-6 in the ["Upload and run data through the pipeline" section](#upload-and-run-data-through-the-pipeline)! 
1. Repeat steps 1-7 in the ["Viewing the pipeline run" section](#viewing-the-pipeline-run).
1. If your pipeline run contains a failure, follow the ["Viewing pipeline failures in ADF" section](#viewing-pipeline-failures-in-adf) to see why the failure occurred.

| Test File | File Contents | Expected Outcome |
| --------- | --------------| ---------------- |
|VXU-V04-01_success_single.hl7| A single valid VXU message.|The ingestion pipeline will process a single message and upload it to the FHIR server.|
|VXU-V04-02_failedConversion.hl7| A single invalid VXU message that cannot be converted to FHIR.| The ingestion process will fail during the initial conversion to FHIR step. Information about the failure is written to `failed_fhir_conversion\vxu\`.
|VXU-V04-02_failedUpload.hl7| A single VXU message that converts to an invalid FHIR bundle.| The ingestion pipeline will fail during the final step when it attempts to upload the data to the FHIR server. Information about the failure is written to `failed_fhir_uploads\vxu\`.|
|VXU-V04-02_success_batch.hl7| A batch Hl7 message containing two valid VXU messages.| The ingestion pipeline is triggered twice and runs successfully to completion both times.|
|VXU-V04-03_batch_1_success_1_failConversion.hl7| A batch Hl7 message containing one valid and one invalid VXU message.| The ingestion pipeline will run twice. On one execution it successfully processes the data and uploads to the FHIR server. On the other execution it fails.|

### Viewing pipeline failures in ADF

When a pipeline run ends in failure, Azure Data Factory makes it easy to see the error that caused the failure.

1. On the `Monitor` tab in Azure Data Factory Studio (the page we opened in step 4 of the ["Viewing the pipeline run" section](#viewing-the-pipeline-run)), select the pipeline run that failed.
![azure-data-factory-failure](./images/azure-data-factory-failure.png)
1. In this view, click the button next to "Failed" on any steps that failed in the "Activity Runs" section to view the relevant error.
![azure-data-factory-error-button](./images/azure-data-factory-error-button.png)
1. The error message should provide the information you need to resolve the issue before reuploading the data for another pipeline run.
![azure-data-factory-error-details](./images/azure-data-factory-error-details.png)
