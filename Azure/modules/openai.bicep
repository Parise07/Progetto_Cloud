// Azure OpenAI Service
// Crea l'account Azure OpenAI e il deployment
// dei modelli:
// - text-embedding-ada-002 (embedding chunk/query)
// - gpt-4o-mini (generazione metadati AI + RAG)

@description('Regione Azure — deve supportare Azure OpenAI')
param location string

@description('Prefisso per il nome della risorsa')
param prefix string

var openAiAccountName = '${prefix}-openai-${take(uniqueString(resourceGroup().id), 8)}'

// AZURE OPENAI SERVICE

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: openAiAccountName
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: openAiAccountName
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    purpose: 'Generazione metadati AI ed embedding RAG'
  }
}

// DEPLOYMENT: text-embedding-ada-002
// Modello per la generazione degli embedding dei chunk
// e delle query di ricerca (1536 dimensioni)

resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAiAccount
  name: 'text-embedding-ada-002'
  sku: {
    name: 'Standard'
    capacity: 30 // Capacità in migliaia di token al minuto (TPM)
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
  }
}

// DEPLOYMENT: gpt-4o-mini
// Modello per la generazione automatica dei metadati
// e per la fase di generation del sistema RAG

resource gptDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAiAccount
  name: 'gpt-4o-mini'
  dependsOn: [embeddingDeployment] // Deploy in sequenza per evitare conflitti di quota
  sku: {
    name: 'Standard'
    capacity: 30
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
  }
}

// OUTPUT

output endpoint string = openAiAccount.properties.endpoint
output accountName string = openAiAccount.name
