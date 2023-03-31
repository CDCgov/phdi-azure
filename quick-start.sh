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
  echo
  echo "Press $(pink 'Enter') when you're ready to continue."
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

# Create text box
box() {
  clear
  gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "$1"
}

### Main ###

# Install gum
export PATH=$HOME/go/bin:$PATH
if ! command -v gum &> /dev/null; then
    echo "Installing gum..."
    go install github.com/charmbracelet/gum@v0.8
fi

# Intro text
box "Welcome to the $(pink 'PHDI Azure') setup script!"
echo "This script will help you setup the PHDI Starter Kit in $(pink 'Azure'), including authentication for GitHub Actions."
echo "In order for the script to work properly you will need:"
echo "  1. Owner access to the Azure subscription where you would like to deploy the PHDI Starter Kit."
echo "  2. To be able to create new repositories in the GitHub account or organization where your copy of CDCgov/phdi-azure will be created."
enter_to_continue

echo "Please select the $(pink 'location') you would like to deploy to."
echo "More info: https://azure.microsoft.com/en-us/explore/global-infrastructure/geographies/#overview"
echo
LOCATION=$(gum choose "eastus" "eastus2" "westus" "westus3" "northcentralus" "southcentralus" "centralus")

echo "Please enter the $(pink 'Authorization ID') of your Smarty Street Account."
echo "More info: https://www.smarty.com/docs/cloud/authentication"
echo
SMARTY_AUTH_ID=$(gum input --placeholder="Authorization ID")

echo "Please enter the $(pink 'Authorization Token') of your Smarty Street Account."
echo "More info: https://www.smarty.com/docs/cloud/authentication"
echo
SMARTY_AUTH_TOKEN=$(gum input --placeholder="Authorization Token")

echo "Please select the $(pink 'License Type') of your Smarty Street Account."
echo "More info: https://www.smarty.com/docs/cloud/licensing"
echo
SMARTY_LICENSE_TYPE=$(gum choose "us-standard-cloud" "us-core-cloud" "us-rooftop-geocoding-cloud" "us-rooftop-geocoding-enterprise-cloud" "us-autocomplete-pro-cloud" "international-global-plus-cloud")

# Login to gh CLI
clear
echo "We will now login to the $(pink 'GitHub CLI')."
echo "For this step, you will need a GitHub account with a verified email address."
echo
echo "• After pressing enter, copy the provided code, and then $(pink 'press') enter."
echo "• $(pink 'Azure will fail to open the url'), so please copy it and manually navigate there in a $(pink 'new tab')"
echo "• If your account has $(pink '2FA') enabled, you will be prompted to enter a 2FA code (this is $(pink 'different') from the code you copied)."
echo "• If you plan to use an $(pink 'organization') account, be sure to click the green \"Authorize\" button next to that organization when prompted."
echo "• After logging in, paste the code into the input and follow the prompts to authorize the GitHub CLI."
echo "• Then return to this terminal!"
echo
enter_to_continue

gh auth login --hostname github.com -p https -w
GITHUB_USER=$(gh api user -q '.login')

while [[ -z $GITHUB_USER ]]; do
  echo "You must log in to $(pink 'GitHub') to continue or exit the script."
  gh auth login --hostname github.com -p https -w
  GITHUB_USER=$(gh api user -q '.login')
done

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
  RESOURCE_GROUP_NAME=$(gum input --prompt="Please enter a name for a new $(pink 'Resource Group'). Names may not contain spaces: " --placeholder="Resource Group name")
  while [[ $RESOURCE_GROUP_NAME = *" "* ]]; do
    echo "Your Resource Group Name contains spaces. Please create a new name with no spaces."
    RESOURCE_GROUP_NAME=$(gum input --prompt="Please enter a name for a new $(pink 'Resource Group'). Names may not contain spaces: " --placeholder="Resource Group name")
  done
  spin "Creating $(pink 'Resource Group')..." az group create --name "${RESOURCE_GROUP_NAME}" --location "${LOCATION}"
  RESOURCE_GROUP_ID=$(az group show -n $RESOURCE_GROUP_NAME --query "id" -o tsv)
fi

# Get tenant and subscription IDs
TENANT_ID=$(az account show --query "tenantId" -o tsv)
SUBSCRIPTION_ID="$(az account show --query "id" -o tsv)"

# Set the current resource group to the RESOURCE_GROUP_NAME specified above
az config set defaults.group="${RESOURCE_GROUP_NAME}"

box "Resource Group $(pink 'set')!"

# Get organization name
if gum confirm "Will you be using an organization account or your personal account?" --affirmative="Organization" --negative="Personal account"; then
  # Organization
  echo "Please choose organization you would like to use:"
  echo
  ORG_NAME=$(gh api user/orgs -q '.[].login' | gum choose)
  ORG_FLAG="--org ${ORG_NAME}"
