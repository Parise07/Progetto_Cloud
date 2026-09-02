@description('Location delle risorse (es. italynorth)')
param location string = resourceGroup().location

@description('Un prefisso unico per il link pubblico')
param dnsNameLabel string = 'newsarchive-api-${uniqueString(resourceGroup().id)}'

// Parametri segreti che passeremo dal terminale
@secure()
param storageConnectionString string
@secure()
param cosmosEndpoint string
@secure()
param cosmosKey string
@secure()
param searchEndpoint string
@secure()
param searchKey string
@secure()
param openAiEndpoint string
@secure()
param openAiKey string

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: 'newsarchive-containers'
  location: location
  properties: {
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      ports: [
        { protocol: 'TCP', port: 8000 } // FastAPI
        { protocol: 'TCP', port: 8080 } // Keycloak
      ]
      dnsNameLabel: dnsNameLabel
    }
    containers: [
      {
        name: 'fastapi-backend'
        properties: {
          // La tua immagine caricata su Docker Hub!
          image: 'parise09/newsarchive-backend:latest'
          ports: [{ port: 8000 }]
          resources: {
            requests: { cpu: 1, memoryInGB: 2 }
          }
          environmentVariables: [
            // Variabili Base
            { name: 'APP_ENV', value: 'development' }
            { name: 'LOG_LEVEL', value: 'INFO' }
            { name: 'TEST_MODE', value: 'False' }

            // Azure Blob Storage
            { name: 'AZURE_STORAGE_CONNECTION_STRING', secureValue: storageConnectionString }
            { name: 'AZURE_STORAGE_CONTAINER_NAME', value: 'articles-raw' }
            { name: 'AZURE_STORAGE_IMAGE_CONTAINER', value: 'articles-image' }

            // Azure Cosmos DB
            { name: 'COSMOS_ENDPOINT', value: cosmosEndpoint }
            { name: 'COSMOS_PRIMARY_KEY', secureValue: cosmosKey }
            { name: 'COSMOS_DATABASE_NAME', value: 'newsarchive' }
            { name: 'COSMOS_ARTICLES_CONTAINER', value: 'articles' }
            { name: 'COSMOS_CHUNKS_CONTAINER', value: 'chunks' }

            // Azure AI Search
            { name: 'AZURE_SEARCH_ENDPOINT', value: searchEndpoint }
            { name: 'AZURE_SEARCH_ADMIN_KEY', secureValue: searchKey }
            { name: 'AZURE_SEARCH_INDEX_NAME', value: 'news-index' }

            // Azure OpenAI
            { name: 'AZURE_OPENAI_ENDPOINT', value: openAiEndpoint }
            { name: 'AZURE_OPENAI_KEY', secureValue: openAiKey }
            { name: 'AZURE_OPENAI_API_VERSION', value: '2024-02-01' }
            { name: 'AZURE_OPENAI_CHAT_DEPLOYMENT', value: 'gpt-4o-mini' }
            { name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT', value: 'text-embedding-ada-002' }

            // Keycloak
            { name: 'KEYCLOAK_SERVER_URL', value: 'http://${dnsNameLabel}.${location}.azurecontainer.io:8080' }
            { name: 'KEYCLOAK_REALM', value: 'prog-cloud' }
            { name: 'KEYCLOAK_CLIENT_ID', value: 'web-app-cloud' }
          ]
        }
      }
      {
        name: 'keycloak-iam'
        properties: {
          // L'immagine ufficiale di Keycloak
          image: 'quay.io/keycloak/keycloak:24.0.2'
          command: ['/opt/keycloak/bin/kc.sh', 'start-dev']
          ports: [{ port: 8080 }]
          resources: {
            requests: { cpu: 1, memoryInGB: 2 }
          }
          environmentVariables: [
            { name: 'KEYCLOAK_ADMIN', value: 'admin' }
            { name: 'KEYCLOAK_ADMIN_PASSWORD', secureValue: 'admin' }
          ]
        }
      }
    ]
  }
}

// Questo ti stamperà il link finale a cui collegare la tua app Flutter
output fqdn string = containerGroup.properties.ipAddress.fqdn
