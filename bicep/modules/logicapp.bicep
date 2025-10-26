@description('Deploy a Logic App that uses Managed Identity and calls a Function App')
param logicAppName string
param location string
param d365ApiEndpoint string
param keyVaultName string
param functionAppUrl string

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    definition: loadTextContent('../../logicapps/order-sync.json')
    parameters: {
      d365_api_endpoint: {
        value: d365ApiEndpoint
      }

      function_app_url: {
        value: functionAppUrl

      }
      storage_account_connection: {
        value: json(reference(resourceId('Microsoft.KeyVault/vaults/secrets', keyVaultName, 'StorageConnection')).value)
      }

      table_storage_connection: {
        value: json(reference(resourceId('Microsoft.KeyVault/vaults/secrets', keyVaultName, 'TableStorageConnection')).value)
      }
      
    }
  }
}

output logicAppPrincipalId string = logicApp.identity.principalId
