# Piano Architetturale — NewsArchive RAG System



## 1. Visione Generale del Sistema

Il sistema è un'applicazione **decoupled** a tre layer:

```
┌─────────────────────────────────────────────────────────────────┐
│                        FRONTEND (Flutter)                       │
│          App cross-platform (Web/Mobile) per l'utente          │
└─────────────────────┬───────────────────────────────────────────┘
                      │ HTTP/REST (JSON)
┌─────────────────────▼───────────────────────────────────────────┐
│                     BACKEND (FastAPI + Python)                  │
│     Orchestrazione AI, RAG pipeline, logica di business        │
└──────────┬──────────┬──────────────┬────────────────────────────┘
           │          │              │
     ┌─────▼──┐  ┌────▼─────┐  ┌────▼──────────────────────┐
     │ Blob   │  │ Cosmos DB│  │  Azure AI Search           │
     │Storage │  │(Metadata)│  │  (Vector DB + Full-text)   │
     └────────┘  └──────────┘  └────────────────────────────┘
```

---

## 2. Servizi Azure Selezionati

### 2.1 Azure Blob Storage — Archiviazione File Grezzi

| Campo | Valore |
|---|---|
| **Servizio** | Azure Blob Storage (Standard LRS) |
| **Scopo** | Archiviare i file originali caricati (TXT, MD, JSON, DOCX, PDF) |
| **Container** | `articles-raw` (blob privato) |
| **Motivazione** | È lo standard de-facto Azure per object storage; scalabile, economico, integrato con tutti gli altri servizi |

- Ogni articolo caricato viene salvato come blob con nome `{article_id}.{ext}`
- L'URL del blob è poi memorizzato nel DB dei metadati come riferimento
- Formati **obbligatori**: TXT, MD, JSON
 DOCX, PDF

### 2.2 Azure Cosmos DB for NoSQL — Database Metadati

| Campo | Valore |
|---|---|
| **Servizio** | Azure Cosmos DB (API NoSQL, modalità Serverless) |
| **Scopo** | Archiviare tutti i metadati degli articoli (manuali + AI-generated) |
| **Database** | `newsarchive` |
| **Containers** | `articles` (metadati articolo) + `chunks` (metadati chunk) |
| **Motivazione** | Schema flessibile (JSON-native) ideale per metadati eterogenei; serverless elimina costi fissi; latenza bassa per query sui metadati |

**Documento `articles` (esempio schema):**
```json
{
  "id": "uuid-articolo",
  "blob_url": "https://...",
  "uploaded_at": "2025-08-05T10:00:00Z",
  "manual": {
    "title": "...", "author": "...", "category": "...",
    "description": "...", "tags": ["...", "..."]
  },
  "ai_generated": {
    "keywords": ["..."], "subtitle": "...", "summary": "...",
    "suggested_categories": ["..."], "language": "it",
    "entities": ["persona: Mario Rossi", "luogo: Roma"]
  }
}
```

**Documento `chunks` (esempio schema):**
```json
{
  "id": "chunk-uuid",
  "article_id": "uuid-articolo",
  "chunk_index": 0,
  "text": "...",
  "token_count": 150
}
```

### 2.3 Azure AI Search — Vector Database + Ricerca Full-Text

| Campo | Valore |
|---|---|
| **Servizio** | Azure AI Search (tier Basic) |
| **Scopo** | Indicizzare gli embedding dei chunk + ricerca semantica e full-text |
| **Index** | `chunks-index` |
| **Motivazione** | **Servizio Azure-nativo** che unisce ricerca vettoriale (HNSW) e full-text in un unico servizio. Elimina la necessità di Pinecone/Qdrant esterni. Supporta **Hybrid Search** (keyword + semantic) nativamente. |

**Schema dell'index:**
```
chunk_id (string, key)
article_id (string, filterable)
chunk_index (int32, sortable)
text (string, searchable)
embedding (Collection(Edm.Single), dimensions=1536, HNSW)
```

### 2.4 Azure OpenAI Service — Modelli AI

| Campo | Valore |
|---|---|
| **Servizio** | Azure OpenAI Service |
| **Modello Embedding** | `text-embedding-ada-002` (1536 dim) |
| **Modello Chat/LLM** | `gpt-4o-mini` (generazione metadati + RAG) |
| **Motivazione** | Obbligatorio usare Azure per ogni componente. Azure OpenAI è l'equivalente Azure-hosted di OpenAI API, garantisce compliance e rimane nell'ecosistema Azure |

### 2.5 Azure Container Apps — Hosting Backend

| Campo | Valore |
|---|---|
| **Servizio** | Azure Container Apps |
| **Scopo** | Hosting del backend FastAPI in container Docker |
| **Motivazione** | Serverless container management; scala a zero; più moderno e flessibile di App Service per API stateless; integrazione nativa con Azure Container Registry |

