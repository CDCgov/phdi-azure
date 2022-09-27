#!/bin/bash

################################################################################
#
# This script is used to setup Azure authentication for GitHub Actions.
# It is based on the following guide: https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azcli
#
################################################################################

# Function to output the variables needed to load into GitHub Actions secrets
print_variables() {
  echo "Please load the following variables into your repository secrets at this URL:"
  echo "https://github.com/$GITHUB_REPO/settings/secrets/actions"
  echo
  echo "TENANT_ID: ${TENANT_ID}"
  echo "SUBSCRIPTION_ID: ${SUBSCRIPTION_ID}"
  echo "CLIENT_ID: ${CLIENT_ID}"
  echo "RESOURCE_GROUP_NAME: ${RESOURCE_GROUP_NAME}"
  echo "LOCATION: ${LOCATION}"
  echo "SMARTY_AUTH_ID: Your Smarty Streets App Authorization ID"
  echo "SMARTY_AUTH_TOKEN: Your Smarty Streets App Authorization Token"
  echo
  echo "More info on locations can be found at:"
  echo "https://azure.microsoft.com/en-us/explore/global-infrastructure/geographies/#overview"
  echo
  echo "You can now continue with the Quick Start instructions in the README.md file."
}

# Function to use GitHub CLI to set repository secrets
set_variables() {
  if ! command -v gh &> /dev/null; then
    echo "Error: The GitHub CLI is not installed. To install, visit this page:"
    echo "https://cli.github.com/manual/installation"
    echo
    print_variables
    exit
  fi

  echo "Please enter the authorization id of your Smarty Street Account."
  echo "More info:   https://www.smarty.com/docs/cloud/authentication"
  read SMARTY_AUTH_ID

  echo "Please enter the authorization token of your Smarty Street Account."
  echo "More info:   https://www.smarty.com/docs/cloud/authentication"
  read SMARTY_AUTH_TOKEN

  echo "Logging in to GitHub..."
  gh auth login

  echo "Setting repository secrets..."
  gh secret -R "${GITHUB_REPO}" set TENANT_ID --body "${TENANT_ID}"
  gh secret -R "${GITHUB_REPO}" set SUBSCRIPTION_ID --body "${SUBSCRIPTION_ID}"
  gh secret -R "${GITHUB_REPO}" set CLIENT_ID --body "${CLIENT_ID}"
  gh secret -R "${GITHUB_REPO}" set RESOURCE_GROUP_NAME --body "${RESOURCE_GROUP_NAME}"
  gh secret -R "${GITHUB_REPO}" set LOCATION --body "${LOCATION}"
  gh secret -R "${GITHUB_REPO}" set SMARTY_AUTH_ID --body "${SMARTY_AUTH_ID}"
  gh secret -R "${GITHUB_REPO}" set SMARTY_AUTH_TOKEN --body "${SMARTY_AUTH_TOKEN}"

  echo "Repository secrets set!"
  echo "You can now continue with the Quick Start instructions in the README.md file."
}

# Prompt user for resource group name and repository name
echo "Welcome to the PHDI Azure setup script!"
echo "This script will help you setup az CLI authentication for GitHub Actions."
echo "We need some info from you to get started."
echo "After entering the info, a browser window will open for you to authenticate with Azure."
echo
while true; do
    read -p "Do you already have a Resource Group in Azure? (y/n) " yn
    case $yn in
        [Yy]* ) read -p "Please enter the name of the existing Resource Group. " RESOURCE_GROUP_NAME; NEW_RESOURCE_GROUP=false; break;;
        [Nn]* ) read -p "Please enter a name for a new Resource Group. " RESOURCE_GROUP_NAME; NEW_RESOURCE_GROUP=true; break;;
        * ) echo "Please answer y or n.";;
    esac
done
echo "Please enter the name of the repository you will be deploying from."
echo "For example, if your repo URL is https://github.com/CDCgov/phdi-azure, enter: CDCgov/phdi-azure"
read GITHUB_REPO

echo "Please enter the name of the location you would like to deploy to (e.g. centralus)."
echo "More info: https://azure.microsoft.com/en-us/explore/global-infrastructure/geographies/#overview"
read LOCATION

# Login to Azure, get tenant and subscription IDs
az login
TENANT_ID=$(az account show --query "tenantId" -o tsv)
SUBSCRIPTION_ID="$(az account show --query "id" -o tsv)"

# Create a resource group if needed and get the resource group ID
if [ $NEW_RESOURCE_GROUP = true ]; then
    az group create --name "${RESOURCE_GROUP_NAME}" --location "${LOCATION}"
fi
RESOURCE_GROUP_ID=$(az group show --name "${RESOURCE_GROUP_NAME}" --query "id" -o tsv)
if [ -z "$RESOURCE_GROUP_ID" ]; then
    echo "Error: Resource Group ID not found. To list resource groups, run 'az group list'."
    exit 1
fi

# Set the current resource group to the RESOURCE_GROUP_NAME specified above
az config set defaults.group="${RESOURCE_GROUP_NAME}"

# Define app registration name, get client ID.
APP_REG_NAME=github
CLIENT_ID=$(az ad app create --display-name $APP_REG_NAME --query appId --output tsv)

# Create service principal and grant access to subscription
az ad sp create-for-rbac --scopes /subscriptions/$SUBSCRIPTION_ID --role contributor --name $APP_REG_NAME

# Create federated credential
cat << EOF > credentials.json
{
  "name": "$APP_REG_NAME",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:$GITHUB_REPO:environment:main",
  "description": "GitHub Actions",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
az ad app federated-credential create --id $CLIENT_ID --parameters credentials.json

echo "Workload Identity Federation setup complete!"
echo

while true; do
    read -p "Would you like to use the GitHub CLI to set repository secrets automatically? (y/n) " yn
    case $yn in
        [Yy]* ) set_variables; break;;
        [Nn]* ) print_variables; break;;
        * ) echo "Please answer y or n.";;
    esac
done