#!/usr/bin/env bash
# Copyright (c) IBM Corporation.
# Copyright (c) Microsoft Corporation.

set -Eeuo pipefail

CURRENT_FILE_NAME="azure-credential-setup.sh"
echo "Execute $CURRENT_FILE_NAME - Start------------------------------------------"

## Create Azure Credentials
REPO_NAME=$(basename `git rev-parse --show-toplevel`)
AZURE_CREDENTIALS_SP_NAME="sp-${REPO_NAME}-$(date +%s)"
echo "Creating Azure Service Principal with name: $AZURE_CREDENTIALS_SP_NAME"
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv| tr -d '\r\n')
AZURE_CREDENTIALS=$(az ad sp create-for-rbac --name "$AZURE_CREDENTIALS_SP_NAME" --role owner --scopes /subscriptions/"$AZURE_SUBSCRIPTION_ID" --sdk-auth)

## Set the Azure Credentials as a secret in the repository

# Get the origin URL and extract the organization/repo
origin_url=$(git remote get-url origin)

if [[ $origin_url =~ ^git@github.com: ]]; then
    org_and_repo_name=${origin_url#git@github.com:}
elif [[ $origin_url =~ ^https://github.com/ ]]; then
    org_and_repo_name=${origin_url#https://github.com/}
else
    echo "Error: Unsupported remote URL format."
    exit 1
fi

# Remove the .git suffix
org_and_repo_name=${org_and_repo_name%.git}

gh secret --repo ${org_and_repo_name} set "AZURE_CREDENTIALS" -b"${AZURE_CREDENTIALS}"
gh variable --repo ${org_and_repo_name} set "AZURE_CREDENTIALS_SP_NAME" -b"${AZURE_CREDENTIALS_SP_NAME}"

echo "Execute $CURRENT_FILE_NAME - End--------------------------------------------"
