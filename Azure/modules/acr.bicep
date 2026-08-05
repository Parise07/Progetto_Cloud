// Azure Container Registry (Basic)
// Crea il registry Docker privato per archiviare
// l'immagine del backend FastAPI, pronta per il
// deploy su Azure Container Apps.

@description('Regione Azure')
param location string

@description('Prefisso per il nome della risorsa')
param prefix string

// I nomi ACR: 5-50 caratteri, solo alfanumerici
var acrName = '${prefix}acr${take(uniqueString(resourceGroup().id), 8)}'

// AZURE CONTAINER REGISTRY — tier Basic
// Basic: adatto allo sviluppo/testing, integrazione nativa
//        con Azure Container Apps

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true // Necessario per il login da Container Apps
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    purpose: 'Registry Docker immagine backend FastAPI'
  }
}

// OUTPUT

output loginServer string = acr.properties.loginServer
output acrName string = acr.name
