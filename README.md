# Integration Stack

This repository contains an Azure integration solution using Logic Apps, Function Apps, and API connections with managed identities and role-based access control (RBAC).

## Architecture

- Logic App workflow that processes order files from Blob Storage
- Function App with managed identity for D365 integration
- Key Vault for secret storage
- API Connections for Blob and Table Storage
- RBAC for secure inter-resource access

## Prerequisites

- Azure CLI
- PowerShell 7+
- Azure subscription with contributor access
- Git

## Quick Deploy

1. Clone the repository:
   ```powershell
   git clone <repo-url>
   cd integration-devopss
   ```

2. Run the deployment script:
   ```powershell
   ./deploy/Deploy-IntegrationStack.ps1 -ResourceGroupName rg-integration-dev
   ```

   Optional parameters:
   - `-Location` (default: westeurope)
   - `-Environment` (default: dev)
   - `-KeyVaultName` (default: kv-integration-{env})
   - `-StorageAccountName` (default: stintdev{env})
   - `-AppServicePlanName` (default: asp-integration-{env})

The script will:
1. Create/verify resource group
2. Create storage account and App Service Plan
3. Create Key Vault and store secrets
4. Deploy Bicep template (infrastructure)
5. Deploy Function App code
6. Test the endpoints

## Manual Deployment Steps

If you prefer to deploy manually or understand the deployment process:

1. Ensure Azure CLI is installed and you're logged in:
   ```powershell
   az login
   ```

2. Create a resource group:
   ```powershell
   az group create -n rg-integration-dev -l westeurope
   ```

3. Create storage account and get connection string:
   ```powershell
   $storageAccount = "stintdevXXX"  # replace XXX with unique numbers
   az storage account create -n $storageAccount -g rg-integration-dev -l westeurope --sku Standard_LRS
   $storageConn = az storage account show-connection-string -n $storageAccount -g rg-integration-dev --query connectionString -o tsv
   ```

4. Create Key Vault and store secrets:
   ```powershell
   az keyvault create -n kv-integration-dev -g rg-integration-dev -l westeurope
   az keyvault secret set --vault-name kv-integration-dev --name StorageConnection --value $storageConn
   ```

5. Create App Service Plan:
   ```powershell
   az appservice plan create -g rg-integration-dev -n asp-integration-dev --sku S1 --is-linux
   ```

6. Deploy Bicep template:
   ```powershell
   az deployment group create -g rg-integration-dev --template-file ./bicep/main.bicep `
     --parameters environment=dev `
     --parameters keyVaultName=kv-integration-dev `
     --parameters appServicePlanId="/subscriptions/<sub-id>/resourceGroups/rg-integration-dev/providers/Microsoft.Web/serverfarms/asp-integration-dev"
   ```

7. Deploy Function App code:
   ```powershell
   Compress-Archive -Path ./functionapp/HttpTrigger1/* -DestinationPath ./functionapp/HttpTrigger1.zip -Force
   az functionapp deployment source config-zip --name func-order-sync-dev --resource-group rg-integration-dev --src ./functionapp/HttpTrigger1.zip
   ```

## Testing

1. Test Function App:
   ```powershell
   $functionUrl = "https://func-order-sync-dev.azurewebsites.net/api/HttpTrigger1?id=123"
   Invoke-WebRequest -Uri $functionUrl -UseBasicParsing
   ```

2. Test Logic App:
   - Upload a file to the `orders` container in the storage account
   - Check Logic App run history in Azure Portal
   - Verify the entry in Table Storage

## CI/CD

The repository includes GitHub Actions workflows that:
- Build and validate Bicep templates
- Run Function App tests
- Optionally deploy to Azure (requires secrets)

Required GitHub secrets for deployment:
- `AZURE_CREDENTIALS`: Service principal credentials
- `AZURE_RESOURCE_GROUP`: Target resource group name

## Architecture Details

### Logic App
- Monitors blob container for new files
- Processes order data and sends to D365
- Logs results to Table Storage
- Uses managed identity for Function App access

### Function App
- HTTP-triggered Node.js function
- Uses managed identity to call D365
- Accesses storage via Key Vault reference
- Automatic scale based on demand

### Security
- Managed identities for service-to-service auth
- RBAC for resource access control
- Key Vault for secret management
- Secure function access via function key

## Contributing

1. Create a feature branch
2. Make changes and test locally
3. Push and create a PR
4. CI will validate changes
5. Merge after approval


# Deploy Integration Stack (Logic App + Function App)

# Pipeline Integration (GitHub Actions)
