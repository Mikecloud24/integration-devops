@description('Deploy a Logic App that uses Managed Identity and calls a Function App')
param logicAppName string
param location string
param d365ApiEndpoint string
param functionAppUrl string
param storageAccountName string

var blobConnectionName = '${logicAppName}-blob'
var tableConnectionName = '${logicAppName}-table'

// Create API Connection for Azure Blob Storage
resource blobConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: blobConnectionName
  location: location
  properties: {
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
    }
    displayName: 'Azure Blob Connection'
    parameterValues: {
      accountName: storageAccountName
      accessKey: reference(resourceId('Microsoft.Storage/storageAccounts', storageAccountName)).primaryEndpoints.blob
    }
  }
}

// Create API Connection for Azure Table Storage
resource tableConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: tableConnectionName
  location: location
  properties: {
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azuretables')
    }
    displayName: 'Azure Table Connection'
    parameterValues: {
      accountName: storageAccountName
      accessKey: reference(resourceId('Microsoft.Storage/storageAccounts', storageAccountName)).primaryEndpoints.table
    }
  }
}

// Deploy Logic App with connections
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
        value: {
          id: blobConnection.id
        }
      }
      table_storage_connection: {
        value: {
          id: tableConnection.id
        }
      }
    }
  }
}

output logicAppPrincipalId string = logicApp.identity.principalId