else
  # Personal account
  ORG_NAME="${GITHUB_USER}"
  ORG_FLAG=""
fi

# Get repo name or create a new repo
if gum confirm "Have you already forked or copied the $(pink 'phdi-azure') repository on GitHub?"; then
  # Repo already exists
  echo "Please choose repository you would like to use:"
  echo
  REPO_NAME=$(gh repo list $ORG_NAME --json name --jq ".[].name" | gum choose)
  GITHUB_REPO="${ORG_NAME}/${REPO_NAME}"
else
  # Repo needs to be created
  GITHUB_REPO="${ORG_NAME}/phdi-azure"
  if gum confirm "Would you like to use a public or private repository?" --affirmative="Public" --negative="Private"; then
    # Public repo
    spin "Forking repository..." gh repo fork ${ORG_FLAG} CDCgov/phdi-azure
  else
    # Private repo
    PRIVATE="true"
    spin "Creating private repo..." gh repo create --private $GITHUB_REPO
    spin "Copying files..." git push --mirror https://github.com/${GITHUB_REPO}.git
  fi
fi

box "GitHub repository $(pink 'set')!"
echo

# Define app registration name, get client ID.
APP_REG_NAME=github-$RESOURCE_GROUP_NAME
CLIENT_ID=$(az ad app create --display-name $APP_REG_NAME --query appId --output tsv)

# Create custom role needed for container app creation
cat << EOF > role.json
{
    "Name": "App Resource Provider Registrant",
    "Description": "Register Microsoft.App resource provider for the subscription",
    "Actions": [
        "Microsoft.App/register/action",
        "Microsoft.OperationalInsights/register/action"
    ],
    "AssignableScopes": ["/subscriptions/$SUBSCRIPTION_ID"]
}
EOF
spin "Creating custom role..." az role definition create --role-definition role.json

# Create service principal and grant necessary roles
spin "Creating service principal..." az ad sp create-for-rbac --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME --role owner --name $APP_REG_NAME
OBJECT_ID=$(az ad sp show --id $CLIENT_ID --query id --output tsv)

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

spin "Creating federated credential..." az ad app federated-credential create --id $CLIENT_ID --parameters credentials.json
az role assignment create --assignee "$CLIENT_ID" --role "App Resource Provider Registrant" --scope "/subscriptions/$SUBSCRIPTION_ID"  

# Add Application.ReadWrite.All permission to the app
spin "Adding Application.ReadWrite.All permission..." az ad app permission add --id $CLIENT_ID --api 00000003-0000-0000-c000-000000000000 --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role
spin "Granting admin consent..." az ad app permission admin-consent --id $CLIENT_ID

# Cleanup
rm role.json
rm credentials.json

echo "Workload Identity Federation setup complete!"
echo

### GitHub Actions ###

# Set up GitHub Secrets
spin "Setting RESOURCE_GROUP_NAME..." gh -R "${GITHUB_REPO}" secret set RESOURCE_GROUP_NAME --body "${RESOURCE_GROUP_NAME}"
spin "Setting SUBSCRIPTION_ID..." gh -R "${GITHUB_REPO}" secret set SUBSCRIPTION_ID --body "${SUBSCRIPTION_ID}"
spin "Setting CLIENT_ID..." gh -R "${GITHUB_REPO}" secret set CLIENT_ID --body "${CLIENT_ID}"
spin "Setting OBJECT_ID..." gh -R "${GITHUB_REPO}" secret set OBJECT_ID --body "${OBJECT_ID}"
spin "Setting LOCATION..." gh -R "${GITHUB_REPO}" secret set LOCATION --body "${LOCATION}"
spin "Setting TENANT_ID..." gh -R "${GITHUB_REPO}" secret set TENANT_ID --body "${TENANT_ID}"
spin "Setting SMARTY_AUTH_ID..." gh -R "${GITHUB_REPO}" secret set SMARTY_AUTH_ID --body "${SMARTY_AUTH_ID}"
spin "Setting SMARTY_AUTH_TOKEN..." gh -R "${GITHUB_REPO}" secret set SMARTY_AUTH_TOKEN --body "${SMARTY_AUTH_TOKEN}"
spin "Setting SMARTY_LICENSE_TYPE..." gh -R "${GITHUB_REPO}" secret set SMARTY_LICENSE_TYPE --body "${SMARTY_LICENSE_TYPE}"

box "Repository secrets $(pink 'set')!"
echo

# Create dev environment in GitHub
spin "Creating $(pink 'dev') environment..." gh api -X PUT "repos/${GITHUB_REPO}/environments/dev" --silent

