#!/bin/bash

################################################################################
#
# This script is used to setup Azure authentication for GitHub Actions.
# It is based on the following guide: https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azcli
#
################################################################################

### Functions ###
# Enter to continue
enter_to_continue() {
  echo "Press $(pink 'Enter') when you're done."
  echo
  read
}

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
enter_to_continue

echo "Please select the $(pink 'location') you would like to deploy to."
echo "More info: https://azure.microsoft.com/en-us/explore/global-infrastructure/geographies/#overview"
echo
LOCATION=$(gum choose "eastus" "eastus2" "westus" "westus2" "westus3" "southcentralus" "centralus")

echo "Please enter the $(pink 'Authorization ID') of your Smarty Street Account."
echo "More info: https://www.smarty.com/docs/cloud/authentication"
echo
SMARTY_AUTH_ID=$(gum input --placeholder="Authorization ID")

echo "Please enter the $(pink 'Authorization Token') of your Smarty Street Account."
echo "More info: https://www.smarty.com/docs/cloud/authentication"
echo
SMARTY_AUTH_TOKEN=$(gum input --placeholder="Authorization Token")

# Check if new project, create a project if needed and get the project ID
if gum confirm "Do you already have a $(pink 'Resource Group') in Azure?"; then
  NEW_RESOURCE_GROUP=false
  echo "We will now get the ID of your existing Azure $(pink 'Resource Group')."
  echo

  echo "Please select the $(pink 'Resource Group') you want to use:"
  RESOURCE_GROUP_NAME=$(az group list --query "[].name" -o tsv | gum choose)
  RESOURCE_GROUP_ID=$(az group show -n $RESOURCE_GROUP_NAME --query "id" -o tsv)
  echo "You selected $(pink "${RESOURCE_GROUP_NAME}") with ID $(pink "${RESOURCE_GROUP_ID}")."
  echo

else
  NEW_RESOURCE_GROUP=true
  echo "Thank you! We will now attempt to create a new Azure $(pink 'Resource Group') for you."
  echo
  RESOURCE_GROUP_NAME=$(gum input --prompt="Please enter a name for a new $(pink 'Resource Group'). " --placeholder="Resource Group name")
  spin "Creating $(pink 'Resource Group')..." az group create --name "${RESOURCE_GROUP_NAME}" --location "${LOCATION}"
  RESOURCE_GROUP_ID=$(az group show -n $RESOURCE_GROUP_NAME --query "id" -o tsv)
fi

# Get tenant and subscription IDs
TENANT_ID=$(az account show --query "tenantId" -o tsv)
SUBSCRIPTION_ID="$(az account show --query "id" -o tsv)"

# Set the current resource group to the RESOURCE_GROUP_NAME specified above
az config set defaults.group="${RESOURCE_GROUP_NAME}"

# Login to gh CLI
echo "Project ID $(pink 'set')!"
echo "We will now login to the $(pink 'GitHub CLI')."
echo "Copy the provided code, press $(pink 'Enter') and then $(pink 'click') the link that will be printed."
echo "If you are not already logged in to GitHub, you will be prompted to do so."
echo "If your account has $(pink '2FA') enabled, you will be prompted to enter a 2FA code (this is $(pink 'different') from the code you copied)."
echo "After logging in, paste the code into the input and follow the prompts to authorize the GitHub CLI."
echo "Then return to this terminal!"
enter_to_continue

gh auth login --hostname github.com -p https -w
GITHUB_USER=$(gh api user -q '.login')

# Check if repo already forked, fork if needed, get repository name
if gum confirm "Have you already forked the $(pink 'phdi-azure') repository on GitHub?"; then
  echo "Please choose repository you would like to use:"
  echo
  REPO_NAME=$(gh repo list --fork --json name --jq ".[].name" | gum choose)
  GITHUB_REPO="${GITHUB_USER}/${REPO_NAME}"
else
  if gum confirm "Would you like to fork into an organization or your personal account?" --affirmative="Organization" --negative="Personal account"; then
    echo "Please choose organization you would like to fork into:"
    echo
    ORG_NAME="--org $(gh api user/orgs -q '.[].login' | gum choose)"
  else
    ORG_NAME=""
  fi
  spin "Forking repository..." gh repo fork ${ORG_NAME} CDCgov/phdi-azure
  GITHUB_REPO="${GITHUB_USER}/phdi-azure"
fi
echo "GitHub repository $(pink 'set')!"
echo

# Define app registration name, get client ID.
APP_REG_NAME=grithub
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

### GitHub Actions ###

# Set up GitHub Secrets
spin "Setting PROJECT_ID..." gh -R "${GITHUB_REPO}" secret set PROJECT_ID --body "${PROJECT_ID}"
spin "Setting SERVICE_ACCOUNT_ID..." gh -R "${GITHUB_REPO}" secret set SERVICE_ACCOUNT_ID --body "${SERVICE_ACCOUNT_ID}"
spin "Setting WORKLOAD_IDENTITY_PROVIDER..." gh -R "${GITHUB_REPO}" secret set WORKLOAD_IDENTITY_PROVIDER --body "${WORKLOAD_IDENTITY_PROVIDER}"
spin "Setting REGION..." gh -R "${GITHUB_REPO}" secret set REGION --body "${REGION}"
spin "Setting ZONE..." gh -R "${GITHUB_REPO}" secret set ZONE --body "${ZONE}"
spin "Setting SMARTY_AUTH_ID..." gh -R "${GITHUB_REPO}" secret set SMARTY_AUTH_ID --body "${SMARTY_AUTH_ID}"
spin "Setting SMARTY_AUTH_TOKEN..." gh -R "${GITHUB_REPO}" secret set SMARTY_AUTH_TOKEN --body "${SMARTY_AUTH_TOKEN}"

