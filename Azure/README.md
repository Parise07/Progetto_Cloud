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
    ├── openai.bicep      # Azure OpenAI Service — solo account base (*)
    └── acr.bicep         # Azure Container Registry (Basic)
```

> **(*) Nota — Policy Azure for Students (Università della Calabria)**
> La sottoscrizione Azure for Students dell'UniCal impone l'uso esclusivo della
> regione **italynorth** e blocca il provisioning automatico verso regioni esterne.
> Per questa ragione il modulo `openai.bicep` crea **soltanto l'account** del
> servizio (`Microsoft.CognitiveServices/accounts`); i **deployment dei modelli**
> (`text-embedding-ada-002` e `gpt-4o-mini`) vengono distribuiti manualmente
> tramite **Azure AI Studio / Portale Azure** dopo il completamento del deploy IaC.

---

## Prerequisiti

1. **Azure CLI** installata e configurata:
   ```bash
   az login
   az account set --subscription <SUBSCRIPTION_ID>
   ```

2. **Accesso ad Azure OpenAI** approvato per la propria subscription:
   → https://aka.ms/oai/access

---

## Deploy infrastruttura base (Bicep)

Il deploy è a scope **subscription** (crea il Resource Group in automatico):

```bash
# Assicurarsi di trovarsi nella cartella Azure/ prima di eseguire il comando

az deployment sub create \
  --location italynorth \
  --template-file main.bicep \
  --parameters parameters.json
```

Al termine, gli **output** mostrano tutti gli endpoint e i nomi delle risorse create.

---

## Deployment manuale dei modelli OpenAI (post-deploy)

Dopo il completamento del deploy Bicep, aprire **Azure AI Studio**
(https://ai.azure.com) oppure il **Portale Azure**, selezionare la risorsa
OpenAI creata (`pcloud-openai-<hash>`) e distribuire manualmente i seguenti
modelli nella sezione **"Model deployments"**:

| Deployment name        | Modello                   | Versione     | SKU      | TPM |
|------------------------|---------------------------|--------------|----------|-----|
| `text-embedding-ada-002` | text-embedding-ada-002  | 2            | Global Standard | 30K |
| `gpt-4o-mini`          | gpt-4o-mini               | 2024-07-18   | Data Zone Standard | 30K |

> **Alternativa embedding**: se `text-embedding-ada-002` non fosse disponibile
> in italynorth, usare `text-embedding-3-small` (1536 dim, stessa interfaccia API).

---

## Raccolta Connection String per il file .env

Dopo il deploy, recupera le chiavi con:

```bash
# Storage Account — connection string
az storage account show-connection-string --name <storageAccountName> --resource-group progettocloud-rg --query connectionString -o tsv

# Cosmos DB — primary key
az cosmosdb keys list --name <cosmosAccountName> --resource-group progettocloud-rg --query primaryMasterKey -o tsv

# Azure AI Search — admin key
az search admin-key show --service-name <searchServiceName> --resource-group progettocloud-rg --query primaryKey -o tsv

# Azure OpenAI — API key
az cognitiveservices account keys list --name <openAiAccountName> --resource-group progettocloud-rg --query key1 -o tsv

# Azure Container Registry — credenziali
az acr credential show --name <acrName> --resource-group progettocloud-rg
```

Copia i valori ottenuti nel file `backend/.env` (non committare questo file su Git).
