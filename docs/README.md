# Public Health Data Infrastructure Azure

- [Public Health Data Infrastructure Azure](#public-health-data-infrastructure-azure)
  - [Overview](#overview)
    - [Problem Scope](#problem-scope)
 - [How to Deploy Our Starter Kit to Azure](#how-to-deploy-our-starter-kit-tozure)
    - [Main Components](#main-components)
      - [Azure Container Applications](#azure-container-applications)
      - [Serverless Funtions](#serverless-functions)
      - [Pipeline Orchestration](#pipeline-orchestration)
      - [Infrastructure as Code](#infrastructure-as-code)
      - [Continuous Integration and Continuous Deployment](#continuous-integration-and-continuous-deployment)
    - [Additional Starter Kit Setup Guidance](#additional-starter-kit-setup-guidance)
  - [Standard Notices](#standard-notices)
    - [Public Domain Standard Notice](#public-domain-standard-notice)
    - [License Standard Notice](#license-standard-notice)
    - [Privacy Standard Notice](#privacy-standard-notice)
    - [Contributing Standard Notice](#contributing-standard-notice)
    - [Records Management Standard Notice](#records-management-standard-notice)
    - [Related documents](#related-documents)
    - [Additional Standard Notices](#additional-standard-notices)

**General disclaimer** This repository was created for use by CDC programs to collaborate on public health related projects in support of the [CDC mission](https://www.cdc.gov/about/organization/mission.htm).  GitHub is not hosted by the CDC, but is a third party website used by CDC and its partners to share information and collaborate on software. CDC use of GitHub does not imply an endorsement of any one particular service, product, or enterprise. 


## Overview

The purpose of this repository is to implement our cloud-based **Starter Kit pipeline** in Azure. Our Starter Kit is composed of **Building Blocks**—modular software tools that, when composed together, can improve data quality and reduce data cleaning workloads—developed from the [PHDI SDK](https://github.com/CDCgov/phdi). This repository will allow users to begin deploying these Building Blocks to their own Azure environment. For more information for using our repository beyond what is contained in this README, please refer to our [Getting Started](getting_started.md) document, which offers additional resources on how to set up a local development environment, how these Building Blocks are deployed, and more.

### Problem Scope

Current public health systems that digest, analyze, and respond to data are siloed. Lacking access to actionable data, our national, as well as state, local, and territorial infrastructure, isn’t pandemic-ready. To address this challenge, CDC and the U.S. Digital Service (USDS) established the Pandemic-Ready Interoperability Modernization Effort (PRIME), a multi-year collaboration to strengthen data quality and information technology systems in state and local health departments. The Public Health Data Infrastructure (PHDI) project emerged from that collaboration. Our objective is to help the CDC best support public health authorities in moving towards a modern public health data infrastructure. This project offers a suite of modular, scalable tools to ingest public health messages, based on [Building Blocks](https://github.com/CDCgov/phdi). See our [public website](https://cdcgov.github.io/phdi-site/) for more details.

PHDI is a sibling project to [PRIME ReportStream](https://reportstream.cdc.gov), which focuses on improving the delivery of COVID-19 test data to public health departments, and [PRIME SimpleReport](https://simplereport.gov), which provides a better way for organizations and testing facilities to report COVID-19 rapid tests to public health departments.

## How to Deploy Our Starter Kit to Azure

To deploy this pipeline to your own Azure environment, follow these steps.
  
  Be sure to replace all instances of `myuser` in GitHub URLs with your user or organization name.
  1. [Install the az CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
  1. [Install the GitHub CLI](https://cli.github.com/manual/installation)
  1. [Fork this repository](https://github.com/myuser/phdi-azure/fork) into your personal or organization account
  1. Clone your newly forked repository to your local machine by running:

         git clone https://github.com/myuser/phdi-azure.git

  1. Navigate to the new repository directory with:

         cd phdi-azure

  1. Authenticate the Azure cloud CLI by running:
       
      for Unix based systems

         ./quick-start.sh

      for Windows based systems
      
         quick-start.ps1

  1. If you did not install the GitHub CLI, follow [these steps](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository) to set the secrets output before proceeding.
  1. Setup a storage account for Terraform state by running the GitHub Action at this URL:  
  https://github.com/myuser/phdi-azure/actions/workflows/terraformSetup.yaml
  1. Create an environment named `dev` in your repository at this URL:  
  https://github.com/myuser/phdi-azure/settings/environments/new
  1. Deploy to your newly created `dev` environment by running the GitHub Action at this URL, selecting `dev` as the environment input:  
  https://github.com/myuser/phdi-azure/actions/workflows/deployment.yaml
  1. Success! You should now see resources in your Azure project ready for data ingestion.

## Main Components

There are five major components to this repository.

### Azure Container Applications

The PHDI Building Blocks containerized web services are deployed in Azure as Azure Container Applications (ACA). ACA is a fully managed serverless platform for deploying containers, similar to AWS Fargate and GCP Cloud Run. Since ACA is serverless, Azure abstracts all aspects of the underlying infrastructure for running and scaling these services. This allows us to simply provide ACA with the images for our containerized Building Blocks. When the Starter Kit deploys, these images are pulled from the public registry associated with the [CDCgov/phdi repository](https://github.com/CDCgov/phdi). You may access these images directly [here](https://github.com/orgs/CDCgov/packages?repo_name=phdi).

### Serverless Functions

The PHDI Building Blocks are implemented as Azure Function Apps. Azure Function Apps are Azure's version of serverless functions, similar to Lambda in Amazon Web Services (AWS) and Azure Function Apps in Mircosoft Azure. Severless function provide a relatively simple way to run services with modest runtime duration, memory, and compute requirements in the cloud. Since they are serverless, Azure abstracts all aspects of the underlying infrastructure allowing us to simply write and excute our Building Blocks without worrying about the computers they run on. The `cloud-functions` directory contains Python source code for Azure Function Apps that implement Building Blocks from the PHDI SDK.

#### Pipeline Orchestration

Since the Building Blocks are designed to be composable users may want to chain serveral together into pipelines.  We use Microsofts Azure Data Factory (ADF) to define the process that require the use of multiple Building Blocks.  These pipelines can be configured using **TBD TODO**

#### Infrastructure as Code

Every resource required to use the Building Blocks and pipelines implemented in this respostory are defined using Terraform. This makes it simple for users to deploy all of the functionality provided in this repository to their own Azure environments. The Terraform code can be found in the `terraform` directory.

#### Continuous Integration and Continuous Deployment

In order to ensure high code quality and reliability we have implemented a Continuous Integation (CI) pipeline consisting of a suite of tests all new contributions must pass before they are merged into `main`. We have also built a Continuous Deployment (CD) pipeline that automatically deploys the code in the repositiory to linked Azure environments when changes are made. The combined CI/CD pipeline is implemented with GitHub Actions in the `.github` directory. 

### Target Users

Target users of this system include:

- Public Health Departments
  - Epidemiologists who rely on health data to take regular actions
  - Senior stakeholders who make executive decisions using aggregate health data
  - IT teams who have to support epidemiologists and external stakeholders integrating with the PHD
  - PHDs may include state, county, city, and tribal organizations
- CDC
  - Employees and contractors working on CDC projects with access to a Azure environment and interest in using PHDI Building Blocks


## Access Request, Repo Creation Request

* [CDC GitHub Open Project Request Form](https://forms.office.com/Pages/ResponsePage.aspx?id=aQjnnNtg_USr6NJ2cHf8j44WSiOI6uNOvdWse4I-C2NUNk43NzMwODJTRzA4NFpCUk1RRU83RTFNVi4u) _[Requires a CDC Office365 login, if you do not have a CDC Office365 please ask a friend who does to submit the request on your behalf. If you're looking for access to the CDCEnt private organization, please use the [GitHub Enterprise Cloud Access Request form](https://forms.office.com/Pages/ResponsePage.aspx?id=aQjnnNtg_USr6NJ2cHf8j44WSiOI6uNOvdWse4I-C2NUQjVJVDlKS1c0SlhQSUxLNVBaOEZCNUczVS4u).]_

## Related documents

* [Open Practices](open_practices.md)
* [Rules of Behavior](rules_of_behavior.md)
* [Thanks and Acknowledgements](thanks.md)
* [Disclaimer](DISCLAIMER.md)
* [Contribution Notice](CONTRIBUTING.md)
* [Code of Conduct](code-of-conduct.md)

## Standard Notices
  
### Public Domain Standard Notice
This repository constitutes a work of the United States Government and is not
subject to domestic copyright protection under 17 USC § 105. This repository is in
the public domain within the United States, and copyright and related rights in
the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
All contributions to this repository will be released under the CC0 dedication. By
submitting a pull request you are agreeing to comply with this waiver of
copyright interest.

### License Standard Notice
This project is in the public domain within the United States, and copyright and
related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
All contributions to this project will be released under the CC0 dedication. By
submitting a pull request or issue, you are agreeing to comply with this waiver
of copyright interest and acknowledge that you have no expectation of payment,
unless pursuant to an existing contract or agreement.

### Privacy Standard Notice
This repository contains only non-sensitive, publicly available data and
information. All material and community participation is covered by the
[Disclaimer](https://github.com/CDCgov/template/blob/master/DISCLAIMER.md)
and [Code of Conduct](https://github.com/CDCgov/template/blob/master/code-of-conduct.md).
For more information about CDC's privacy policy, please visit [http://www.cdc.gov/other/privacy.html](https://www.cdc.gov/other/privacy.html).

### Contributing Standard Notice
Anyone is encouraged to contribute to the repository by [forking](https://help.github.com/articles/fork-a-repo)
and submitting a pull request. (If you are new to GitHub, you might start with a
[basic tutorial](https://help.github.com/articles/set-up-git).) By contributing
to this project, you grant a world-wide, royalty-free, perpetual, irrevocable,
non-exclusive, transferable license to all users under the terms of the
[Apache Software License v2](http://www.apache.org/licenses/LICENSE-2.0.html) or
later.

All comments, messages, pull requests, and other submissions received through
CDC including this GitHub page may be subject to applicable federal law, including but not limited to the Federal Records Act, and may be archived. Learn more at [http://www.cdc.gov/other/privacy.html](http://www.cdc.gov/other/privacy.html).

### Records Management Standard Notice
This repository is not a source of government records, but is a copy to increase
collaboration and collaborative potential. All government records will be
published through the [CDC web site](http://www.cdc.gov).

### Additional Standard Notices
Please refer to [CDC's Template Repository](https://github.com/CDCgov/template)
for more information about [contributing to this repository](https://github.com/CDCgov/template/blob/master/CONTRIBUTING.md),
[public domain notices and disclaimers](https://github.com/CDCgov/template/blob/master/DISCLAIMER.md),
and [code of conduct](https://github.com/CDCgov/template/blob/master/code-of-conduct.md).
