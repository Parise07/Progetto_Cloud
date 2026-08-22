//#########################################
// file bicep sono composti da 3 elementi parametri(input), risorse (servizi da creare) e output (valori da restituire)
//#########################################
// Azure Blob Storage
// Crea lo Storage Account e il container privato
// 'articles-raw' per l'archiviazione dei file
// originali caricati (TXT, MD, JSON, DOCX, PDF).

@description('locazione Azure')
param location string

@description('Prefisso per il nome della risorsa')
param prefix string

// I nomi degli Storage Account devono avere degli standard unici in tutto Azure, composto solo da lettere minuscole e numeri 
var storageAccountName = '${prefix}${take(uniqueString(resourceGroup().id), 10)}'

// STORAGE ACCOUNT

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false // Accesso pubblico disabilitato
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
  tags: {
    purpose: 'Archiviazione file articoli grezzi'
  }
}

// BLOB SERVICE

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// CONTAINER articles-raw (privato)

resource articlesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'articles-raw'
  properties: {
    publicAccess: 'None' // Container privato — accesso solo tramite backend
  }
}
resource articlesImageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'articles-image'
  properties: {
    publicAccess: 'None' // Container privato — accesso solo tramite backend
  }
}

// OUTPUT

output storageAccountName string = storageAccount.name
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
