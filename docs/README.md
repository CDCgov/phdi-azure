# Public Health Data Infrastructure Google Cloud

- [Public Health Data Infrastructure Google Cloud](#public-health-data-infrastructure-google-cloud)
  - [Overview](#overview)
    - [Quick Start](#quick-start)
    - [Structure and Organizations](#structure-and-organization)
      - [Serverless Funtions](#serverless-functions)
      - [Pipeline Orchestration](#pipeline-orchestration)
      - [Infrastructure as Code](#infrastructure-as-code)
      - [Continuous Integration and Continuous Deployment](#continuous-integration-and-continuous-deployment)
    - [Target Users](#target-users)
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

The Public Health Data Infrastructure (PHDI) projects are part of the Pandemic-Ready Interoperability Modernization Effort (PRIME), a multi-year collaboration between CDC and the U.S. Digital Service (USDS) to strengthen data quality and information technology systems in state and local health departments. Under the PRIME umberalla the PHDI project seeks to develop tools, often reffered to as Building Blocks, that State, Tribal, Local, and Territorial public health agencies (STLTs) can use to better handle the public health data they recieve. The purpose of this repository is to implement the Building Blocks devloped from the [PHDI SDK](https://github.com/CDCgov/phdi-sdk) on Google Cloud Platform (GCP). This will allow users to easily begin using these Building Blocks in their own GCP environment. For more information on using this repository beyond what is contained in this document please refer to our [Getting Started](getting_started.md) doc.

### Quick Start

To deploy this pipeline to your own Google Cloud environment, follow these steps.
  
  Be sure to replace all instances of `myuser` in GitHub URLs with your user or organization name.
  1. [Install the gcloud CLI](https://cloud.google.com/sdk/docs/install-sdk)
  1. [Install the GitHub CLI](https://cli.github.com/manual/installation) (optional)
  1. [Fork this repository](https://github.com/myuser/phdi-google-cloud/fork) into your personal or organization account
  1. Clone your newly forked repository to your local machine by running:

         git clone https://github.com/myuser/phdi-google-cloud.git

  1. Navigate to the new repository directory with:

         cd phdi-google-cloud

  1. Authenticate the gcloud CLI by running:

         ./quick-start.sh

  1. Follow [these steps](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository) to set the secrets output by the previous step in your repository.
  1. Setup a storage bucket for Terraform state by running the GitHub Action at this URL:  
  https://github.com/myuser/phdi-google-cloud/actions/workflows/terraformSetup.yaml
  1. Create an environment named `dev` in your repository at this URL:  
  https://github.com/myuser/phdi-google-cloud/settings/environments/new
  1. Deploy to your newly created `dev` environment by running the GitHub Action at this URL, selecting `dev` as the environment input:  
  https://github.com/myuser/phdi-google-cloud/actions/workflows/deployment.yaml
  1. Success! You should now see resources in your GCP project ready for data ingestion.

### Structure and Organization

There are primarily four major components to this repository.

#### Serverless Functions

The PHDI Building Blocks are implemented as Google Cloud Functions. Google Cloud Functions are GCP's version of serverless functions, similar to Lamabda in Amazon Web Services (AWS) and Azure Functions in Mircosoft Azure. Severless function provide a relatively simple way to run services with modest runtime duration, memory, and compute requirements in the cloud. Since they are serverless, GCP abstracts all aspects of the underlying infrastructure allowing us to simply write and excute our Building Blocks without worrying about the computers they run on. The `cloud-functions` directory contains Python source code for Google Cloud Functions that implement Building Blocks from the PHDI SDK.

#### Pipeline Orchestration

Since the Building Blocks are designed to be composable users may want to chain serveral together into pipelines. We use the Google Workflow resource to define processes that require the use of multiple Building Blocks. These workflows are defined using YAML configuration files found in the `worklows` directory.

#### Infrastructure as Code

Every resource required to use the Building Blocks and pipelines implemented in this respostory are defined using Terraform. This makes it simple for users to deploy all of the functionality provided in this repository to their own GCP environments. The Terraform code can be found in the `terraform` directory.

#### Continuous Integration and Continuous Deployment

In order to ensure high code quality and reliability we have implemented a Continuous Integation (CI) pipeline consisting of a suite of tests all new contributions must pass before they are merged into `main`. We have also built a Continuous Deployment (CD) pipeline that automatically deploys the code in the repositiory to linked GCP environments when changes are made. The combined CI/CD pipeline is implemented with GitHub Actions in the `.github` directory. 

### Target Users

Target users of this system include:

- Public Health Departments
  - Epidemiologists who rely on health data to take regular actions
  - Senior stakeholders who make executive decisions using aggregate health data
  - IT teams who have to support epidemiologists and external stakeholders integrating with the PHD
  - PHDs may include state, county, city, and tribal organizations
- CDC
  - Employees and contractors working on CDC projects with access to a GCP environment and interest in using PHDI Building Blocks


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
