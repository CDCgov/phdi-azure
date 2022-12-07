#!/bin/bash

################################################################################
#
# This script is used to setup Azure authentication for GitHub Actions.
# It is based on the following guide: https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azcli
#
################################################################################

### Functions ###

# Colorize text
colorize() {
  gum style --foreground "$1" "$2"
}

# Print pink text
pink() {
  colorize 212 "$1"
}

# Run a command with a spinner
spin() {
  local -r title="${1}"
  shift 1
  gum spin -s line --title "${title}" -- $@
}

### Main ###

# Install gum
if ! command -v gum &> /dev/null; then
    echo "Installing gum..."
    go install github.com/charmbracelet/gum@v0.8
fi

export PATH=$HOME/go/bin:$PATH

clear


# Intro text
gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "Welcome to the $(pink 'PHDI Azure') setup script!"
echo "This script will help you setup $(pink 'Azure') authentication for GitHub Actions."
echo "We need some info from you to get started."
echo


# Check if new project, create a project if needed and get the project ID
if gum confirm "Do you already have a $(pink 'Resource Group') in Azure?"; then
  NEW_PROJECT=false
  echo "We will now get the ID of your existing Azure $(pink 'Resource Group')."
  echo

  echo "Please select the $(pink 'Resource Group') you want to use:"
  PROJECT_NAME=$(az group list --query "[].name" -o tsv | gum choose)
  PROJECT_ID=$(az group show -n $PROJECT_NAME --query "[].id" -o tsv)
  echo "You selected $(pink "${PROJECT_NAME}") with ID $(pink "${PROJECT_ID}")."
  echo

else
  NEW_PROJECT=true
  echo "Thank you! We will now attempt to create a new Azure $(pink 'Resource Group') for you."
  echo "A window will open asking you to authorize the gcloud CLI. Please click '$(pink 'Authorize')'."
  echo

  PROJECT_NAME=$(gum input --prompt="Please enter a name for a new $(pink 'Project'). " --placeholder="Project name")
  PROJECT_ID=$(echo $PROJECT_NAME | awk '{print tolower($0)}')-$(date +"%s")
  spin "Creating $(pink 'project')..." gcloud projects create $PROJECT_ID --name="${PROJECT_NAME}"

  # Link billing account to project
  link_billing_account
fi


# Prompt user for resource group name and repository name
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
az ad sp create-for-rbac --scopes /subscriptions/$SUBSCRIPTION_ID --role owner --name $APP_REG_NAME

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

until az ad app show --id $CLIENT_ID &> /dev/null; do
  echo "Waiting for app to be created..."
  sleep 5
done

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