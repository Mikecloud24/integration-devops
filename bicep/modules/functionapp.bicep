@description('Deploys an Azure Function App with Managed Identity, using Key Vault for secrets')
param name string
param location string
param keyVaultName string
param appServicePlanId string
param storageSecretName string

// Reference the existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

// Deploy Function App with managed identity
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      appSettings: [
        // Required runtime configuration
        { name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node' 
        }

        // Secret reference syntax for Key Vault
        {
          name: 'AzureWebJobsStorage'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${storageSecretName})'
        }

        { name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1' 
        }
      ]
    }
  }
}

// Access to Key Vault secrets will be granted via Azure RBAC role assignments in `main.bicep`.

output functionAppName string = name
output functionAppPrincipalId string = functionApp.identity.principalId
output functionAppHostname string = functionApp.properties.defaultHostName