# Enable GitHub Actions
GITHUB_ACTIONS_URL="https://github.com/${GITHUB_REPO}/actions"
if [[ $PRIVATE != "true" ]]; then
  echo "To deploy your new pipeline, you'll need to enable $(pink 'GitHub Workflows')."
  echo
  echo "Please open $(pink $GITHUB_ACTIONS_URL) in a new tab."
  echo "Click the green button to enable $(pink 'GitHub Workflows')."
  echo
  echo "Continuing from this point will begin a series of GitHub actions that may take 20+ minutes to complete"

  enter_to_continue

  WORKFLOWS_ENABLED=$(gh api -X GET "repos/${GITHUB_REPO}/actions/workflows" -q '.total_count')
  while [ "$WORKFLOWS_ENABLED" = "0" ]; do
    echo "Looks like that didn't work! Please try again."
    echo "Please open $GITHUB_ACTIONS_URL in a new tab."
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
fi

echo "If you would like to see the following workflows run in more detail please click here:"
echo $(pink $GITHUB_ACTIONS_URL)

# Run Terraform Setup workflow
echo "We will now run the $(pink 'Terraform Setup') workflow."
echo "This will create the necessary storage account for Terraform in Azure."
echo
spin "Waiting for $(pink 'Workload Identity') to be ready..." sleep 10
spin "Starting Terraform Setup workflow..." gh -R "${GITHUB_REPO}" workflow run terraformSetup.yaml
echo

# Watch Terraform Setup workflow until complete
TIMESTAMP=$(date --date="5 min ago" +"%s")
TF_SETUP_STARTED=$(gh -R "${GITHUB_REPO}" run list --workflow=terraformSetup.yaml --json databaseId,createdAt -q "map(select(.createdAt | fromdateiso8601 > $TIMESTAMP)) | length")
CHECK_COUNT=0
while [ "$TF_SETUP_STARTED" = "0" ]; do
  if [ "$CHECK_COUNT" -gt 60 ]; then
    echo "Looks like that didn't work! Please contact the PHDI team for help."
    exit 1
  fi
  spin "Waiting for Terraform Setup workflow to start..." sleep 1
  TF_SETUP_STARTED=$(gh -R "${GITHUB_REPO}" run list --workflow=terraformSetup.yaml --json databaseId,createdAt -q "map(select(.createdAt | fromdateiso8601 > $TIMESTAMP)) | length")
  CHECK_COUNT=$((CHECK_COUNT+1))
done
TF_SETUP_WORKFLOW_ID=$(gh -R "${GITHUB_REPO}" run list --workflow=terraformSetup.yaml --json databaseId,createdAt -q "map(select(.createdAt | fromdateiso8601 > $TIMESTAMP)) | .[0].databaseId")
gh -R "${GITHUB_REPO}" run watch $TF_SETUP_WORKFLOW_ID

# Check for Terraform Setup workflow success
TF_SETUP_SUCCESS=$(gh -R "${GITHUB_REPO}" run view $TF_SETUP_WORKFLOW_ID --json conclusion -q '.conclusion')
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
TIMESTAMP=$(date --date="5 min ago" +"%s")
DEPLOYMENT_STARTED=$(gh -R "${GITHUB_REPO}" run list --workflow=deployment.yaml  --json databaseId,createdAt -q "map(select(.createdAt | fromdateiso8601 > $TIMESTAMP)) | length")
CHECK_COUNT=0
while [ "$DEPLOYMENT_STARTED" = "0" ]; do
  if [ "$CHECK_COUNT" -gt 60 ]; then
    echo "Looks like that didn't work! Please contact the PHDI team for help."
    exit 1
  fi
  spin "Waiting for deployment workflow to start..." sleep 1
  DEPLOYMENT_STARTED=$(gh -R "${GITHUB_REPO}" run list --workflow=deployment.yaml  --json databaseId,createdAt -q "map(select(.createdAt | fromdateiso8601 > $TIMESTAMP)) | length")
  CHECK_COUNT=$((CHECK_COUNT+1))
done
DEPLOYMENT_WORKFLOW_ID=$(gh -R "${GITHUB_REPO}" run list --workflow=deployment.yaml --json databaseId,createdAt -q "map(select(.createdAt | fromdateiso8601 > $TIMESTAMP)) | .[0].databaseId")
gh -R "${GITHUB_REPO}" run watch $DEPLOYMENT_WORKFLOW_ID

# Check for deployment workflow success
DEPLOY_SUCCESS=$(gh -R "${GITHUB_REPO}" run view $DEPLOYMENT_WORKFLOW_ID --json conclusion -q '.conclusion')
if [ "$DEPLOY_SUCCESS" != "success" ]; then
  echo "Looks like that didn't work! Please contact the PHDI team for help."
  echo "To view the status of your workflows, go to $GITHUB_ACTIONS_URL."
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