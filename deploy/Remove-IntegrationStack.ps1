# Remove Integration Stack Resources
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",

    [Parameter(Mandatory=$false)]
    [switch]$DeleteResourceGroup
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

# List resources that will be deleted
Write-Host "Resources in group $ResourceGroupName that will be removed:" -ForegroundColor Yellow
az resource list --resource-group $ResourceGroupName --output table

# Prompt for confirmation
$confirmation = Read-Host "Are you sure you want to delete these resources? This cannot be undone. Type 'yes' to confirm"
if ($confirmation -ne 'yes') {
    Write-Host "Cleanup cancelled." -ForegroundColor Green
    exit 0
}

Write-Host "Starting cleanup..." -ForegroundColor Yellow

# Remove resources in order (reverse dependency order)
$functionAppName = "func-order-sync-$Environment"
$logicAppName = "logicapp-order-sync-$Environment"

# 1. Remove Logic App (and its connections)
Write-Host "Removing Logic App..." -ForegroundColor Cyan
az logic workflow delete --resource-group $ResourceGroupName --name $logicAppName --yes
# Remove API Connections
Write-Host "Removing API Connections..." -ForegroundColor Cyan
az resource list --resource-group $ResourceGroupName --resource-type "Microsoft.Web/connections" --query "[].name" -o tsv | ForEach-Object {
    Write-Host "Removing connection: $_"
    az resource delete --resource-group $ResourceGroupName --resource-type "Microsoft.Web/connections" --name $_ --verbose
}

# 2. Remove Function App
Write-Host "Removing Function App..." -ForegroundColor Cyan
az functionapp delete --resource-group $ResourceGroupName --name $functionAppName --yes

# 3. Remove Role Assignments (clean up RBAC)
Write-Host "Removing role assignments..." -ForegroundColor Cyan
az role assignment list --resource-group $ResourceGroupName --query "[?contains(principalName, '$functionAppName') || contains(principalName, '$logicAppName')].id" -o tsv | ForEach-Object {
    Write-Host "Removing role assignment: $_"
    az role assignment delete --ids "$_"
}

# 4. Remove Key Vault (requires soft-delete purge if you want to recreate with same name)
$keyVaultName = "kv-integration-$Environment"
Write-Host "Removing Key Vault..." -ForegroundColor Cyan
az keyvault delete --name $keyVaultName --resource-group $ResourceGroupName
Write-Host "Purging Key Vault (waiting 30s for deletion to complete)..." -ForegroundColor Cyan
Start-Sleep -Seconds 30
az keyvault purge --name $keyVaultName

# 5. Remove Storage Account
$storageAccountName = "stintdev$Environment"
Write-Host "Removing Storage Account..." -ForegroundColor Cyan
az storage account delete --name $storageAccountName --resource-group $ResourceGroupName --yes

# 6. Remove App Service Plan
$appServicePlanName = "asp-integration-$Environment"
Write-Host "Removing App Service Plan..." -ForegroundColor Cyan
az appservice plan delete --name $appServicePlanName --resource-group $ResourceGroupName --yes

# Optionally delete the entire resource group
if ($DeleteResourceGroup) {
    Write-Host "Removing entire Resource Group..." -ForegroundColor Red
    az group delete --name $ResourceGroupName --yes --no-wait
    Write-Host "Resource Group deletion initiated. This will take several minutes to complete." -ForegroundColor Yellow
} else {
    Write-Host "Resource Group '$ResourceGroupName' was preserved. To delete it, rerun with -DeleteResourceGroup switch." -ForegroundColor Green
}

Write-Host "Cleanup complete!" -ForegroundColor Green