echo "Repository secrets $(pink 'set')!"
echo

# Create dev environment in GitHub
spin "Creating $(pink 'dev') environment..." gh api -X PUT "repos/${GITHUB_REPO}/environments/dev" --silent

# Enable GitHub Actions
echo "To deploy your new pipeline, you'll need to enable $(pink 'GitHub Workflows')."
echo "Please open https://github.com/${GITHUB_REPO}/actions in a new tab."
echo "Click the green button to enable $(pink 'GitHub Workflows')."
enter_to_continue

WORKFLOWS_ENABLED=$(gh api -X GET "repos/${GITHUB_REPO}/actions/workflows" -q '.total_count')
while [ "$WORKFLOWS_ENABLED" = "0" ]; do
  echo "Looks like that didn't work! Please try again."
  echo "Please open https://github.com/${GITHUB_REPO}/actions in a new tab."
  echo "Click the green button to enable $(pink 'GitHub Workflows')."
  echo "Press $(pink 'Enter') when you're done. Type $(pink 'exit') to exit the script."
  echo
  read SHOULD_CONTINUE
  if [ "$SHOULD_CONTINUE" = "exit" ]; then
    exit 1
  else
    WORKFLOWS_ENABLED=$(gh api -X GET "repos/${GITHUB_REPO}/actions/workflows" -q '.total_count')
  fi
done

# Run Terraform Setup workflow
echo "We will now run the $(pink 'Terraform Setup') workflow."
echo "This will create the necessary storage account for Terraform in Azure."
echo
spin "Waiting for $(pink 'Workload Identity') to be ready (this will take a minute)..." sleep 60
spin "Starting Terraform Setup workflow..." gh -R "${GITHUB_REPO}" workflow run terraformSetup.yaml
echo

# Watch Terraform Setup workflow until complete
TF_SETUP_STARTED=$(gh -R "${GITHUB_REPO}" run list --workflow=terraformSetup.yaml --json databaseId -q ". | length")
CHECK_COUNT=0
while [ "$TF_SETUP_STARTED" = "0" ]; do
  if [ "$CHECK_COUNT" -gt 60 ]; then
    echo "Looks like that didn't work! Please contact the PHDI team for help."
    exit 1
  fi
  spin "Waiting for Terraform Setup workflow to start..." sleep 1
  TF_SETUP_STARTED=$(gh -R "${GITHUB_REPO}" run list --workflow=terraformSetup.yaml --json databaseId -q ". | length")
  CHECK_COUNT=$((CHECK_COUNT+1))
done
TF_SETUP_WORKFLOW_ID=$(gh -R "${GITHUB_REPO}" run list --workflow=terraformSetup.yaml -L 1 --json databaseId -q ".[0].databaseId")
gh -R "${GITHUB_REPO}" run watch $TF_SETUP_WORKFLOW_ID

# Check for Terraform Setup workflow success
TF_SETUP_SUCCESS=$(gh -R "${GITHUB_REPO}" run list --workflow=terraformSetup.yaml --json conclusion -q '.[].conclusion')
if [ "$TF_SETUP_SUCCESS" != "success" ]; then
  echo "Looks like that didn't work! Please contact the PHDI team for help."
  exit 1
fi

# Run deployment workflow
echo "We will now run the $(pink 'Terraform Deploy') workflow."
echo "This will deploy the infrastructure to your Azure Resource Group."
echo
spin "Running Terraform Deploy workflow..." gh -R "${GITHUB_REPO}" workflow run deployment.yaml -f environment=dev
echo

# Watch deployment workflow until complete
DEPLOYMENT_STARTED=$(gh -R "${GITHUB_REPO}" run list --workflow=deployment.yaml --json databaseId -q ". | length")
CHECK_COUNT=0
while [ "$DEPLOYMENT_STARTED" = "0" ]; do
  if [ "$CHECK_COUNT" -gt 60 ]; then
    echo "Looks like that didn't work! Please contact the PHDI team for help."
    exit 1
  fi
  spin "Waiting for deployment workflow to start..." sleep 1
  DEPLOYMENT_STARTED=$(gh -R "${GITHUB_REPO}" run list --workflow=deployment.yaml --json databaseId -q ". | length")
  CHECK_COUNT=$((CHECK_COUNT+1))
done
DEPLOYMENT_WORKFLOW_ID=$(gh -R "${GITHUB_REPO}" run list --workflow=deployment.yaml -L 1 --json databaseId -q ".[0].databaseId")
gh -R "${GITHUB_REPO}" run watch $DEPLOYMENT_WORKFLOW_ID

# Check for deployment workflow success
DEPLOY_SUCCESS=$(gh -R "${GITHUB_REPO}" run list --workflow=deployment.yaml --json conclusion -q '.[].conclusion')
if [ "$DEPLOY_SUCCESS" != "success" ]; then
  echo "Looks like that didn't work! Please contact the PHDI team for help."
  echo "To view the status of your workflows, go to https://github.com/${GITHUB_REPO}/actions."
  echo
  exit 1
fi

# Sendoff
clear
gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "Quick start $(pink 'complete')! You can view your forked repository at https://github.com/${GITHUB_REPO}"
echo
echo "Your infrastructure is $(pink 'deployed')!"
echo "To trigger your new pipeline, upload a file to the storage account starting with $(pink 'phdidevphi') at this link:"
echo "https://portal.azure.com/#view/HubsExtension/BrowseResource/resourceType/Microsoft.Storage%2FStorageAccounts"
echo

echo "Thanks for using the $(pink 'PHDI Azure') quick start script!"
echo