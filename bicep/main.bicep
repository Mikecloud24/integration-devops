@description('The deployment environment (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Location for all resources')
param location string = resourceGroup().location

@description('App Service Plan for Function App')
param appServicePlanId string


@description('Key Vault name for secret storage')
param keyVaultName string

@description('RoleDefinitionId for Key Vault Secrets User role')
@secure()
param keyVaultSecretsUserRoleId string

@description('RoleDefinitionId for Function App invoke/reader role')
param functionInvokeRoleId string

// Environment-specific D365 endpoints
var d365ApiEndpoint = {
  dev: 'https://dev-finance.contoso.com/api/orders'
  test: 'https://test-finance.contoso.com/api/orders'
  prod: 'https://finance.contoso.com/api/orders'
}[environment]

// Existing Key Vault reference so we can use a resource scope (resource | tenant)
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyVaultName
}

// Give the Function App identity permission to read secrets from Key Vault
// (Removed duplicate resource declaration — the role assignment with the correct roleDefinitionId
// is defined later in this file to avoid duplicate identifier errors.)


// Deploy the Function App
module functionApp './modules/functionapp.bicep' = {
  name: 'functionapp-${environment}'
  params: {
    name: 'func-order-sync-${environment}'
    location: location
    keyVaultName: keyVaultName
    storageSecretName: 'storageConnection'
    appServicePlanId: appServicePlanId
  }
}

// Give the Function App identity permission to read secrets from Key Vault
resource kvSecretReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, 'func-order-sync-${environment}', 'KeyVaultSecretUser')
  scope: keyVault
  properties: {
    principalId: functionApp.outputs.functionAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId) // Key Vault Secrets User
    principalType: 'ServicePrincipal'
  }
}


// Deploy the Logic App, calling the Function App

// Deploy the Logic App, calling the Function App
var storageAccountName = 'stintdev${environment}'

module logicApp './modules/logicapp.bicep' = {
  name: 'logicapp-${environment}'
  params: {
    logicAppName: 'logicapp-order-sync-${environment}'
    location: location
    d365ApiEndpoint: d365ApiEndpoint
    functionAppUrl: 'https://${functionApp.outputs.functionAppHostname}/api/HttpTrigger1'
    storageAccountName: storageAccountName
  }
}

// Assign permission: allow Logic App to call Function App
resource functionAppResource 'Microsoft.Web/sites@2022-03-01' existing = {
  name: 'func-order-sync-${environment}'
}

resource logicAppCaller 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('func-order-sync-${environment}', 'LogicAppAccess', 'logicapp-order-sync-${environment}')
  scope: functionAppResource
  properties: {
    principalId: logicApp.outputs.logicAppPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', functionInvokeRoleId) // Reader + Function Invoke
    principalType: 'ServicePrincipal'
  }
}