### 2.6 Azure Static Web Apps — Hosting Frontend

| Campo | Valore |
|---|---|
| **Servizio** | Azure Static Web Apps |
| **Scopo** | Hosting dell'app Flutter compilata per Web |
| **Motivazione** | Gratuito per progetti accademici; CDN globale integrata; deploy automatico da GitHub |

### 2.7 Azure Container Registry — Registry Docker

| Campo | Valore |
|---|---|
| **Servizio** | Azure Container Registry (Basic) |
| **Scopo** | Archiviare l'immagine Docker del backend |
| **Motivazione** | Integrazione nativa con Container Apps; privato e sicuro |

---

## 3. Flusso Dati End-to-End

### 3.1 Upload e Ingestion di un Articolo

```
[Flutter App]
    │
    ├─ 1. POST /articles/upload (file + metadati manuali)
    │
[FastAPI Backend]
    │
    ├─ 2. Salva file grezzo su Azure Blob Storage
    ├─ 3. Estrae testo dal file (parser multiformat: txt/md/json + docx/prf)
    ├─ 4. [LangChain] Chiama Azure OpenAI (gpt-4o-mini) → genera metadati AI
    │       (keywords, subtitle, summary, categories, language, entities)
    ├─ 5. Salva documento in Cosmos DB (articles container)
    ├─ 6. [LangChain] Chunking del testo (RecursiveCharacterTextSplitter)
    │       chunk_size=500 tokens, overlap=50 tokens
    ├─ 7. Per ogni chunk:
    │       a. Genera embedding via Azure OpenAI (ada-002)
    │       b. Salva metadata chunk in Cosmos DB (chunks container)
    │       c. Indicizza chunk + embedding in Azure AI Search
    └─ 8. Ritorna 201 Created con article_id al frontend
```

### 3.2 Ricerca in Linguaggio Naturale (RAG)

```
[Flutter App]
    │
    ├─ 1. POST /search/query (query: "Articoli sulla guerra in Ucraina")
    │
[FastAPI Backend]
    │
    ├─ 2. Genera embedding della query (Azure OpenAI ada-002)
    ├─ 3. Hybrid Search su Azure AI Search
    │       (vettoriale + full-text, top-k=5 chunk)
    ├─ 4. Per ogni chunk recuperato:
    │       → Recupera metadati articolo da Cosmos DB (article_id)
    ├─ 5. [LangChain] RAG: costruisce prompt con contesto dei chunk
    ├─ 6. Azure OpenAI (gpt-4o-mini) genera risposta in linguaggio naturale
    └─ 7. Ritorna risposta + lista articoli con relativi score e metadati
```

---

## 4. Struttura delle Cartelle del Progetto

```
Progetto_Cloud/
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── upload_screen.dart
│   │   │   ├── search_screen.dart
│   │   │   └── article_detail_screen.dart
│   │   ├── models/
│   │   │   └── article.dart
│   │   ├── services/
│   │   │   └── api_service.dart
│   │   └── widgets/
│   ├── pubspec.yaml
│   └── ...
│
├── backend/
│   ├── app/
│   │   ├── main.py               # FastAPI app entry point
│   │   ├── config.py             # Settings (Azure credentials, ecc.)
│   │   ├── routers/
│   │   │   ├── articles.py       # Endpoint upload/CRUD articoli
│   │   │   └── search.py         # Endpoint ricerca RAG
│   │   ├── services/
│   │   │   ├── blob_service.py   # Azure Blob Storage client
│   │   │   ├── cosmos_service.py # Cosmos DB client
│   │   │   ├── search_service.py # Azure AI Search client
│   │   │   ├── ai_service.py     # Azure OpenAI + LangChain
│   │   │   └── ingestion_service.py # Orchestrazione pipeline
│   │   └── models/
│   │       ├── article.py        # Pydantic models
│   │       └── chunk.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── azure/
│   ├── main.bicep               # IaC: provisioning automatico risorse Azure
│   ├── parameters.json          # Parametri di deploy (nomi risorse, SKU, regione)
│   └── README.md                # Istruzioni deploy via Azure CLI
│
└── Relazione_Progetto.md
```

---

## 5. Ordine di Sviluppo dei Task

Il progetto viene sviluppato in fasi incrementali, ognuna con demo funzionante.

