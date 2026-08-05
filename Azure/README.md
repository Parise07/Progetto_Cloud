# Azure Infrastructure — NewsArchive RAG System

## Struttura

```
Azure/
├── main.bicep            # Entry point: crea RG + chiama tutti i moduli
├── parameters.json       # Parametri configurabili (RG name, location, prefix)
└── modules/
    ├── storage.bicep     # Blob Storage + container articles-raw
    ├── cosmos.bicep      # Cosmos DB Serverless + database + containers
    ├── search.bicep      # Azure AI Search (tier Basic)
    ├── openai.bicep      # Azure OpenAI Service + deployment modelli
    └── acr.bicep         # Azure Container Registry (Basic)
```

## Prerequisiti

1. **Azure CLI** installata e configurata:
   ```bash
   az login
   az account set --subscription <SUBSCRIPTION_ID>
   ```

2. **Accesso ad Azure OpenAI** approvato per la propria subscription:
   → https://aka.ms/oai/access

## Deploy

Il deploy è a scope **subscription** (crea il Resource Group in automatico):

```bash
az deployment sub create \
  --location italynorth \
  --template-file main.bicep \
  --parameters parameters.json
```

Al termine, gli **output** mostrano tutti gli endpoint e nomi delle risorse create.

## Raccolta Connection String per il file .env

Dopo il deploy, recupera le chiavi con:

```bash
# Storage Account — connection string
az storage account show-connection-string \
  --name <storageAccountName> \
  --resource-group progettocloud-rg \
  --query connectionString -o tsv

# Cosmos DB — primary key
az cosmosdb keys list \
  --name <cosmosAccountName> \
  --resource-group progettocloud-rg \
  --query primaryMasterKey -o tsv

# Azure AI Search — admin key
az search admin-key show \
  --service-name <searchServiceName> \
  --resource-group progettocloud-rg \
  --query primaryKey -o tsv

# Azure OpenAI — API key
az cognitiveservices account keys list \
  --name <openAiAccountName> \
  --resource-group progettocloud-rg \
  --query key1 -o tsv

# Azure Container Registry — credenziali
az acr credential show \
  --name <acrName> \
  --resource-group progettocloud-rg
```

Copia i valori ottenuti nel file `backend/.env` (non committare questo file su Git).
