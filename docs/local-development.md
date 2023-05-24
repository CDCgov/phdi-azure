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
      - [Connecting Terraform to Azure](#connecting-terraform-to-azure)

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
4. Install [Python 3.10.x](https://www.python.org/downloads/).  As of this writing, this is the highest Python version supported by Azure Funcation Apps.
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
└── python/
    ├── requirements_dev.txt
    ├── requirements.txt
    └── myfunction/
        ├── .funcignore
        ├── __init__.py
        └── function.json
    └── tests/
        └── myfunction/
            ├── assets/
            ├── __init__.py
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

As mentioned in [Azure Function Directory Structure](#azure-function-directory-structure) every Azure Function has unit testing in a `test_<FUNCTION-NAME>.py` file. We use [pytest](https://docs.pytest.org) to run these unit tests. Pytest is included in the [Development Dependencies](#development-dependencies), but can also be installed with `pip install pytest`. To run the unit tests for a Azure Function navigate to its root directory and simply run `pytest`. To run the unit tests for all Azure Function in this repository navigate to `phdi-azure/src/serverless-functions/tests/` and run `pytest`. Please note that merging into the `main` branch of this repository is automatically blocked if all unit tests are not passing, see [Continuous Integration (CI)](#continuous-integration-ci) for details on this.  

#### Pushing to Github

To get access to push to Github, ask to get maintainer access to the repo for your Github account.

#### Connecting Terraform to Azure

This repository contains Terraform configurations for deploying infrastructure on Azure. Follow the steps below to set up and connect Terraform to your Azure account.

Make sure you have the following installed.
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [Homebrew](https://brew.sh/) package manager (for macOS users)

1. Navigate to the Terraform implementation directory:

   ```shell
   cd your-repository/terraform/implementation

2. Install Azure CLI using Homebrew (macOS):

    ```shell
    brew update && brew install azure-cli
3. Install Terraform CLI using Homebrew:

    ```shell
    brew tap hashicorp/tap
    brew install hashicorp/tap/terraform

4. Log in to Azure:
    ```shell
    az login

This command will open a browser window where you can complete the Azure login process. Once authenticated, you can close the browser and return to the terminal.

5. Connect Terraform to Azure:
    ```shell
    terraform init -backend-config=backend.tfvars

This command initializes Terraform and configures the backend using the provided backend.tfvars file.

##### Usage
Now that you have connected Terraform to Azure, you can start using Terraform commands to manage your infrastructure. Some common commands include:

- terraform plan: Generates an execution plan for changes to be applied.
- terraform apply: Applies the changes to create or update the resources.
- terraform destroy: Destroys the infrastructure defined in the Terraform configuration.
- terraform workspace list: Lists the available workspaces.
- terraform workspace select {workspace name}: Select a workspace to operate in.

Refer to the official [Terraform documentation](https://www.terraform.io/docs/cli/commands/index.html) for more details on using Terraform commands.