### FASE 1 — Infrastruttura Azure (IaC con Bicep)
- [ x ] **Task 1.1**: Scrittura del file `main.bicep` (scope: subscription) per il provisioning completo di tutte le risorse Azure: Resource Group `progettocloud-rg`, Blob Storage + container `articles-raw`, Cosmos DB Serverless + database + containers, Azure AI Search, Azure OpenAI Service, Azure Container Registry — strutturato in moduli separati per massima leggibilità
- [ x ] **Task 1.2**: Scrittura del file `parameters.json` con tutti i parametri configurabili (nome RG, location, prefix, SKU)
- [ x ] **Task 1.3**: Esecuzione del deploy tramite Azure CLI (`az deployment sub create`) — tutte le risorse infrastrutturali create con successo in **italynorth**
- [ x ] **Task 1.4**: Estrazione e configurazione sicura delle Connection String e API Key nel file `.env` locale (non committato)
- [ x ] **Task 1.5 — Refactoring modulo OpenAI per conformità policy Azure for Students (italynorth)**: La policy della sottoscrizione Azure for Students (Università della Calabria) impone l'uso esclusivo della regione `italynorth` e blocca qualsiasi deploy verso regioni esterne. Poiché `italynorth` non supporta il provisioning automatico dei model-deployment OpenAI tramite ARM/Bicep con SKU Standard, il modulo `openai.bicep` è stato refactorizzato per creare **soltanto l'account base** (`Microsoft.CognitiveServices/accounts`). I deployment dei modelli (`text-embedding-ada-002` e `gpt-4o-mini`) vengono distribuiti **manualmente** tramite Azure AI Studio / Portale Azure al termine del deploy IaC. Questa scelta garantisce conformità con le policy di sicurezza della sottoscrizione accademica pur mantenendo la riproducibilità dell'infrastruttura base via IaC.

### FASE 2 — Backend: Core Pipeline di Ingestion
- [ x ] **Task 2.1**: Setup FastAPI + struttura cartelle backend
- [x] **Task 2.2**: Endpoint `POST /articles/upload` + salvataggio su Blob Storage
- [x] **Task 2.3**: Parser file multiformat
  - Obbligatori: TXT, MD, JSON
  - Facoltativi: DOCX (`python-docx`), PDF
- [x] **Task 2.4**: Generazione metadati AI (LangChain + Azure OpenAI)
- [x] **Task 2.5**: Salvataggio metadati su Cosmos DB
- [ ] **Task 2.6**: Chunking + embedding + indicizzazione su Azure AI Search

### FASE 3 — Backend: RAG e Ricerca
- [ ] **Task 3.1**: Endpoint `POST /search/query` (ricerca in linguaggio naturale)
- [ ] **Task 3.2**: Endpoint `GET /articles` (lista articoli con filtri)
- [ ] **Task 3.3**: Endpoint `GET /articles/{id}` (dettaglio articolo + chunk)

### FASE 4 — Frontend Flutter
- [ ] **Task 4.1**: Struttura app + navigazione tra schermate
- [ ] **Task 4.2**: Schermata Upload articolo (form metadati + file picker)
- [ ] **Task 4.3**: Schermata Ricerca (input NL + visualizzazione risultati RAG)
- [ ] **Task 4.4**: Schermata Lista Articoli (con filtri)
- [ ] **Task 4.5**: Schermata Dettaglio Articolo (metadati + chunk)

### FASE 5 — Docker e Deploy
- [ ] **Task 5.1**: Dockerfile per il backend
- [ ] **Task 5.2**: Push immagine su Azure Container Registry
- [ ] **Task 5.3**: Deploy su Azure Container Apps
- [ ] **Task 5.4**: Build Flutter Web + deploy su Azure Static Web Apps

### FASE 6 — Feature Originali (da discutere)
- [ ] **Task 6.1**: Timeline cronologica degli articoli (visualizzazione avanzata)
- [ ] **Task 6.2**: Dashboard con statistiche (categorie, lingue, keyword cloud)
- [ ] **Task 6.3**: Export articolo + metadati in PDF
- [ ] **Task 6.4**: Clustering automatico articoli correlati

### FASE 7 — Relazione Finale
- [ ] **Task 7.1**: Aggiornamento e completamento `relazione.md`
- [ ] **Task 7.2**: Conversione in PDF per consegna

---

## 6. Dipendenze Python Principali (backend)

```
fastapi
uvicorn
python-multipart         # Upload file
langchain
langchain-openai         # Azure OpenAI integration
azure-storage-blob       # Blob Storage SDK
azure-cosmos             # Cosmos DB SDK
azure-search-documents   # Azure AI Search SDK
pydantic-settings        # Config management
tiktoken                 # Tokenizer per chunking
# --- Parsing formati facoltativi ---
python-docx              # Estrazione testo da file DOCX
pypdf2                   # Estrazione testo da file PDF
```

---

## 7. Dipendenze Flutter Principali (frontend)

```yaml
http: ^1.2.0             # HTTP client per API REST
file_picker: ^8.0.0      # Selezione file da caricare
provider: ^6.1.0         # State management
```


