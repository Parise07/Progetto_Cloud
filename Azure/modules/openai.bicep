// Azure OpenAI Service
// Crea il solo account Microsoft.CognitiveServices (kind: 'OpenAI', SKU: 'S0').
//
// NOTA ARCHITETTURALE — Policy Azure for Students (Università della Calabria):
// La sottoscrizione Azure for Students impone l'uso esclusivo della regione
// italynorth e blocca regioni esterne (es. swedencentral, westeurope).
// Per questa ragione il provisioning automatico dei sub-deployment dei modelli
// (text-embedding-ada-002 / text-embedding-3-small e gpt-4o-mini) è stato
// rimosso da questo modulo Bicep.
//
// I deployment dei modelli vengono distribuiti MANUALMENTE tramite:
//   → Azure AI Studio: https://ai.azure.com
//   → Portale Azure: portale.azure.com → risorsa OpenAI → Model deployments
//
// Modelli da distribuire manualmente:
//   • text-embedding-ada-002 (v2) o text-embedding-3-small — SKU: Standard
//   • gpt-4o-mini (2024-07-18) — SKU: Standard

@description('Regione Azure per l\'account OpenAI. Deve rispettare le policy della sottoscrizione (italynorth per Azure for Students UniCal).')
param location string

@description('Prefisso per il nome della risorsa')
param prefix string

var openAiAccountName = '${prefix}-openai-${take(uniqueString(resourceGroup().id), 8)}'

// AZURE OPENAI SERVICE — solo account base
// I deployment dei modelli vengono gestiti manualmente via Azure AI Studio
// per conformità con le policy della sottoscrizione Azure for Students.

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
    note: 'Model deployments gestiti manualmente via Azure AI Studio'
  }
}

// DEPLOYMENT MODELLI — RIMOSSO DA BICEP (policy italynorth)
//
// Le risorse seguenti erano gestite via IaC ma sono state rimosse a causa
// delle restrizioni della policy Azure for Students che impone italynorth
// come unica regione ammessa e non supporta SKU Standard per i deployment
// di modelli OpenAI in quella regione.

// OUTPUT

output endpoint string = openAiAccount.properties.endpoint
output accountName string = openAiAccount.name
