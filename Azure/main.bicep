targetScope = 'subscription'

// PARAMETRI 

@description('Nome del Resource Group da creare')
param resourceGroupName string = 'progettocloud-rg'

@description('Regione Azure per tutte le risorse')
param location string = 'italynorth'

@description('Prefisso breve per i nomi delle risorse (3-8 caratteri, solo minuscole e numeri)')
@minLength(3)
@maxLength(8)
param prefix string = 'pcloud'

// RESOURCE GROUP

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: {
    project: 'Archivio Notizie'
    course: 'Sistemi Distribuiti e Cloud Computing'
    managedBy: 'Bicep IaC'
  }
}

// MODULI

module storage 'modules/storage.bicep' = {
  name: 'storageDeployment'
  scope: rg
  params: {
    location: location
    prefix: prefix
  }
}

module cosmos 'modules/cosmos.bicep' = {
  name: 'cosmosDeployment'
  scope: rg
  params: {
    location: location
    prefix: prefix
  }
}

module search 'modules/search.bicep' = {
  name: 'searchDeployment'
  scope: rg
  params: {
    location: location
    prefix: prefix
  }
}

module openai 'modules/openai.bicep' = {
  name: 'openaiDeployment'
  scope: rg
  params: {
    location: location
    prefix: prefix
  }
}

module acr 'modules/acr.bicep' = {
  name: 'acrDeployment'
  scope: rg
  params: {
    location: location
    prefix: prefix
  }
}

// OUTPUT — valori da copiare nel file .env

output storageAccountName string = storage.outputs.storageAccountName
output storageBlobEndpoint string = storage.outputs.blobEndpoint
output cosmosEndpoint string = cosmos.outputs.endpoint
output searchEndpoint string = search.outputs.endpoint
output openAiEndpoint string = openai.outputs.endpoint
output acrLoginServer string = acr.outputs.loginServer
output resourceGroupName string = rg.name
output location string = rg.location
