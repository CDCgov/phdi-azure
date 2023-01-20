# Getting Started

This is a guide for getting started as a user and/or developer with the PHDI Azure Quickstart Kit. You'll find resources on how to setup a local development environment, how these tools are deployed, and more.

- [Getting Started](#getting-started)
  - [Architecture](#architecture)
    - [Azure Blob Storage: Storage](#azure-blob-storage-storage)
        - [PHI (Protected Health Information) Storage Account](#phi-protected-health-information-storage-account)
        - [Azure Functions Storage Account](#azure-functions-storage-account)
        - [Terraform State Storage Account](#terraform-state-storage-account)
    - [Azure Data Factory (ADF): Orchestration](#azure-data-factory-adf-orchestration)
    - [Azure Functions: Cloud-native event-driven processing](#azure-functions-cloud-native-event-driven-processing)
    - [Azure Project Configuration](#azure-project-configuration)
  - [Infrastructure as Code (IaC)](#infrastructure-as-code-iac)
    - [Running Terraform Locally](#running-terraform-locally)
  - [Continuous Integration and Continuous Deployment (CI/CD)](#continuous-integration-and-continuous-deployment-cicd)
    - [Continuous Integration (CI)](#continuous-integration-ci)
    - [Continuous Deployment (CD)](#continuous-deployment-cd)

## Architecture

Source data is stored in Azure using [Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/). When new data is written to this blob store the `read-source-data` [Azure Function](https://learn.microsoft.com/en-us/azure/data-factory/control-flow-azure-function-activity) is triggered. This function simply reads the new data from blob storage and passes it, along with some metadata, to the ingestion pipeline for further processing. The ingestion pipeline is implemented in [Azure Data Factory (ADF)](https://learn.microsoft.com/en-us/azure/data-factory/) and is responsible for data cleaning, standardization, enrichment, record linkage and finally uploading data to a FHIR server ([Azure API for FHIR](https://learn.microsoft.com/en-us/azure/healthcare-apis/azure-api-for-fhir/overview)). Each step of the pipeline, orchestrated by ADF, is simply a REST API call to indepent containerized microservices (AKA Building Blocks) developed by PHDI ([available here](https://github.com/orgs/CDCgov/packages?repo_name=phdi)). These services are deployed in Azure as [Azure Container Apps (ACA)](https://learn.microsoft.com/en-us/azure/container-apps/). Each endpoint on a service performs a single function, or step in a pipeline (e.g patient name standardization), and returns the processed data back to the data factory where it is passed on to the next service. Endpoints that perform related functions (e.g. name standardization and phone number standardization) are provided by a single service. Ingested data may be accessed via the FHIR server's API ([HL7 docs](https://hl7.org/fhir/http.html), [Azure docs](https://learn.microsoft.com/en-us/azure/healthcare-apis/azure-api-for-fhir/overview-of-search)), or the tabulation service. When called, the tabulation service with extract data, in tabular form according to a user-defined schema, from the FHIR server and writen to flat files. This entire architecture is show in the diagram below.


![Architecture Diagram](./images/azure-starter-kit-arch.drawio.png)

### Azure Blob Storage: Storage

All data for the starter kit in Azure is stored in [Azure Storage Accounts](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview), primarily in [Azure Blob Storage Containers](https://learn.microsoft.com/en-us/azure/storage/blobs/). Currently the starter kit includes the three storage accounts described below.

#### PHI (Protected Health Information) Storage Account

The PHI storage account is the primary storage account of the starter kit. All PHI/PII data stored outside of the FHIR server is stored in this account. The account has the following three containers:
1. `source-data`
2. `fhir-conversion-failures`
3. `fhir-upload-failures`

Data in the form it is originally recieved by the starter kit is stored in the `source-data`. In practice the pipeline has two failure modes, on occasion issues will be encountered converting source data to FHIR at the beginning of the ingestion pipeline and uploading data to the FHIR server at the end of the ingestion pipeline. In the event of FHIR conversion and upload failures the data that could not be converted or uploaded is written to the appropriate container (`fhir-conversion-failures`, or `fhir-upload-failures`) as a JSON blob along with logging describing the specific failure. Additionally, each of these three containers contains a subdirectory for each type of public health data the starter kit can process. A new ELR message for the pipeline to ingest would be written to `source-data/elr/` while an eCR message that failed to be uploaded to the FHIR server would be written to `fhir-upload-failures/ecr`. The overall directory structure for the PHI storage account is shown below.

```bash
phdi{ENV NAME}phi{UNIX TIME OF CREATION}/
└── source-data/
    ├── elr/
    ├── ecr/
    └── vxu/
└── fhir-conversion-failures/
    ├── elr/
    ├── ecr/
    └── vxu/
└── fhir-upload-failures/
    ├── elr/
    ├── ecr/
    └── vxu/
```

#### Azure Functions Storage Account
The second storage account in the starter kit is the Azure Functions Storage Account. This account is used for all storage need related to Azure Functions. The starter kit currently creates a containers in this account to store the source code for the [`read-source-data](#azure-functions) function.

#### Terraform State Storage Account
The third and final storage account in the starter kit in the Terraform State Storage Account. This account is shared across all deployed environments of the starter kit (dev, prod, QA, etc..) and is used to store the Terraform state of each environment. For more information Terraform state please refer to the [Infrastructure as Code (IaC)](#infrastructure-as-code-iac) section of this doc.

### Azure Data Factory (ADF): Orchestration
We use [Azure Data Factory (ADF)](https://learn.microsoft.com/en-us/azure/data-factory/control-flow-azure-function-activity) to define processes that require the use of multiple Building Blocks. These data flows can be developed using [The Azure Function Ativity UI](https://learn.microsoft.com/en-us/azure/data-factory/control-flow-azure-function-activity#create-an-azure-function-activity-with-ui). However for best Infrastructure as Code (IaC) best practices we recommend deploying deploying ADF pipelines in production from JSON configuation files. This allows consistency and reproducibility between deployments and the use of source control to track changes to the piple over time. The JSON configuration file for the ingestion pipeline is available in [`/terraform/modules/data_factory/ingestion-pipeline.json`](../terraform/modules/data_factory/ingestion-pipeline.json) in this repository.

The table below summarizes these pipelines, their purposes, triggers, inputs, steps, and results:

| Name | Purpose | Trigger | Input | Steps | Result |
| ---- | ------- | ------- | ----- | ----- | ------ |
| ingestion-pipeline | Read source data (HL7v2 and CCDA), convert to FHIR, standardize, and upload to a FHIR server | File creation in storage container via Eventarc trigger | New file name and its storage container | 1. convert-to-fhir<br>2.standardize-patient-names<br>3. standardize-patient-phone-numbers<br>4. geocode-patient-address<br>5. compute-patient-hash<br>6. upload-to-fhir-server | HL7v2 and CCDA messages are read, converted to FHIR, standardized and enriched, and uploaded to a FHIR server as they arrive in Cloud Storage. In the event that the conversion or upload steps fail the data is written to separate storage containers along with relevent logging. |

### Azure Functions: Cloud-native event-driven processing
[Azure Functions](https://learn.microsoft.com/en-us/azure/data-factory/control-flow-expression-language-functions) are Microsoft's version of serverless functions, similar to Lamabda in Amazon Web Services (AWS) and Cloud Functions in GCP. Severless functions provide a relatively simple way to run services with modest runtime duration, memory, and compute requirements in the cloud. They are considered serverless because the cloud provider, Azure in this case, abstracts away management of the underlying infrastructure from the user. The [serverless-functions/](../serverless-functions/) directory contains source code for each of our Azure Functions. We have chosen to develop the functions in Python because the [PHDI SDK](https://github.com/CDCgov/phdi-sdk) is written in Python and Azure has [strong support and documentation](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level) for developing Azure Functions with Python.

The table below summarizes these functions, their purposes, triggers, inputs, and outputs:

| Name | Language | Purpose | Trigger | Input | Output | Effect |
| ---- | -------- | ------- | ------- | ------| ------ | ------ |
| read-source-data | Python | Trigger the ingestion pipeline on blob creation events on the `source-data` container. | blob | Blob creation event | N/A | The ingestion pipeline is triggered every time new messages are written to the `source-data` container. In the case when a batch message is uploaded to `source-data` the pipeline is triggered once for every individual message in the batch. |   

### Azure Container Apps (ACA): Containerized Microservices

[Azure Container Apps (ACA)](https://learn.microsoft.com/en-us/azure/container-apps/) are one of the many ways to deploy containerized applications on Azure. We have chosen to use ACA for time being because it is simplest option in Azure for running containers that is fully-managed, serverless, and supports horozonital scaling. As the number of containerized services deployed by the starter increase we will likely move towards [Azur Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/), Azure's managed Kubernetes offering. The following containerized services are deployed via ACA.

| Service | Purpose | Documentation and Source Code |
| ------- | ------- | ----------------------------- |
| Fhir-converter | Convert Hl7v2 and C-CDA data to FHIR at the beginning of the ingestion pipeline. |  [https://github.com/CDCgov/phdi/tree/main/containers/fhir-converter](https://github.com/CDCgov/phdi/tree/main/containers/fhir-converter) |
| Ingestion | Provide endpoints for each step of the ingestion pipeline except conversion to FHIR. | [https://github.com/CDCgov/phdi/tree/main/containers/ingestion](https://github.com/CDCgov/phdi/tree/main/containers/ingestion) |
| Tabulation | Extract and tabularize data from the FHIR server according to user-defined schema. |  [https://github.com/CDCgov/phdi/tree/main/containers/tabulation](https://github.com/CDCgov/phdi/tree/main/containers/tabulation) |

### Azure Project Configuration

Unknown - TODO??

We use Azure KeyVault for sensitive information, and the "Configuration" properties of each function to store relevant variables. We tie the two together using [Azure KeyVault References](https://docs.microsoft.com/en-us/azure/app-service/app-service-key-vault-references).

You can easily download the environment variable configuration for a given function app using the azure CLI with:

```bash
cd src/FunctionApps/NAME
func azure functionapp fetch-app-settings pitest-python-functionapp --output-file local.settings.json
func settings decrypt
```

You can then further customize this file.


## Infrastructure as Code (IaC)

IaC is the practice of writing machine-readable code for infrastructure configuration. It offers numerous benefits including, allowing infrastructure to be tracked in source control, and the ability to easily create multiple identical instances our infrastructure. For more information in general about IaC this [Wikipedia page](https://en.wikipedia.org/wiki/Infrastructure_as_code) may be a good starting place. In this repository the `phdi-azure/terraform/` directory contains full coverage for all of our GCP infrastructure with HashiCorp [Terraform](https://www.terraform.io/). This directory has the following structure:

```bash
terraform/
├── modules/
│   ├── shared/
│   │   ├── data.tf
│   │   └── main.tf
│   │   └── output.tf
│   │   └── variables.tf
│   ├── implementation/
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   └── variables.tf
│   └── setup/
│       ├── main.tf
│       └── variables.tf
└── vars/
    └── skylight/
        ├── main.tf
```

The `modules/` directory contains configuration for each Azure functions required to run the pipelines defined in this repository. Resources are organized into further subdirectories by type. The `vars/` directory contains a subdirectory for each Azure environment we have deployed to. These directories are used to define configuration specific to each Azure deployment. For more information on using Terraform please refer to the [Terraform Documentation](https://www.terraform.io/docs) and [Terraform Registry](https://registry.terraform.io/). 

### Running Terraform Locally

In order to use the Terraform code in this repository on your local machine you must first install Terraform which can be done following [this guide](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform). Additionally, you will also need to authenticate with an Azure project using the Azure CLI Tools. Install Azure CLI following [this guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli). After installing this software authenticate with your Azure project by running `az login` and follow the prompts in your browser. Now you are ready run Terraform commands!

To begin using terraform:  
  1. Navigate to the directory `phdi-azure/terraform/setup`. 
  1. Run `terraform init` to initialize the setup Terraform. 
  1. Run `terraform apply` to create a storage container for storing terraform state. It will prompt you for a Project ID ??TODO?? and region/zone. Note the name of the bucket output by this command. 
  1. Navigate to the directory `phdi-azure/terraform/implementation`.
  1. TODO?? Run `terraform init` to initialize the implementation Terraform. It will prompt you for the name of a container to store Terraform's state. Enter the name of the container output in the earlier step. It will also prompt you for a Project ID and region/zone.
  1. Create a new workspace called "dev" by running `terraform workspace new dev`. 
  1. Now you can run `terraform plan` to have Terraform determine the difference between the code locally and the infrastructure currently deployed in the Azure project. Terraform will return a list of changes, resources it will create, destroy, or modify, that it would make if you chose to move forward with a deployment. After a carefull review, if these changes are acceptable you may deploy them by running `terraform apply`. Please refer to the [Terraform CLI documentation](https://www.terraform.io/cli/commands) for further information on using Terraform locally.

## Continuous Integration and Continuous Deployment (CI/CD)

We have implemented CI/CD pipelines with [GitHub Actions](https://docs.github.com/en/actions) orchestrated by [GitHub Workflows](https://docs.github.com/en/actions/using-workflows/about-workflows) found in the `phdi-azure/.github/` directory.

### Continuous Integration (CI)

The entire CI pipeline can be found in `phdi-azure/.github/test.yaml`. It runs every time a Pull Request is opened and whenever additional changes are pushed to a branch. Currently, the following steps are included in the CI pipeline:

1. Identify all directories containing an Azure Function.
2. Run the unit tests for each Azure Function.
3. Check that all Python code complies with Black and Flake8.
4. Check that all Terraform code is formated properly.

### Continuous Deployment (CD)

A separate CD pipeline is configured for each Azure environemnt we deploy to. Each of these pipelines is defined in a YAML file starting with "deploy" in the `workflows/` directory (e.g. `phdi-azure/.github/deployment.yaml`). Generally, these pipelines run every time code is merged into the `main` branch of the repository. However, additional dependencies can be specified. For example, a successful deployment to a development environment could required before deploying to a production environment proceeds. When these pipelines run they first look for differences in the infrastructure that is specified in the respository and currently deployed to a given Azure project. If differences are detected, they are resolved by making changes to Azure project to bring into alignment with the repository. In order to grant the GitHub repository permission to make these changes, follow [these instructions](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azp#github-actions) to authenticate it with Azure.