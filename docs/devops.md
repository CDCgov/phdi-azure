# DevOps

## Continuous Integration and Continuous Deployment (CI/CD)

We have implemented CI/CD pipelines with [GitHub Actions](https://docs.github.com/en/actions) orchestrated by [GitHub Workflows](https://docs.github.com/en/actions/using-workflows/about-workflows) found in the `phdi-azure/.github/` directory.

### Continuous Integration (CI)

The pre-merge CI pipeline can be found in [`phdi-azure/.github/workflows/testPython.yaml`](https://github.com/CDCgov/phdi-azure/blob/main/.github/workflows/testPython.yaml) It runs every time a Pull Request is opened and whenever additional changes are pushed to a branch. Currently, the following steps are included in this CI pipeline:

1. Identify all directories containing an Azure Function.
2. Run the unit tests for each Azure Function.
3. Check that all Python code complies with Black and Flake8.
4. Check that all Terraform code is formatted properly.

After merging, an end-to-end test is run against the `main` branch. This test can be found in `phdi-azure/.github/workflows/end-to-end.yaml`. This test runs sample data against a pipeline set up in an Azure development environment, and validates that the pipeline performed as intended.

### Continuous Deployment (CD)

A separate CD pipeline is configured for each Azure environment we deploy to. Each of these pipelines is defined in a YAML file starting with "deploy" in the `workflows/` directory (e.g. `phdi-azure/.github/deployment.yaml`). Generally, these pipelines run every time code is merged into the `main` branch of the repository. However, additional dependencies can be specified. For example, a successful deployment to a development environment could be required before deploying to a production environment. When these pipelines run Terraform looks for differences between the infrastructure that is specified on a given branch of this repository and what is currently deployed to a given environment in the Azure resource group. If differences are detected, they are resolved by making changes to Azure resources to bring them alignment with the repository. In order to grant the GitHub repository permission to make these changes, follow [these instructions](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azp#github-actions) to authenticate it with Azure.

### Table of CI/CD Pipelines

| Pipeline Name   | Purpose                                                                                                                  | Trigger                                                                         | Notes                                                                                                                       |
|-----------------|--------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| testPython      | Run unit and linting tests on all Python source code in the repository, primarily the `read-source-data` Azure Function. | All pull request actions, pushes to `main`, and manually.                       | Unit test with Pytest. Linting with Black and Flake8.                                                                       |
| terraformChecks | Ensure all Terraform code is valid and properly linted.                                                                  | All pull request actions if they involve changes in `terraform/`, and manually. | `terraform fmt` for linting and `terraform validate` for validation.                                                        |
| deployment      | Deploy the starter kit from a branch to a given environment.                                                             | Pushes to `main` and manually.                                                  | Pushes to `main` trigger a deploy to the `dev` environment. This behavior can be changed as desired.                        |
| terraformSetup  | Create a storage account for storing the state of every environment deployed in the Azure resource group.                | Manual                                                                          | This workflow should only be run once for initial setup.                                                                    |
| end-to-end      | Run end-to-end tests to ensure the pipeline functions as expected within Azure.                                          | Pushes to `main`, or manually.                                                  | Verify the pipeline records the correct number of successes and failures and that data can be queried from the FHIR server. |
| destroy         | Destroy an environment within Azure.                                                                                     | Manual                                                                          | Destroys a given Terraform environment.                                                                                     |

## New Releases
It's important to keep your repository up-to-date with version changes from the main `phdi` repository. Even if you're not using new features of the services, staying up to date is a security best practice.

To update, visit the [main phdi repository](https://github.com/CDCgov/phdi) and copy the [latest version number](https://github.com/CDCgov/phdi/releases). Update the container image tag in [`main.tf`](https://github.com/CDCgov/phdi-azure/blob/main/terraform/modules/shared/main.tf#L201-L201).

We recommend doing this update at least monthly, and deploying every time an update is made.