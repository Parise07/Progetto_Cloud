//  Azure AI Search (tier Basic)
//Crea il servizio di ricerca che ospiterà
//l'index 'chunks-index' per la ricerca vettoriale
//(HNSW) e full-text (Hybrid Search) sui chunk.

@description('Regione Azure')
param location string

@description('Prefisso per il nome della risorsa')
param prefix string

var searchServiceName = '${prefix}-search-${take(uniqueString(resourceGroup().id), 8)}'

// AZURE AI SEARCH — tier Basic
// Basic: fino a 15 indici, 2GB storage, SLA garantito
// Supporta ricerca vettoriale (HNSW) e full-text in Hybrid mode

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  sku: {
    name: 'basic'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    semanticSearch: 'free'
  }
  tags: {
    purpose: 'Vector DB e Hybrid Search per RAG'
  }
}

// OUTPUT

output endpoint string = 'https://${searchService.name}.search.windows.net'
output serviceName string = searchService.name
