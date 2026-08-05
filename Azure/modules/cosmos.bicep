// Azure Cosmos DB for NoSQL (Serverless)
// Crea l'account Cosmos DB in modalità Serverless,
// il database 'newsarchive' e i containers
// 'articles' e 'chunks' per i metadati.

@description('Regione Azure')
param location string

@description('Prefisso per il nome della risorsa')
param prefix string

var cosmosAccountName = '${prefix}-cosmos-${take(uniqueString(resourceGroup().id), 8)}'

// COSMOS DB ACCOUNT (Serverless)

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-02-15-preview' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    // Modalità Serverless: nessun costo fisso, pay-per-request
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
  }
  tags: {
    purpose: 'Metadati articoli e chunks RAG'
  }
}

// DATABASE newsarchive

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-02-15-preview' = {
  parent: cosmosAccount
  name: 'newsarchive'
  properties: {
    resource: {
      id: 'newsarchive'
    }
  }
}

// CONTAINER articles — metadati degli articoli caricati
// Partition key: /id

resource articlesContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-02-15-preview' = {
  parent: database
  name: 'articles'
  properties: {
    resource: {
      id: 'articles'
      partitionKey: {
        paths: ['/id']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
      }
    }
  }
}

// CONTAINER chunks — frammenti testuali per il RAG
// Partition key: /article_id (per co-locare i chunk per articolo)

resource chunksContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-02-15-preview' = {
  parent: database
  name: 'chunks'
  properties: {
    resource: {
      id: 'chunks'
      partitionKey: {
        paths: ['/article_id']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
      }
    }
  }
}

// OUTPUT

output endpoint string = cosmosAccount.properties.documentEndpoint
output accountName string = cosmosAccount.name
