# Deploy Integration Stack
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [string]$Location = "westeurope",

    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",

    [Parameter(Mandatory=$false)]
    [string]$KeyVaultName = "kv-integration-$Environment",

    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName = "stintdev$Environment",

    [Parameter(Mandatory=$false)]
    [string]$AppServicePlanName = "asp-integration-$Environment"
)

# Ensure Az CLI is available
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in
$account = az account show | ConvertFrom-Json
if (-not $account) {
    Write-Host "Not logged in to Azure. Running 'az login'..."
    az login
}

# Create Resource Group if it doesn't exist
Write-Host "Ensuring Resource Group exists..."
az group create --name $ResourceGroupName --location $Location

# Create Storage Account if it doesn't exist
Write-Host "Creating Storage Account..."
az storage account create -n $StorageAccountName -g $ResourceGroupName -l $Location --sku Standard_LRS --kind StorageV2
$storageConn = az storage account show-connection-string -n $StorageAccountName -g $ResourceGroupName --query connectionString -o tsv

# Create Key Vault if it doesn't exist
Write-Host "Creating Key Vault..."
az keyvault create --name $KeyVaultName --resource-group $ResourceGroupName --location $Location

# Store connection string in Key Vault
Write-Host "Setting Key Vault secrets..."
az keyvault secret set --vault-name $KeyVaultName --name "StorageConnection" --value $storageConn

# Create App Service Plan if it doesn't exist
Write-Host "Creating App Service Plan..."
az appservice plan create -g $ResourceGroupName -n $AppServicePlanName --sku S1 --is-linux
$appServicePlanId = az appservice plan show -g $ResourceGroupName -n $AppServicePlanName --query id -o tsv

# Look up role definition IDs
Write-Host "Looking up role definition IDs..."
$keyVaultSecretsUserRoleId = az role definition list --name "Key Vault Secrets User" --query "[0].id" -o tsv
$functionInvokeRoleId = az role definition list --name "Website Contributor" --query "[0].id" -o tsv

# Deploy Bicep template
Write-Host "Running what-if deployment..."
az deployment group what-if `
    --resource-group $ResourceGroupName `
    --template-file ./bicep/main.bicep `
    --parameters environment=$Environment `
    --parameters location=$Location `
    --parameters keyVaultName=$KeyVaultName `
    --parameters appServicePlanId=$appServicePlanId `
    --parameters keyVaultSecretsUserRoleId=$keyVaultSecretsUserRoleId `
    --parameters functionInvokeRoleId=$functionInvokeRoleId

# Prompt for confirmation
$confirmation = Read-Host "Do you want to proceed with the deployment? (y/n)"
if ($confirmation -ne 'y') {
    Write-Host "Deployment cancelled."
    exit 0
}

Write-Host "Deploying Bicep template..."
az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file ./bicep/main.bicep `
    --parameters environment=$Environment `
    --parameters location=$Location `
    --parameters keyVaultName=$KeyVaultName `
    --parameters appServicePlanId=$appServicePlanId `
    --parameters keyVaultSecretsUserRoleId=$keyVaultSecretsUserRoleId `
    --parameters functionInvokeRoleId=$functionInvokeRoleId

# Deploy Function App code
Write-Host "Deploying Function App code..."
$functionName = "func-order-sync-$Environment"

# Create zip package
Compress-Archive -Path ./functionapp/HttpTrigger1/* -DestinationPath ./functionapp/HttpTrigger1.zip -Force

# Deploy via zip
az functionapp deployment source config-zip --name $functionName --resource-group $ResourceGroupName --src ./functionapp/HttpTrigger1.zip

Write-Host "Deployment complete! Testing endpoints..."

# Get function key
$functionKeys = az functionapp function keys list --resource-group $ResourceGroupName --name $functionName --function-name HttpTrigger1 | ConvertFrom-Json
$defaultKey = $functionKeys.default

# Test the function
$functionUrl = "https://$functionName.azurewebsites.net/api/HttpTrigger1?code=$defaultKey&id=123"
Write-Host "Testing function at: $functionUrl"
try {
    $response = Invoke-WebRequest -Uri $functionUrl -UseBasicParsing
    Write-Host "Function test result: $($response.StatusCode) $($response.StatusDescription)"
} catch {
    Write-Warning "Function test failed: $_"
}

Write-Host @"
Deployment Summary:
------------------
Resource Group: $ResourceGroupName
Environment: $Environment
Key Vault: $KeyVaultName
Storage Account: $StorageAccountName
Function App: $functionName
Logic App: logicapp-order-sync-$Environment

Next Steps:
1. Verify Logic App connections in Azure Portal
2. Test the blob trigger by uploading a file to the 'orders' container
3. Monitor Function App logs for any issues
4. Check Logic App run history after triggering
"@