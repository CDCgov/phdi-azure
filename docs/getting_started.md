# Getting Started

This is a guide for getting started as a user and/or developer with the PHDI Azure Quickstart Kit. You'll find resources on how to setup a local development environment, how these tools are deployed, and more.

- [Getting Started](#getting-started)
  - [Architecture](#architecture)
    - [Azure Data Factory](#azure-data-factory)
    - [Azure Functions](#azure-functions)
    - [Azure Project Configuration](#azure-project-configuration)
  - [Local Development Environment](#local-development-environment)
    - [Hardware](#hardware)
    - [Software](#software)
      - [Overview](#overview)
      - [Installation](#installation)
    - [Developing Python Azure Functions](#developing-azure-functions)
      - [Azure Function Directory Structure](#azure-function-directory-structure)
      - [Creating a Virtual Environment](#creating-a-virtual-environment)
      - [Azure Function Dependencies](#azure-function-dependencies)
      - [Development Dependencies](#development-dependencies)
      - [Running Azure Functions Locally](#running-azure-functions-locally)
      - [Azure Function Unit Testing](#azure-function-unit-testing)
      - [Pushing to Github](#pushing-to-github)
    - [Infrastructure as Code (IaC)](#infrastructure-as-code-iac)
      - [Running Terraform Locally](#running-terraform-locally)
    - [Continuous Integration and Continuous Deployment (CI/CD)](#continuous-integration-and-continuous-deployment-cicd)
      - [Continuous Integration (CI)](#continuous-integration-ci)
      - [Continuous Deployment (CD)](#continuous-deployment-cd)

## Architecture

We store data on the Azure Platform in [Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction). ??TODO?? Data is processed in pipelines, defined as [Azure Data Factory (ADF)](https://learn.microsoft.com/en-us/azure/data-factory/), that each orchestrate a series of calls to indepent microservices (AKA Building Blocks) that we have implemented using [Azure Functions](https://learn.microsoft.com/en-us/azure/data-factory/control-flow-azure-function-activity). ??TODO?? Each service performs a single step in a pipeline (e.g patient name standardization) and returns the processed data back to the data factory where it is passed on to the next service via a POST request. The diagram below (??TODO??) describes the current version of our ingestion pipeline that converts source HL7v2 and CCDA data to FHIR, preforms some basic standardizations and enrichments, and finally uploads the data to a FHIR server.

![Architecture Diagram TODO]()

### Azure Data Factory
TODO: Still need to determine if we are going to use ADF or Azure Logic Apps (ALA)
Since PHDI Building Blocks are designed to be composable users may want to chain serveral together into pipelines. We use [Azure Data Factory (ADF)](https://learn.microsoft.com/en-us/azure/data-factory/control-flow-azure-function-activity) to define processes that require the use of multiple Building Blocks. These data flows are defined using [The Azure Function Ativity UI](https://learn.microsoft.com/en-us/azure/data-factory/control-flow-azure-function-activity#create-an-azure-function-activity-with-ui)??

The table below summarizes these pipelines, their purposes, triggers, inputs, steps, and results:

| Name | Purpose | Trigger | Input | Steps | Result |
| ---- | ------- | ------- | ----- | ----- | ------ |
| ingestion-pipeline | Read source data (HL7v2 and CCDA), convert to FHIR, standardize, and upload to a FHIR server | File creation in storage container via Eventarc trigger | New file name and its storage container | 1. convert-to-fhir<br>2.standardize-patient-names<br>3. standardize-patient-phone-numbers<br>4. geocode-patient-address<br>5. compute-patient-hash<br>6. upload-to-fhir-server | HL7v2 and CCDA messages are read, converted to FHIR, standardized and enriched, and uploaded to a FHIR server as they arrive in Cloud Storage. In the event that the conversion or upload steps fail the data is written to separate storage containers along with relevent logging. |

### Azure Functions
[Azure Functions](https://learn.microsoft.com/en-us/azure/data-factory/control-flow-expression-language-functions) are Microsoft's version of serverless functions, similar to Lamabda in Amazon Web Services (AWS) and Cloud Functions in GCP. Severless functions provide a relatively simple way to run services with modest runtime duration, memory, and compute requirements in the cloud. They are considered serverless because the cloud provider, Azure in this case, abstracts away management of the underlying infrastructure from the user. This allows us to simply write and excute our Building Blocks without worrying about the computers they run on. The TODO [??-functions/]() directory contains source code for each of our Azure Functions. We have chosen to develop the functions in Python because the [PHDI SDK](https://github.com/CDCgov/phdi-sdk) is written in Python and Azure has [strong support and documentation](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level) for developing Azure Functions with Python.

The table below summarizes these functions, their purposes, triggers, inputs, and outputs:

| Name | Language | Purpose | Trigger | Input | Output | Effect |
| ---- | -------- | ------- | ------- | ------| ------ | ------ |
| convert-to-fhir | Python | Convert source HL7v2 or CCDA messages to FHIR. | POST request | file name and bucket name | JSON FHIR bundle or conversion failure message | HL7v2 or CCDA messages are read from a bucket and returned as a JSON FHIR bundle. In the even that the conversion fails the data is written to a separate bucket along with the response of the converter.|
| standarize-patient-names | Python | Ensure all patient names are formatted similarly. | POST request | JSON FHIR bundle | JSON FHIR Bundle | A FHIR bundle is returned with standardized patient names. |
| standardize-patient-phone-numbers | Python | Ensure all patient phone number have the same format. | POST request | JSON FHIR bundle | JSON FHIR bundle | A FHIR bundle is returned with all patient phone numbers in the E.164 standardard international format. |
| geocode-patient-address | Python | Standardize patient addresses and enrich with latitude and longitude. | POST request | JSON FHIR bundle | JSON FHIR bundle | A FHIR bundle is returned with patient addresses in a consistent format that includes latitude and longitude. |
| compute-patient-hash | Python | Generate an identifier for record linkage purposes. | POST request | JSON FHIR bundle | JSON FHIR bundle | A FHIR bundle is returned where every patient resource contains a hash based on their name, date of birth, and address that can be used to link their records. |
| upload-to-fhir-server | Python | Add FHIR resources to a FHIR server. | POST request| JSON FHIR bundle | FHIR server response | All resources in a FHIR bundle are uploaded to a FHIR server. In the event that a resource cannot be uploaded it is written to a separate bucket along with the response from the FHIR server. |  

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


## Local Development Environment

The below instructions cover how to setup a development environment for local development of functions

### Hardware

Until we have properly containerized our apps, we will need to rely on informal consensus around hardware. Here is a list of machines that are compatible with development:
- Intel Macs
- Apple-Silicon Macs
- Windows-based machines with Windows 10/11 Home or higher. However, as the work moves towards containerization, Windows Pro will be necessary in order to run Docker.

### Software

#### Overview
The team uses VSCode as its IDE, but other options (e.g. IntelliJ, Eclipse, PyCharm, etc.) can be viable as well. The main drivers behind using VSCode are its integration with Azure, which is a natural byproduct of them both being Microsoft-owned prodcuts, and the amount of documentation that exists to help get the environment setup. The rest of this document will assume that you're using VSCode as your IDE.The project itself is coded primarily in Python.

Lastly, there are some dependencies that the team makes use of in order to test Azure functionality locally, which include [Azurite](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azurite?tabs=visual-studio), [Azure Core Function Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local), and the .NET Core SDK. Azurite is a storage emulator, which will let you mock Azure's different data storage options, such as Tables, Queues, and Blobs. Azure Core Function Tools are the heart of what allows you to develop Azure functionality locally, and the .NET Core SDK is used for some of the functionality you might develop. For example, when building Azure Functions in Java, the .NET framework provides access to bindings (e.g `@BlobTrigger`) that you'll need. 

#### Installation
1. Install the latest version of [VSCode](https://code.visualstudio.com/download) (or use `brew install vscode`).
2. Install the [Azure Core Function Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local), but be sure to install the 3.x version, and not 4.x. 4.x does not work with all Azure functionality as well as one might hope.
3. Install the [.NET Core SDK 3.1](https://dotnet.microsoft.com/en-us/download/dotnet/3.1). Versions 5.0 and 6.0 do not seem to work well with the 3.x Azure Core Function Tools.
4. Install [Python 3.9.x](https://www.python.org/downloads/).  As of this writing, this is the highest Python version supported by Azure Funcation Apps.
5. Install [Azure CLI Tools](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).  These tools are essential to work with various aspects of the Azure cloud. 
In the next section, "Developing Azure Locally", we'll go over which Extensions you need to install, including the Azurite Extension, in order to begin developing Azure functionality.
6. Install [pip](https://pip.pypa.io/en/stable/installation/). This is the dependency manager for the Azure Functions

### Developing Azure Locally

At a high level, we follow the guide [here](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-vs-code) for how to set up Azure Functions directly for integration with VSCode. As mentioned previously, it's possible to use alternative means of working with these functions, but this represents the path that we have found to be well documented and to make certain operations easier. To get started with developing Azure functionality in VSCode efficiently, you first need to install some useful extensions.

#### Extensions

If you prefer to minimize what gets installed on your machine, you can install each of the following extensions, which should provide the functionality that you need.

**Azure CLI Tools**  
These are the tools for developing and running commands for the Azure CLI, which is what's needed when you want to run your Azure Functions locally. 

**Azure Account**  
This is the extension used to sign into Azure and manage your subscription. Be sure to sign in to your CDC Superuser Account once you've installed this extension.

**Azure Functions**  
This is the core extension needed to build the Azure Functions locally.

**Azure Resources**  
This extension isn't explictly necessary, but can be helpful to view and manage Azure resources.

**Azurite**  
This is another core extension to install as it allows you to mock Azure's data storage tools like Tables, Queues, and Blobs so that you can store and access data locally as if you were engaging with those tools. There are other ways to install Azurite, such as with `npm` or Docker, but working with it through the extension works as well. If you'd like to install this via Docker or npm, you can see the installation instructions [here](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azurite?tabs=npm).

If you'd prefer to minimize the amount of things you need to install yourself, you can install a single extension, which will provide all of those listed above plus more.

**Azure Tools**  
This extension installs 12 different extensions, which include the five listed above as well as Docker, Azure App Service, Azure Resource Manager, Azure Databases, Azure Storage, Azure Pipelines, and Azure Virtual Machines. If you find yourself needing these extensions, or believe you'll need them in the future, then installing this one extension could be worth it.

_Note: At various points in your project, VS Code may ask you if you want to optimize for use with the tools. If so, be sure to click yes to optimize._

##### What is the VSCode Azure Integration Actually Doing?

Under the hood, this integration is doing the following:

1. Creates a virtual environment (default path `.venv`) and installing all depedencies called out in `requirements.txt`. You can alternatively do this yourself with `source .venv/bin/activate; pip install -r requirements.txt`.
2. Creates `.vscode/tasks.json`, which make it easier to activate the relevant virtual environment, installs dependencies, and starts a debugging session
3. Creates `.vscode/launch.json`, which makes it so that when you hit F5 / go to `Run->Start Debugging` it runs the tasks from (2) and then attaches to the debugger for your functions when running locally.

#### Azure Function Directory Structure

All Azure Functions live in the [severless-functions](https://github.com/CDCgov/phdi-azure/tree/main/serverless-functions) directory. The tree below shows a hypoethetical example for a Azure Function called `myfunction`. The PHDI team believes strongly in the importance of developing well tested code, so we include an additional file called `test_<FUNCTION-NAME>.py`. In this example `test_myfunction.py` cotains the unit tests for `myfunction`. The deployment process for `myfunction` does???  TODO??

```bash
serverless-functions/
├── requirements_dev.txt
└── myfunction/
    ├── main.py
    ├── requirements.txt
    └── test_myfunction.py
```

#### Creating a Virtual Environment

In order to avoid dependency conflicts between multiple Python projects and potentially between different Azure Functions within this repo, we recommend that all Azure Function development is done within a Python virtual environment dedicated to a single function. For information on creating, activating, deactivating, and managing Python virtual environment please refer to [this guide](https://realpython.com/python-virtual-environments-a-primer). We recommend naming your virtual environment `.venv` as we have already added it to our `.gitignore` file to prevent it from being checked into source control.

#### Azure Function Dependencies

After creating a virtual environment and activating it, you may install all of the Azure Function's dependencies using `source .venv/bin/activate; pip install -r requirements.txt` or using the built-in F5 action provided by the Azure extension. To create or update a `requirements.txt` file run `pip freeze > requirements.txt`. 

Deploying the function app will result in it automatically installing the dependencies in `requirements.txt`.

#### Development Dependencies

Beyond the dependencies required to run Azure Functions we also rely on some additional development tools which include. We recommend you install these tool in your Azure Function virtual environments as well.

These tools include:

- [Black](https://black.readthedocs.io/en/stable/) - automatic code formatter that enforces PEP best practices
- [pytest](https://docs.pytest.org/en/6.2.x/) - for easy unit testing
- [flake8](https://flake8.pycqa.org/en/latest/) - for code style enforcement

All of these can be installed from the `requirements_dev.txt` file in `serverless-functions/` directory. Simply run `pip install -r requirements_dev.txt` from `serverless-functions/`, or `pip install -r ../requirements_dev.txt` from within a Azure Function subdirectory.

#### Running Azure Functions Locally

Before diving into the specifics of working with Python, it's worth covering how testing Azure Functionality in VS Code in general works, which is outlined below.

* As long as you have the Azure Functions extension installed (as described above), then you can either click the `Run -> Debug` button (the one that looks like the sideways triangle with the bug) or press `F5` to run the Function.  
* The second thing you'll need implemented is the Azurite storage extension described above. If you've installed this through the VS Code extension, then you can start the container by clicking one of the three buttons in the bottom-right tray of VS Code, which will saying "Azurite Table Service", "Azurite Queue Service", or "Azurite Blob Service". If you've installed Azurite using npm or Docker, use [the documentation](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azurite?tabs=npm) to work through how to start the service.  
* To use this container, set your connection string to `UseDevelopmentStorage=true`as detailed [here](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azurite?tabs=visual-studio).

#### Azure Function Unit Testing

As mentioned in [Azure Function Directory Structure](#azure-function-directory-structure) every Azure Function has unit testing in a `test_<FUNCTION-NAME>.py` file. We use [pytest](https://docs.pytest.org) to run these unit tests. Pytest is included in the [Development Dependencies](#development-dependencies), but can also be installed with `pip install pytest`. To run the unit tests for a Azure Function navigate to its root directory and simply run `pytest`. To run the unit tests for all Azure Function in this repository navigate to `phdi-azure/serverless-functions/` and run `pytest`. Please note that merging into the `main` branch of this repository is automatically blocked if all unit tests are not passing, see [Continuous Integration (CI)](#continuous-integration-ci) for details on this.  

#### Pushing to Github

To get access to push to Github, ask to get maintainer access to the repo for your Github account.

### Infrastructure as Code (IaC)

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

#### Running Terraform Locally

In order to use the Terraform code in this repository on your local machine you must first install Terraform which can be done following [this guide](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform). Additionally, you will also need to authenticate with an Azure project using the Azure CLI Tools. Install Azure CLI following [this guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli). After installing this software authenticate with your Azure project by running `az login` and follow the prompts in your browser. Now you are ready run Terraform commands!

To begin using terraform:  
  1. Navigate to the directory `phdi-azure/terraform/setup`. 
  1. Run `terraform init` to initialize the setup Terraform. 
  1. Run `terraform apply` to create a storage container for storing terraform state. It will prompt you for a Project ID ??TODO?? and region/zone. Note the name of the bucket output by this command. 
  1. Navigate to the directory `phdi-azure/terraform/implementation`.
  1. TODO?? Run `terraform init` to initialize the implementation Terraform. It will prompt you for the name of a container to store Terraform's state. Enter the name of the container output in the earlier step. It will also prompt you for a Project ID and region/zone.
  1. Create a new workspace called "dev" by running `terraform workspace new dev`. 
  1. Now you can run `terraform plan` to have Terraform determine the difference between the code locally and the infrastructure currently deployed in the Azure project. Terraform will return a list of changes, resources it will create, destroy, or modify, that it would make if you chose to move forward with a deployment. After a carefull review, if these changes are acceptable you may deploy them by running `terraform apply`. Please refer to the [Terraform CLI documentation](https://www.terraform.io/cli/commands) for further information on using Terraform locally.

### Continuous Integration and Continuous Deployment (CI/CD)

We have implemented CI/CD pipelines with [GitHub Actions](https://docs.github.com/en/actions) orchestrated by [GitHub Workflows](https://docs.github.com/en/actions/using-workflows/about-workflows) found in the `phdi-azure/.github/` directory.

#### Continuous Integration (CI)

The entire CI pipeline can be found in `phdi-azure/.github/test.yaml`. It runs every time a Pull Request is opened and whenever additional changes are pushed to a branch. Currently, the following steps are included in the CI pipeline:

1. Identify all directories containing an Azure Function.
2. Run the unit tests for each Azure Function.
3. Check that all Python code complies with Black and Flake8.
4. Check that all Terraform code is formated properly.

#### Continuous Deployment (CD)

A separate CD pipeline is configured for each Azure environemnt we deploy to. Each of these pipelines is defined in a YAML file starting with "deploy" in the `workflows/` directory (e.g. `phdi-azure/.github/deployment.yaml`). Generally, these pipelines run every time code is merged into the `main` branch of the repository. However, additional dependencies can be specified. For example, a successful deployment to a development environment could required before deploying to a production environment proceeds. When these pipelines run they first look for differences in the infrastructure that is specified in the respository and currently deployed to a given Azure project. If differences are detected, they are resolved by making changes to Azure project to bring into alignment with the repository. In order to grant the GitHub repository permission to make these changes, follow [these instructions](https://github.com/google-github-actions/auth#setup) to authenicate it with GCP.