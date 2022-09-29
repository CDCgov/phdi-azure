################################################################################
#
# This script is used to setup Azure authentication for GitHub Actions.
# It is based on the following guide: https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azcli
#
################################################################################

# Function to output the variables needed to load into GitHub Actions secrets
function Get-Variables {
    Write-Host "Please load the following variables into your repository secrets at this URL:"
    Write-Host "https://github.com/$GITHUB_REPO/settings/secrets/actions"
    Write-Host ""
    Write-Host "TENANT_ID: $TENANT_ID"
    Write-Host "SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
    Write-Host "CLIENT_ID: $CLIENT_ID"
    Write-Host "RESOURCE_GROUP_NAME: $RESOURCE_GROUP_NAME"
    Write-Host "LOCATION: $LOCATION"
    Write-Host "SMARTY_AUTH_ID: Your Smarty Streets App Authorization ID"
    Write-Host "SMARTY_AUTH_TOKEN: Your Smarty Streets App Authorization Token"
    Write-Host ""
    Write-Host "More info on locations can be found at:"
    Write-Host "https://azure.microsoft.com/en-us/explore/global-infrastructure/geographies/#overview"
    Write-Host ""
    Write-Host "You can now continue with the Quick Start instructions in the README.md file."
}

# Function to use GitHub CLI to set repository secrets
function Set-Variables {
    $GH_COMMAND = Get-Command "gh" -ErrorAction SilentlyContinue
    if ($null -eq $GH_COMMAND) {
        Write-Host "Error: The GitHub CLI is not installed. To install, visit this page:"
        Write-Host "https://cli.github.com/manual/installation"
        Write-Host
        Get-Variables
        Exit
    }

    Write-Host "Please enter the authorization id of your Smarty Street Account."
    Write-Host "More info:   https://www.smarty.com/docs/cloud/authentication"
    $SMARTY_AUTH_ID = Read-Host
  
    Write-Host "Please enter the authorization token of your Smarty Street Account."
    Write-Host "More info:   https://www.smarty.com/docs/cloud/authentication"
    $SMARTY_AUTH_TOKEN = Read-Host

    Write-Host "Logging in to GitHub..."
    gh auth login

    Write-Host "Setting repository secrets..."
    gh secret -R "$GITHUB_REPO" set TENANT_ID --body "$TENANT_ID"
    gh secret -R "$GITHUB_REPO" set SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"
    gh secret -R "$GITHUB_REPO" set CLIENT_ID --body "$CLIENT_ID"
    gh secret -R "$GITHUB_REPO" set RESOURCE_GROUP_NAME --body "$RESOURCE_GROUP_NAME"
    gh secret -R "$GITHUB_REPO" set LOCATION --body "$LOCATION"
    gh secret -R "$GITHUB_REPO" set SMARTY_AUTH_ID --body "$SMARTY_AUTH_ID"
    gh secret -R "$GITHUB_REPO" set SMARTY_AUTH_TOKEN --body "$SMARTY_AUTH_TOKEN"

    Write-Host "Repository secrets set!"
    Write-Host "You can now continue with the Quick Start instructions in the README.md file."
}

# Prompt user for project name and repository name
Write-Host "Welcome to the PHDI Azure setup script!"
Write-Host "This script will help you setup az CLI authentication for GitHub Actions."
Write-Host "We need some info from you to get started."
Write-Host "After entering the info, a browser window will open for you to authenticate with Azure."
Write-Host ""

while ($null -eq $RESOURCE_GROUP_NAME) {
    $yn = Read-Host "Do you already have a Resource Group in Azure? (y/n)"
    Switch ($yn) {
        { @("y", "Y") -eq $_ } {
            $RESOURCE_GROUP_NAME = Read-Host "Please enter the name of the existing Resource Group."
            $NEW_RESOURCE_GROUP = $false
        }
        { @("n", "N") -eq $_ } {
            $RESOURCE_GROUP_NAME = Read-Host "Please enter a name for a new Resource Group."
            $NEW_RESOURCE_GROUP = $true
        }
        default { "Please enter y or n." }
    }
}

Write-Host "Please enter the name of the repository you will be deploying from."
Write-Host "For example, if your repo URL is https://github.com/CDCgov/phdi-azure, enter: CDCgov/phdi-azure."
$GITHUB_REPO = Read-Host

Write-Host "Please enter the name of the location you would like to deploy to (e.g. centralus)."
Write-Host "More info: https://azure.microsoft.com/en-us/explore/global-infrastructure/geographies/#overview"
$LOCATION = Read-Host

# Login to Azure, get tenant and subscription IDs
az login
$TENANT_ID = (az account show --query "tenantId" -o tsv)
$SUBSCRIPTION_ID = (az account show --query "id" -o tsv)

# Create a project if needed and get the project ID
if ($NEW_RESOURCE_GROUP) {
    az group create --location "$LOCATION" --resource-group "$RESOURCE_GROUP_NAME"
}

$RESOURCE_GROUP_ID = (az group show --resource-group "${RESOURCE_GROUP_NAME}" --query "id" -o tsv)
if ([string]::IsNullOrEmpty($RESOURCE_GROUP_ID)) {
    Write-Host "Error: Resource Group ID not found. To list resource groups, run 'az group list'."
    Exit 1
}

# Set the current resource group to the RESOURCE_GROUP_NAME specified above
az config set defaults.group="${RESOURCE_GROUP_NAME}"

# Define app registration name, get client ID.
$APP_REG_NAME = "github"
$CLIENT_ID = (az ad app create --display-name $APP_REG_NAME --query appId --output tsv)

# Create service principal and grant access to subscription
az ad sp create-for-rbac --scopes /subscriptions/$SUBSCRIPTION_ID --role contributor --name $APP_REG_NAME

# Create federated credential
$CREDENTIALS = @"
{
  "name": "$APP_REG_NAME",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:$GITHUB_REPO:environment:main",
  "description": "GitHub Actions",
  "audiences": ["api://AzureADTokenExchange"]
}
"@ 
Write-Host "$CREDENTIALS" > credentials.json
az ad app federated-credential create --id $CLIENT_ID --parameters credentials.json

Write-Host "Workload Identity Federation setup complete!"
Write-Host ""

while ($null -eq $SCRIPT_DONE) {
    $yn = Read-Host "Would you like to use the GitHub CLI to set repository secrets automatically? (y/n)"
    Switch ($yn) {
        { @("y", "Y") -eq $_ } {
            Set-Variables
            $SCRIPT_DONE = $true
        }
        { @("n", "N") -eq $_ } {
            Get-Variables
            $SCRIPT_DONE = $true
        }
        default { "Please enter y or n." }
    }
}