# PHDI Azure Implementation Guide

- [PHDI Azure Implementation Guide](#phdi-azure-implementation-guide)
    - [Overview](#overview)
        - [What is PHDI?](#what-is-phdi)
        - [What are Building Blocks?](#what-are-building-blocks)
        - [PHDI Starter Kit Architecture](#phdi-starter-kit-architecture)
            - [Ingestion Pipeline](#ingestion-pipeline)
            - [Tabulation Service](#tabulation-service)
        - [Additional References](#additional-references)
    - [Implementing the PHDI Starter Kit in Azure](#implementing-the-phdi-starter-kit-in-azure)
        - [User Requirements](#user-requirements)
        - [Step 1: Ensure You Have Collected Values for Geocoding Variables](#step-1-ensure-you-have-collected-values-for-geocoding-variables)
        - [Step 2: Run the Quick Start Script in Azure Cloud Shell](#step-2-run-the-quick-start-script-in-azure-cloud-shell)

## Overview
This document offers a detailed guide for implementing the PHDI Starter Kit pipeline in an Azure environment.

### What is PHDI?
The Public Health Data Infrastructure (PHDI) project is part of the Pandemic-Ready Interoperability Modernization Effort (PRIME), a multi-year collaboration between CDC and the U.S. Digital Service (USDS) to strengthen data quality and information technology systems in state and local health departments. The PHDI project has developed a **Starter Kit data ingestion pipeline**, built from modular software tools known as **Building Blocks**, which can be combined in multiple configurations to create data pipelines. The purpose of this repository is to help users deploy the Building Blocks provided in the [PHDI library](https://github.com/CDCgov/phdi) as a Starter Kit pipeline in their own Azure environment.

### What are Building Blocks?
PHDI's goal is to provide public health authorities (PHAs) with modern software tools to solve challenges working with public health data. We refer to these tools as Building Blocks. Some Building Blocks offer relatively simple functionality, like standardizing patient names, while others perform more complex tasks, including geocoding and standardizing addresses. Importantly, the Building Blocks have been carefully designed with common inputs and outputs making them easily composable into data pipelines.  

### PHDI Starter Kit Architecture
The composable nature of Building Blocks allows them to be strung together into data pipelines where each Building Block represents a single step in a pipeline. As an example, let's consider a hypothetical case where a PHA would like to improve the quality of their patient address data and ensure that patient names are written consistently. They could solve this problem by using the name standardization and geocoding Building Blocks, mentioned in the previous section, to build a simple pipeline that standardizes patients' names and geocodes their addresses. Non-standardized data would be sent into the pipeline, where it would pass through each of the Building Blocks, and then exit the pipeline with standardized name and address fields. PHAs are welcome to use Building Blocks to create their own custom pipelines. However, because many PHAs face similar challenges processing data this repository implements a basic architecture in the form of a Starter Kit. The goal of this Starter Kit is to help PHAs easily get up and running with modern modular tooling for processing public health data in the cloud. We also fully understand that all PHAs do not face the same challenges. Our intention is for STLTs to modify and expand on this Starter Kit architecture to make it fit their specific needs. The Starter Kit has two main components: an ingestion pipeline that cleans and stores data in a FHIR server, and tabulation service that allows data to be easily extracted from the FHIR server. The complete architecture for the Starter Kit is shown in the diagram below.

![Architecture Diagram](./images/azure-starter-kit-arch.drawio.png)

#### Ingestion Pipeline
The ingestion pipeline is intended to allow PHAs to easily bring data that is reported to them into their system after performing standardizations and enrichments. Source data can be provided in either Hl7v2 or C-CDA formats, allowing this single pipeline to manage ingestion of ELR, VXU, ADT, and eCR messages. The pipeline is able to support both data types because the initial step is to convert to FHIR. After this conversion, the pipeline is able to handle all reported data the same way by simply processing the FHIR bundles (e.g., collections of FHIR resources) that result from the conversion. Once data has be converted to FHIR, the following standardizations and enrichments are made:
1. Patient names are standardized.
2. Patient phone numbers are transformed into the ISO E.164 standard international format.
3. Patient addresses are geocoded for standardization and enrichment with latitude and longitude.
4. A hash based on a patient's name, date of birth, and address is computed to facilitate linkage with other records for the same patient.

After the data has been cleaned and enriched, it is uploaded to a FHIR Store where it can serve as a single source of truth for all downstream reporting and analytics needs.

#### Tabulation Service
The tabulation service provides a mechanism for extracting and tabulating data from the FHIR server. Users define schemas describing the table(s) they would like to extract from the FHIR Store and submit them to the tabulation service. The service then conducts a basic Extract Transform and Load (ETL process) with the following steps:
1. Extraction - The service identifies the data required for a given schema and extracts it from the FHIR server using the FHIR API. 
2. Transform - The non-tabular and nested JSON FHIR data is transformed into the tabular format specified by the schema.
3. Load - The tabulated data is loaded into a flat file format (CSV, Parquet, or SQLite) and stored in an Azure File share. The data specified in the schema is now available to downstream reporting and analytical workloads.

### Additional References
We have only provided a brief overview of PHDI, Building Blocks, and the Starter Kit pipeline we have designed. For additional information, please refer to the documents linked below.
- [PHDI-azure README](./README.md)
- [PHDI-azure Getting Started Guide](./getting_started.md)

## Implementing the PHDI Starter Kit in Azure
In this section, we describe how a PHA can take this repository and use it to spin up all of the functionality that the Starter Kit offers in their own Azure environment.

Below, we will provide our Quick Start Script, which, when executed, connects your GitHub repository to your Azure instance, sets up environment variables for both, and executes the Terraform necessary to provision required resources in your Azure environment.

### User Requirements
In order to proceed, you will need:
1. `Owner` access to the Azure subscription where you would like to deploy the PHDI Starter Kit.
1. A GitHub account with a verified email address.
1. To be able to create new repositories in the GitHub account or organization where your copy of this repository will be created.

If you are planning to use an organization account, you must be able to authorize the GitHub CLI to interact with the organization.

If you do not meet these criteria, contact the owner of your organization's Azure subscription and/or GitHub organization.

### Step 1: Ensure You Have Collected Values for Geocoding Variables

Exiting the Quick Start Script partway through is not recommended, so please have all values on hand when you run the script.

Required to use geocoding functionality:
- `SMARTY_AUTH_ID` - Your SmartyStreet Authorization ID. Find more info on the Smarty geocoding service [here](https://www.smarty.com/pricing/us-rooftop-geocoding).
- `SMARTY_AUTH_TOKEN` - Your SmartyStreet Authorization Token.

Keep these values easily accessible so that they can be entered later when the script prompts for them.

### Step 2: Run the Quick Start Script in Azure Cloud Shell
In this step, we will work through Azure's [Workload Identity Federation](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation) to grant your phdi-azure repository access to deploy the pipelines to your organization's Azure environment. Below, we have provided a Quick Start Script to automate most of this process that we recommend you use. However, if you prefer to work through it manually, you may follow [this guide](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azcli).

**Quick Start Script:**
Navigate to the [Azure Cloud Shell](https://shell.azure.com/).  
  
Choose Bash as your shell environment:
![azure-cloud-shell-bash](./images/azure-cloud-shell-bash.png)  
  
Create storage for your Cloud Shell:  
![azure-cloud-shell-storage](./images/azure-cloud-shell-storage.png)  
  
When your shell is ready to receive commands, it will look like this:
![azure-cloud-shell-ready](./images/azure-cloud-shell-ready.png)

To download and run the Quick Start Script, run the following command in Cloud Shell:
```bash
git clone https://github.com/CDCgov/phdi-azure.git && cd phdi-azure && ./quick-start.sh
```

When the script is ready for your input, it will look like this:  
![quick-start-ready](./images/quick-start-ready.png)  
  
Press enter to begin the script.

If you plan to deploy to an existing resource group in your Azure environment, have the resource group name ready and provide it to the Quick Start Script when prompted.

The script will take around 20-30 minutes to run.


### Upgrading the PHDI Version

When a new version of PHDI is availble, the version used by `phdi-azure` can be updated by doing the following steps.

#### Upgrade Steps

1. Create a new branch for the upgrade.

2. Open the `terraform/modules/shared/main.tf` in a text editor of your choice.

3. Within the file, search for the code block that starts with `data "docker_registry_image" "ghcr_data" {`.

4. In the `name` field of the code block, you will find the current version number specified. Modify the version number to the desired new version.

   Example:
   ```hcl
   data "docker_registry_image" "ghcr_data" {
     for_each = local.images
     name     = "ghcr.io/cdcgov/phdi/${each.key}:v1.0.5"
   }
   ```

   Change the version number to the desired new version:
   ```hcl
   data "docker_registry_image" "ghcr_data" {
     for_each = local.images
     name     = "ghcr.io/cdcgov/phdi/${each.key}:v1.0.6"
   }
   ```

5. Save the `main.tf` file after making the necessary modifications.

6. Commit and push the branch to your repository.

7. Open a new PR for your branch to `main`.

8. After merging your PR, `dev` will be automatically deployed. Other environments can be deployed via github actions
