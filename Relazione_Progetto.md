# Relazione di Progetto: Sistema RAG per l'Archiviazione e Ricerca Intelligente di Notizie

---

## 1. Introduzione e Obiettivi

### 1.1 Contesto

Il presente documento costituisce la relazione tecnica completa relativa alla progettazione e all'implementazione di un sistema cloud-native per la gestione di un archivio digitale di notizie giornalistiche. Il contesto applicativo si colloca nell'ambito della crescente necessità di sistemi informativi capaci di gestire volumi elevati di contenuti testuali non strutturati, fornendo meccanismi di accesso efficienti e semanticamente significativi. L'adozione di tecniche di intelligenza artificiale generativa per l'arricchimento automatico dei metadati e per la ricerca in linguaggio naturale rappresenta il contributo tecnologico centrale del progetto, declinato all'interno di un'architettura cloud completamente basata su Microsoft Azure.

### 1.2 Requisiti di Traccia

Il progetto richiede la realizzazione di un'applicazione cloud-native in grado di:

- Gestire il caricamento di articoli testuali in formati standard (`TXT`, `Markdown`, `JSON`) e in formati documentali complessi (`DOCX`, `PDF`);
- Estrarre automaticamente il contenuto testuale dai formati supportati;
- Generare automaticamente metadati descrittivi di qualità editoriale tramite modelli linguistici di grandi dimensioni (LLM);
- Indicizzare i contenuti per consentire sia ricerche tradizionali per parola chiave che interrogazioni in linguaggio naturale, attraverso l'integrazione di un sistema **RAG (Retrieval-Augmented Generation)**;
- Basare l'intera infrastruttura computazionale e di persistenza su servizi **Microsoft Azure**.

### 1.3 Obiettivi del Sistema

Gli obiettivi principali del progetto consistono nella realizzazione di un'architettura **disaccoppiata** (*decoupled*), scalabile e resiliente. Si mira a fornire un'interfaccia utente multipiattaforma accessibile da browser e dispositivi desktop, supportata da un backend robusto in grado di orchestrare pipeline di intelligenza artificiale avanzate per l'arricchimento semantico dei documenti e la successiva fase di retrieval. La gestione delle identità utente è affidata a un Identity Provider certificato, in conformità con le best practice di sicurezza del settore.

---

## 2. Architettura del Sistema

### 2.1 Panoramica Decoupled

L'architettura proposta prevede una netta separazione delle responsabilità attraverso un approccio a **tre layer**: **Frontend**, **Backend** e **Servizi Cloud**. Questa modularità garantisce la possibilità di evolvere, scalare e manutenere i singoli componenti in maniera indipendente, limitando l'accoppiamento architetturale e rendendo il sistema intrinsecamente resistente ai guasti localizzati.

[RIFERIMENTO DIAGRAMMA ARCHITETTURA]

![Diagramma Architetturale](images_rel/architettura.png)

I tre layer operano secondo il seguente schema di responsabilità:

| Layer | Tecnologia | Responsabilità |
|-------|-----------|----------------|
| **Presentazione** | Flutter/Dart (Web/Desktop) | Interfaccia utente, rendering, gestione sessioni, comunicazione REST |
| **Business Logic** | Python / FastAPI | Orchestrazione pipeline AI, CRUD articoli, autenticazione JWT, routing HTTP |
| **Persistenza e AI** | Azure (Blob, Cosmos DB, AI Search, OpenAI) | Archiviazione, metadati, ricerca vettoriale, inferenza LLM |

### 2.2 Motivazioni dell'Architettura Multi-Layer

La scelta di un'architettura multi-layer è motivata dall'esigenza di massimizzare la flessibilità e la manutenibilità a lungo termine del sistema. Il Frontend, operando come client autonomo, comunica esclusivamente tramite protocollo **HTTP/REST** con payload **JSON** con il Backend, il quale funge da orchestratore centrale della logica di business e delle pipeline di intelligenza artificiale.

I servizi Azure sottostanti operano come layer di persistenza e computazione specializzata, accessibili esclusivamente tramite le API del Backend. Questo approccio garantisce un controllo centralizzato su sicurezza, autorizzazioni e flussi di dati, impedendo l'accesso diretto del client alle risorse cloud — principale vettore di attacco nelle architetture mal progettate.

[RIFERIMENTO DIAGRAMMA FLUSSO DATI API REST]

### 2.3 Gestione delle Identità e Sicurezza (Autenticazione)

Per proteggere gli endpoint sensibili e differenziare l'utenza pubblica da quella autenticata, il sistema richiede un'infrastruttura di **Identity and Access Management (IAM)** conforme agli standard industriali.

In linea con il principio di sicurezza *"Don't roll your own crypto"*, si è optato per non implementare una soluzione di autenticazione custom basata su gestione diretta di password e chiavi crittografiche.

**Motivazione della scelta di Keycloak**: La sottoscrizione *Azure for Students* dell'Università della Calabria impone restrizioni significative sui permessi di amministrazione della directory Azure Entra ID, inibendo la creazione di tenant **Azure Entra ID B2C**. Tali vincoli hanno condotto alla scelta di **Keycloak** come Identity Provider (IdP) open-source certificato. Questa soluzione garantisce:

- L'utilizzo dei flussi standard **OAuth 2.0 / OpenID Connect (OIDC)**, consolidati e ampiamente validati dalla comunità di sicurezza;
- La firma dei token JWT tramite algoritmo **RS256** (RSA con SHA-256), con chiavi pubbliche distribuite tramite endpoint **JWKS** standard;
- La possibilità di federazione con ulteriori provider (Google, LDAP, SAML) in scenari di produzione futuri senza modifiche architetturali;
- La piena conformità con i vincoli infrastrutturali della sottoscrizione accademica, senza compromettere il livello di sicurezza del sistema.

---

## 3. Tecnologie e Strumenti

### 3.1 Servizi Azure

#### Azure Blob Storage

Per l'archiviazione fisica dei file originali (`TXT`, `MD`, `JSON`, `DOCX`, `PDF`) e delle immagini di copertina è stato adottato **Azure Blob Storage**, organizzato in due container distinti:

- `articles-raw`: contenitore dei file testuali originali;
- Container dedicato alle immagini di copertina (configurabile tramite `AZURE_STORAGE_IMAGE_CONTAINER`).

**Motivazione architetturale**: La separazione dell'archiviazione fisica dei file (Blob Storage) dai metadati strutturati (Cosmos DB) è una scelta progettuale deliberata. Azure Blob Storage è il servizio standard per l'*object storage* in ambiente Azure, ottimizzato per la gestione di file binari con scalabilità virtualmente illimitata e costi proporzionali all'utilizzo effettivo. Unificare file e metadati in un unico database avrebbe comportato inefficienze prestazionali e costi elevati per query sui metadati, che non richiedono il trasferimento del payload del file.

#### Azure Cosmos DB (API NoSQL)

La gestione dei metadati degli articoli è affidata ad **Azure Cosmos DB** in modalità API NoSQL, organizzato in due container:

- **`articles`**: contenitore principale dei metadati, con `article_id` (UUID v4) come chiave di partizione;
- **`chunks`**: contenitore dei frammenti testuali (*chunk*), con `chunk_id` (`{article_id}-chunk-{index}`) come chiave di partizione.

**Motivazione architetturale**: Lo schema dei documenti di un archivio notizie è per natura **eterogeneo e variabile nel tempo**. Un database relazionale rigido costringerebbe a costose migrazioni dello schema a ogni evoluzione del modello dati. L'approccio **documentale JSON-native** di Cosmos DB è strutturalmente superiore in questo contesto: consente l'estensione dello schema senza migrazioni distruttive e si allinea perfettamente con la serializzazione JSON nativa di Pydantic. La modalità **Serverless** è stata selezionata per ottimizzare i costi operativi in un contesto a carico discontinuo tipico di una sottoscrizione accademica.

#### Azure AI Search

Per l'indicizzazione vettoriale dei chunk testuali e la ricerca semantica ibrida è stato adottato **Azure AI Search**. Il servizio unifica in un'unica soluzione gestita:

- **Ricerca vettoriale**: tramite algoritmo **HNSW** (*Hierarchical Navigable Small World*), per il recupero approssimato del vicinato su spazi ad alta dimensionalità (1536 dimensioni);
- **Ricerca full-text tradizionale**: tramite algoritmo **BM25**, combinabile in modalità *Hybrid Search*.

**Motivazione architetturale**: L'adozione di un unico servizio gestito elimina la necessità di orchestrare database vettoriali di terze parti (es. Pinecone, Weaviate, Qdrant), abbassando significativamente la complessità operativa. L'indice vettoriale viene creato automaticamente all'avvio del backend tramite `setup_ai_search_index()`, garantendo la riproducibilità dell'ambiente senza interventi manuali.

#### Azure OpenAI Service

L'integrazione dei modelli linguistici si basa su **Azure OpenAI Service**. I modelli selezionati sono:

| Modello | Deployment | Utilizzo |
|---------|-----------|---------|
| `text-embedding-ada-002` | `AZURE_OPENAI_EMBEDDING_DEPLOYMENT` | Generazione vettori embedding (1536 dimensioni) |
| `gpt-4o-mini` | `AZURE_OPENAI_CHAT_DEPLOYMENT` | Generazione metadati AI, risposta RAG, chat contestuale |

**Motivazione architetturale**: L'adozione di Azure OpenAI Service garantisce conformità con le policy enterprise di trattamento dei dati, latenze inferiori grazie alla prossimità con i servizi Azure di persistenza, e un'integrazione sicura all'interno dell'ecosistema cloud del progetto.

**Vincoli della Sottoscrizione Accademica**: La policy della sottoscrizione *Azure for Students* dell'Università della Calabria impone l'uso esclusivo della regione `italynorth` e blocca il provisioning automatico verso regioni esterne. Poiché tale regione non supporta il deployment automatico dei modelli OpenAI tramite ARM/Bicep, la configurazione IaC crea esclusivamente l'account base del servizio. I deployment dei modelli (`text-embedding-ada-002` e `gpt-4o-mini`) sono distribuiti manualmente tramite **Azure AI Studio / Portale Azure** al termine del deploy IaC. Questa scelta architetturale preserva la riproducibilità dell'infrastruttura base garantendo piena conformità con la sottoscrizione.

#### Azure Container Registry (ACR)

È stato predisposto un modulo Bicep per il provisioning di un **Azure Container Registry**, necessario per l'hosting delle immagini Docker del backend FastAPI in scenari di deployment containerizzato (Azure Container Apps, AKS). L'endpoint è esposto come output IaC tramite `acrLoginServer`.

#### Azure Bicep — Infrastructure as Code

Per il provisioning automatico e riproducibile dell'intera infrastruttura Azure si è adottato **Azure Bicep** come strumento nativo di Infrastructure as Code (IaC).

**Motivazione architetturale**:

- **Versionabilità e Tracciabilità**: L'intera infrastruttura è trattata come codice sorgente, gestita nella repository Git. Ogni modifica architetturale è tracciata nel log di versione con autore, data e motivazione.
- **Riproducibilità degli Ambienti**: L'intero stack applicativo può essere ricreato in modo identico e automatizzato in pochi minuti, facilitando la gestione di ambienti separati di sviluppo, test e produzione.
- **Sicurezza e Conformità**: La gestione dichiarativa azzera il rischio di errori umani legati a configurazioni manuali.
- **Integrazione Nativa con Azure**: A differenza di Terraform (che richiede la gestione di file di stato `.tfstate`), Bicep è il linguaggio IaC nativo di Microsoft Azure, con sintassi dichiarativa semplificata rispetto ai template ARM JSON.

La struttura IaC è organizzata in un file principale `main.bicep` con `targetScope = 'subscription'`, che orchestra cinque moduli indipendenti:

```
Azure/
├── main.bicep              # Orchestratore principale (scope: subscription)
├── parameters.json         # Parametri di configurazione del deploy
├── modules/
│   ├── storage.bicep       # Azure Blob Storage (Standard LRS, due container)
│   ├── cosmos.bicep        # Azure Cosmos DB (API NoSQL, Serverless, due container)
│   ├── search.bicep        # Azure AI Search
│   ├── openai.bicep        # Azure OpenAI Service (account base, region italynorth)
│   └── acr.bicep           # Azure Container Registry (tier Basic)
└── README.md               # Istruzioni operative deploy via Azure CLI
```

### 3.2 FastAPI

Il layer Backend è sviluppato in **Python** con il framework **FastAPI**. Le motivazioni principali sono:

- **Prestazioni asincrone**: basato su **Starlette** e `asyncio`, è tra i framework Python più performanti per workload I/O-bound tipici delle integrazioni con API cloud;
- **Tipizzazione nativa con Pydantic**: validazione automatica degli input HTTP e riduzione del codice boilerplate;
- **Swagger UI automatica** (`/docs`): contratto API sempre aggiornato e consultabile;
- **Gestione asincrona nativa**: supporto di prima classe per `async def` e `await`, fondamentale per l'integrazione con i client SDK Azure e le chain LangChain.

Il ciclo di vita dell'applicazione è gestito tramite `@asynccontextmanager lifespan`, che all'avvio esegue `setup_ai_search_index()` garantendo che l'indice vettoriale sia disponibile prima di accettare richieste.

### 3.3 LangChain

Per l'orchestrazione delle pipeline AI si è adottato **LangChain**, che offre il pattern **LCEL (LangChain Expression Language)** per la composizione dichiarativa di componenti tramite l'operatore `|`, con integrazioni native ottimizzate per **Azure OpenAI** e il pattern *Structured Output* (function calling).

### 3.4 Flutter/Dart

Il layer di presentazione è realizzato con **Flutter** (Dart), framework cross-platform che genera applicazioni native per Web, Desktop e Mobile da un'unica base di codice. Il progetto è configurato e testato in modalità **Web**.

Le dipendenze principali (`pubspec.yaml`):

| Pacchetto | Versione | Utilizzo |
|-----------|---------|---------|
| `http` | `^1.2.0` | Chiamate HTTP REST verso il Backend |
| `shared_preferences` | `^2.3.2` | Persistenza locale del token JWT |
| `file_picker` | `^8.1.4` | Selezione file dal filesystem locale |
| `desktop_drop` | `^0.8.3` | Drag-and-drop di file sull'interfaccia |
| `pdf` | `^3.10.8` | Generazione PDF lato client dei metadati articolo |
| `openid_client` | `^0.4.8` | Supporto flussi OIDC |
| `flutter_appauth` | `^7.0.1` | Autenticazione OAuth2/OIDC |

---

## 4. Dettagli Implementativi

### 4.1 Struttura del Backend (FastAPI)

Il backend è organizzato secondo una struttura modulare a layer:

```
Backend/
├── app/
│   ├── main.py                # Entry point: lifespan, CORS, router registration
│   ├── config.py              # Settings Pydantic (lettura tipizzata da .env)
│   ├── azure_clients.py       # Singleton client SDK Azure (Blob asincrono, Cosmos)
│   ├── models/
│   │   ├── article.py         # ManualMetadata, MetadataIA, ArticleDocument,
│   │   │                      #   ArticleUpdateModel, EmbeddingDocument
│   │   └── chunk.py           # RagSearchQuery, GenericSearchQuery, ArticleChatQuery
│   ├── routers/
│   │   ├── articles.py        # CRUD completo articoli
│   │   ├── search.py          # RAG, keyword, chat contestuale
│   │   └── utente.py          # Autenticazione (addUtente, login)
│   └── services/
│       ├── blob_service.py        # Upload, download, delete su Azure Blob Storage
│       ├── cosmos_service.py      # CRUD metadati su Cosmos DB
│       ├── search_service.py      # Setup indice, indicizzazione, ricerca, similarità
│       ├── ai_service.py          # Metadati AI, embedding, RAG, chat
│       └── ingestion_service.py   # Parser multiformat
├── autentication/
│   ├── keycloack_service.py   # Verifica JWT (OIDC/RS256), addUtente, login_user
│   └── docker-compose.yml     # Stack Keycloak containerizzato per sviluppo locale
├── requirements.txt
└── .env / .env.example
```

#### Gestione della Configurazione (`config.py`)

La configurazione è centralizzata tramite `pydantic-settings` (`BaseSettings`) per il caricamento tipizzato dal file `.env`. Il pattern **fail-fast** garantisce che l'applicazione non si avvii in assenza di credenziali obbligatorie, prevenendo errori runtime difficili da diagnosticare.

#### Client Azure Centralizzati (`azure_clients.py`)

I client degli SDK Azure sono istanziati come **singleton** a livello di modulo. Il client di Azure Blob Storage adotta la variante **asincrona** (`azure.storage.blob.aio.BlobServiceClient`): l'uso del client sincrono in un contesto `async def` bloccherebbe il thread dell'event loop, degradando le prestazioni sotto carico.

### 4.2 Modelli Dati (Pydantic)

| Modello | Campi principali | Ruolo |
|---------|-----------------|-------|
| `ManualMetadata` | `title`, `author`, `category`, `description`, `tags` | Metadati inseriti dall'utente |
| `MetadataIA` | `subtitle`, `summary`, `keywords`, `category`, `language`, `entities` | Metadati generati dall'LLM |
| `ArticleDocument` | `id`, `user_id`, `blob_url`, `cover_url`, `uploaded_at`, `manual`, `IA_metadata` | Documento completo su Cosmos DB |
| `ArticleUpdateModel` | `title`, `author`, `description`, `category`, `tags` (tutti opzionali) | Aggiornamento parziale metadati |
| `EmbeddingDocument` | `chunk_id`, `article_id`, `chunk_text`, `embedding` | Documento chunk su AI Search |
| `ArticleChatQuery` | `question`, `current_article_id` | Query per chat contestuale |

Il modello `MetadataIA` viene passato a `llm.with_structured_output(MetadataIA)` per il *function calling*, garantendo output JSON sempre deserializzabile e tipizzato.

### 4.3 Ingestion e Parsing Multiformat (`ingestion_service.py`)

La funzione `extract_text_from_file(file_bytes, filename)` supporta:

| Formato | Libreria | Strategia di Estrazione |
|---------|---------|------------------------|
| `.txt`, `.md` | Built-in Python | Decodifica UTF-8 diretta |
| `.json` | `json` (stdlib) | Parse strutturato + re-serializzazione come stringa |
| `.docx` | `python-docx` | Estrazione paragrafo per paragrafo via `Document.paragraphs` |
| `.pdf` | `PyPDF2` | Estrazione pagina per pagina via `PdfReader.pages` |

Per i formati non riconosciuti viene sollevata una `ValueError` che il layer superiore trasforma in `HTTP 400 Bad Request`.

### 4.4 Pipeline di Upload (`POST /articles/upload`)

L'endpoint è protetto da `Depends(get_current_user)`. Il flusso orchestrato è il seguente:

[RIFERIMENTO DIAGRAMMA PIPELINE DI UPLOAD]

1. **Validazione input**: filename non vuoto, altrimenti `HTTP 400`.
2. **Controllo duplicazione per titolo**: query Cosmos DB parametrizzata `c.manual.title = @title`; se esiste, `HTTP 400`.
3. **Generazione UUID v4**: identificatore univoco per articolo e nome blob (`{article_id}.{ext}`).
4. **Parsing del file**: `extract_text_from_file()` restituisce il testo grezzo.
5. **Controllo similarità semantica (deduplicazione vettoriale)**: i primi 500 caratteri vengono convertiti in embedding e confrontati con AI Search (`k=1`, soglia `0.90`). Se il punteggio supera la soglia, `HTTP 400`. Il controllo avviene **prima** dell'upload su Blob, evitando sprechi di risorse su contenuti che verranno rifiutati.
6. **Upload Blob Storage**: file su `articles-raw`, copertina opzionale su container dedicato tramite `upload_cover()`.
7. **Costruzione `ManualMetadata`**: normalizzazione categorie e tag.
8. **Generazione metadati AI**: `generate_ai_metadata()` (asincrona) restituisce `MetadataIA` validato da Pydantic.
9. **Costruzione `ArticleDocument`**: aggregazione di tutti i campi, incluso `user_id` estratto dal claim `sub` del token JWT.
10. **Persistenza Cosmos DB (articoli)**: serializzazione con `.model_dump(mode='json')` e `save_article_metadata()`.
11. **Chunking e persistenza chunk**: `chunking()` + `save_chunks_metadata()` nel container `chunks`.
12. **Embedding e indicizzazione vettoriale**: `generate_embedding_for_chunks()` + `index_chunk_to_ai_search()`.
13. **Risposta `HTTP 201 Created`**: `status`, `message`, `filename`, `blob_url`, `cover_url`.

### 4.5 Generazione Metadati via LLM (LangChain + Azure OpenAI)

Il modulo `app/services/ai_service.py` implementa la pipeline di generazione metadati.

#### Schema di Output (Pydantic + Structured Output)

| Campo | Tipo | Semantica |
|-------|------|-----------|
| `subtitle` | `str` | Sottotitolo editoriale sintetico |
| `summary` | `str` | Riassunto dettagliato (3-4 frasi corpose) |
| `keywords` | `List[str]` | Parole chiave tematiche |
| `category` | `List[str]` | Categorie giornalistiche |
| `language` | `str` | Lingua rilevata dell'articolo |
| `entities` | `List[str]` | Entità nominate (formato `"tipo: nome"`) |

`llm.with_structured_output(MetadataIA)` utilizza il **function calling** di Azure OpenAI per vincolare il modello a produrre un output JSON strettamente conforme allo schema, eliminando la necessità di parsing manuale.

#### Chain LangChain (LCEL)

```python
ai_metadata_chain = prompt | structured_llm
```

Il `ChatPromptTemplate` definisce:
- **System message**: ruolo di "assistente editoriale esperto", regole di estrazione, vincoli sul formato;
- **Human message**: testo dell'articolo iniettato via `{text_content}`.

La chain è invocata tramite `ainvoke()` (asincrona), compatibile con il runtime `asyncio` di FastAPI. In caso di errore, viene sollevata `HTTPException 503 Service Unavailable`.

#### Modalità TEST_MODE

In modalità `TEST_MODE=True`, tutte le funzioni di `ai_service.py` restituiscono risposte mock predeterminate, consentendo sviluppo e testing senza consumo di crediti Azure OpenAI.

### 4.6 Chunking, Embedding e Indicizzazione Vettoriale

[RIFERIMENTO DIAGRAMMA PIPELINE DI INDICIZZAZIONE VETTORIALE]

#### Inizializzazione Automatica dell'Indice (`setup_ai_search_index`)

All'avvio tramite `lifespan`, la funzione verifica e crea automaticamente l'indice vettoriale su Azure AI Search:

| Campo | Tipo AI Search | Proprietà |
|-------|---------------|-----------|
| `chunk_id` | `String` | Chiave primaria |
| `article_id` | `String` | Filtrabile |
| `chunk_text` | `String` | Ricercabile full-text |
| `embedding` | `Collection(Single)` | Vettore 1536 dimensioni, profilo HNSW |

In caso di indice già esistente, `ResourceExistsError` viene catturato e il server si avvia normalmente. Questa funzionalità costituisce un elemento di **Infrastructure as Code applicativo** che garantisce la coerenza dello schema senza interventi manuali.

#### Chunking (`ai_service.chunking`)

`RecursiveCharacterTextSplitter` con `chunk_size=500` e `chunk_overlap=50`. La sovrapposizione preserva il contesto ai margini dei frammenti, evitando interruzioni semantiche nette che degraderebbero la qualità del retrieval.

#### Generazione Embedding (`ai_service.generate_embedding_for_chunks`)

`AzureOpenAIEmbeddings.aembed_documents()` trasforma ogni chunk in un vettore denso a **1536 dimensioni**, restituendo una lista parallela nel medesimo ordine dei chunk in ingresso.

#### Indicizzazione (`search_service.index_chunk_to_ai_search`)

`zip(chunks, embedding)` con `enumerate` accoppia deterministicamente testo e vettore, generando `chunk_id = {article_id}-chunk-{index}`. Il caricamento avviene con una singola chiamata batch `upload_documents` tramite il client asincrono (`azure.search.documents.aio.SearchClient`) gestito con `async with` per il rilascio corretto delle risorse HTTP.

#### Deduplicazione Semantica (`search_service.check_similarity`)

`VectorizedQuery` con `k_nearest_neighbors=1` e soglia `0.90`: rileva contenuti riformulati o leggermente modificati che eluderebbero un controllo sul solo titolo. L'esecuzione prima dell'upload su Blob risparmia sia storage che crediti OpenAI.

### 4.7 Motore RAG (`POST /search/rag`) e Chat AI (`POST /search/article-chat`)

[RIFERIMENTO DIAGRAMMA PIPELINE RAG]

#### Flusso della Pipeline RAG

1. **Embedding della domanda**: `generate_embedding_for_chunks([query.question])` produce un vettore a 1536 dimensioni.
2. **Ricerca chunk rilevanti** (`search_relevant_chunks`): `VectorizedQuery` con `k_nearest_neighbors=3`. Se nessun chunk viene trovato, risposta "non trovato" senza invocare il LLM (risparmio crediti).
3. **Recupero articoli completi**: per ogni `article_id` distinto nei chunk rilevanti, `get_article_by_id()` da Cosmos DB.
4. **Generazione risposta RAG** (`generate_rag_answer`): `rag_prompt | llm` con `ainvoke()`. Il system message vincola il modello a rispondere **esclusivamente** dal contesto fornito, con fallback esplicito in assenza di informazioni pertinenti.
5. **Risposta strutturata**: `question`, `answer`, `relevant_chunks` (articoli completi per la tracciabilità delle fonti).

#### Endpoint Ricerca per Keyword (`POST /search/generic`)

`cosmos_service.search_by_keywords()` esegue query Cosmos DB SQL con `CONTAINS()` case-insensitive su cinque campi (`title`, `description`, `author`, `category`, `tags`), con supporto per ricerche su array tramite `EXISTS(SELECT VALUE ... FROM ... IN ...)`.

#### Chat AI Contestuale (`POST /search/article-chat`)

`generate_chat_answer(relevant_chunks, question, current_article_id)` differisce da `generate_rag_answer` per un prompt di sistema arricchito che:
- Informa il modello dell'`article_id` correntemente letto dall'utente;
- Distingue chunk dell'articolo corrente da chunk di altri articoli;
- Se rileva chunk di articoli semanticamente correlati, segnala attivamente i contenuti correlati, incentivando la navigazione.

### 4.8 CRUD Completo degli Articoli

| Metodo | Endpoint | Auth | Descrizione |
|--------|---------|------|-------------|
| `POST` | `/articles/upload` | Richiesta | Upload, pipeline AI, indicizzazione |
| `GET` | `/articles` | Pubblica | Lista paginata con filtri categoria e ordinamento |
| `GET` | `/articles/me` | Richiesta | Articoli dell'utente autenticato con ricerca keyword |
| `GET` | `/articles/{id}` | Pubblica | Dettaglio articolo con chunk |
| `GET` | `/articles/{id}/download` | Richiesta | Download file originale da Blob Storage |
| `GET` | `/articles/{id}/cover` | Pubblica | Download immagine di copertina (proxy backend) |
| `DELETE` | `/articles/{id}/delete` | Richiesta (owner) | Eliminazione cascata (Blob + Cosmos + AI Search) |
| `PUT` | `/articles/{id}/update` | Richiesta (owner) | Aggiornamento selettivo metadati manuali |

#### Paginazione e Filtri (`GET /articles`)

| Parametro | Tipo | Default | Semantica |
|-----------|------|---------|-----------|
| `decreasing` | `bool` | `false` | `false` = più recenti per primi |
| `category` | `str` | `None` | Filtro `ARRAY_CONTAINS` sulla categoria |
| `skip` | `int` | `0` | Offset paginazione (infinite scroll) |
| `limit` | `int` | `10` | Elementi per pagina |

#### Eliminazione Cascata con Ownership

L'eliminazione verifica `article.user_id == current_user['sub']` (`HTTP 403` se non autorizzato), poi elimina in sequenza: file Blob, copertina Blob, metadati e chunk Cosmos DB, vettori AI Search (`chunk_id = {article_id}-chunk-{i}` deterministico). Nessun dato orfano rimane nel sistema.

#### Aggiornamento Selettivo (`PUT /articles/{id}/update`)

`update_data.model_dump(exclude_unset=True)` estrae solo i campi forniti, applicandoli esclusivamente al sotto-documento `manual` tramite `replace_item()`. I metadati AI e i dati di sistema rimangono intatti.

### 4.9 Autenticazione tramite Keycloak (OIDC/JWT)

[RIFERIMENTO DIAGRAMMA FLUSSO AUTENTICAZIONE OIDC]

#### Verifica Token JWT (`get_current_user`)

1. Estrazione Bearer token via `HTTPBearer`;
2. Download JWKS da `{KEYCLOAK_SERVER_URL}/realms/{realm}/protocol/openid-connect/certs` (rotazione chiavi trasparente);
3. Verifica crittografica RS256 con `python-jose` (firma, scadenza `exp`, issuer `iss`);
4. Restituzione payload (`sub`, `preferred_username`, claim OIDC) tramite `Depends(get_current_user)`;
5. `HTTP 401 Unauthorized` con header `WWW-Authenticate: Bearer` in caso di token non valido, scaduto o alterato.

#### Registrazione (`POST /utente/addUtente`) e Login (`POST /utente/login`)

- **Registrazione**: `KeycloakAdmin.create_user()` + `set_user_password(temporary=False)`;
- **Login**: flusso **Direct Access Grants (OAuth 2.0 ROPC)** via `KeycloakOpenID.token()`, restituisce `access_token`, `refresh_token` e `expires_in`.

Entrambi gli endpoint consentono al Frontend di gestire il ciclo di autenticazione senza reindirizzare l'utente alle pagine predefinite di Keycloak.

### 4.10 Frontend Flutter — Architettura e Schermate

| File/Modulo | Responsabilità |
|-------------|---------------|
| `main.dart` | Home Page: lista articoli, ricerca RAG/Normal, navigazione |
| `api_config.dart` | Costante globale `baseUrl` |
| `shared_preferences.dart` | Wrapper singleton persistenza token JWT |
| `utils.dart` | Modello `Articolo` con `fromJson()` e `toMap()` |
| `pages/login_page.dart` | Login e Registrazione animata |
| `pages/upload_page.dart` | Upload articolo con drag-and-drop |
| `pages/detail_page.dart` | Dettaglio articolo con chat AI e generazione PDF |
| `pages/cronologia_page.dart` | Cronologia articoli utente |
| `pages/info_page.dart` | Informazioni sull'applicazione |

#### Design System — Palette Cromatica (Regola 60-30-10)

| Ruolo | Colore | Esadecimale |
|-------|--------|-------------|
| Sfondo (60%) | Grigio chiaro | `#F4F6F8` |
| Principale (30%) | Marrone caldo | `#7F5539` |
| Accento (10%) | Arancione vivace | `#FF6B35` |

#### Home Page (`main.dart`)

**AppBar**:

| Posizione | Widget | Funzionalità |
|-----------|--------|-------------|
| Sinistra | `Text` (titolo) | Identità dell'applicazione ("NewsArchive") |
| Centro-sinistra | `DropdownButton<String>` | Filtro per categoria con refresh automatico |
| Centro-destra | `TextField` con bordi circolari | Barra di ricerca RAG/Normal |
| Destra | `Switch` + `IconButton` | Toggle modalità ricerca + menu Drawer |

**Drawer** (`endDrawer`): navigazione verso Login, Cronologia, Upload, Informazioni tramite `ListTile`.

**Body — Infinite Scroll**: `GridView.builder` con `ScrollController`. A 200px dal fondo, caricamento pagina successiva tramite `GET /articles?skip=N&limit=10&category=...`. `RefreshIndicator` per il reset completo.

**Card Articolo**: immagine copertina (`cover_url`) via `Image.network`/`BoxFit.cover` (o placeholder contestuale), badge categoria, titolo (max 2 righe, `TextOverflow.ellipsis`), autore.

#### Schermata Upload (`upload_page.dart`)

- Drag-and-drop via `DropTarget` (`desktop_drop`) per documento e copertina;
- `FilePicker` per selezione da filesystem;
- `FilterChip` per categorie predefinite + categoria custom;
- Chip tag rimovibili;
- Verifica login all'avvio; upload disabilitato per utenti non autenticati.

#### Schermata Dettaglio (`detail_page.dart`)

- Layout responsive (breakpoint 900px: colonne affiancate vs verticali);
- Metadati manuali e analisi IA (parole chiave come chip, entità, riassunto);
- Download file originale e generazione PDF metadati;
- Chat AI contestuale: pannello laterale con auto-scroll, distinzione visiva messaggi, restrizione utenti autenticati.

#### Schermata Cronologia (`cronologia_page.dart`)

- `GET /articles/me` con token Bearer; infinite scroll su `ListView.builder`;
- Ricerca per keyword (`?keyword=...`); eliminazione con dialog di conferma; accesso all'aggiornamento.

---

## 5. Funzionalità Extra-Traccia

La presente sezione documenta le implementazioni che superano i requisiti minimi di traccia, evidenziandone l'utilità pratica e il grado di innovazione apportato al sistema.

### 5.1 Generazione PDF dei Metadati Articolo (Lato Client)

**Descrizione**: Nella schermata di Dettaglio, l'utente autenticato può generare e scaricare un documento PDF riassuntivo dell'articolo, contenente tutti i metadati (manuali e AI), l'immagine di copertina e il riassunto LLM.

**Implementazione**: La generazione avviene interamente **lato client** tramite la libreria `pdf` (`^3.10.8`) di Flutter. Il processo comprende: recupero copertina via `GET /articles/{id}/cover` (accesso centralizzato, non URL diretto Blob); costruzione layout PDF con `pw.MultiPage`, tipografia (`Times`/`TimesBold`/`TimesItalic`), paginazione automatica e footer con numerazione; download automatico via API Web (`html.Blob`, `html.AnchorElement`) senza ricaricare la pagina.

**Utilità e Innovazione**: Funzionalità premium per la condivisione e l'archiviazione off-line dei dati analitici in formato universale. L'approccio lato client elimina il carico elaborativo dal backend, costituendo un esempio di *edge-computing* applicato alla generazione documentale. Disponibile esclusivamente per utenti autenticati.

### 5.2 Eliminazione Cascata Multi-Layer con Autorizzazione per Ownership

**Descrizione**: `DELETE /articles/{id}/delete` elimina in modo sicuro e completo un articolo e tutte le sue risorse associate su tre sistemi di persistenza distinti.

**Implementazione**: (1) `HTTP 404` se l'articolo non esiste; (2) `HTTP 403` se `article.user_id != current_user['sub']`; (3) eliminazione file Blob; (4) eliminazione copertina Blob; (5) eliminazione metadati e chunk Cosmos DB con restituzione del conteggio chunk; (6) eliminazione vettori AI Search con `chunk_id = {article_id}-chunk-{i}` deterministico.

**Utilità e Innovazione**: La coerenza dei dati su tre sistemi di persistenza eterogenei (Blob Storage, Cosmos DB, AI Search) è un problema architetturale non banale. L'approccio garantisce l'assenza di dati orfani che potrebbero causare sprechi di storage o inquinare i risultati di ricerca vettoriale.

### 5.3 Chat AI Contestuale per Articolo (`POST /search/article-chat`)

**Descrizione**: Pannello di chat laterale nella schermata Dettaglio, con agente AI contestualmente consapevole dell'articolo correntemente letto dall'utente.

**Implementazione Backend** (`generate_chat_answer`): il system message inietta `current_article_id`, distingue chunk dell'articolo corrente da chunk di altri articoli, segnala attivamente contenuti correlati nell'archivio. Applica regole di risposta più flessibili rispetto alla RAG generica.

**Implementazione Frontend**: pannello laterale con lista messaggi (`isAi: true/false`), indicatore di caricamento `_isChatLoading`, auto-scroll animato dopo ogni messaggio, restrizione ad utenti autenticati.

**Utilità e Innovazione**: Trasforma la schermata di dettaglio da visualizzazione statica a esperienza interattiva di esplorazione dell'archivio. La consapevolezza contestuale dell'agente consente domande naturali di approfondimento ("Spiega meglio questo concetto", "Ci sono altri articoli sull'argomento?") con risposte rilevanti e personalizzate.

### 5.4 Aggiornamento Selettivo dei Metadati (`PUT /articles/{id}/update`)

**Descrizione**: Aggiornamento parziale dei metadati manuali senza rieseguire la pipeline di upload e re-indicizzazione.

**Implementazione**: `model_dump(exclude_unset=True)` estrae solo i campi forniti, applicandoli esclusivamente al sotto-documento `manual` via `replace_item()`. Protezione ownership identica all'eliminazione.

**Utilità**: Correzione post-pubblicazione di metadati errati (titolo, autore) senza ri-elaborazione AI — operazione costosa in termini di crediti Azure OpenAI.

### 5.5 Download Diretto del Documento Originale (`GET /articles/{id}/download`)

**Descrizione**: Download del file grezzo nel formato originale (TXT, MD, JSON, DOCX, PDF) da Blob Storage, con preservazione del `Content-Type` e del filename originale.

**Implementazione**: Recupero `blob_url` da Cosmos DB, estrazione filename, download bytes via `download_file()` (client asincrono), risposta `fastapi.Response` con `Content-Disposition: attachment`. Il Frontend usa Web API per il download senza navigazione.

**Utilità e Innovazione**: Il routing del download attraverso il Backend centralizza il controllo di accesso: gli URL dei blob non sono esposti direttamente al client, e ogni operazione di accesso ai file è mediata dal backend con possibilità di applicare policy di autorizzazione uniformi.

### 5.6 Proxy Backend per Copertine (`GET /articles/{id}/cover`)

**Descrizione**: Proxy trasparente tra Frontend e container immagini Azure Blob Storage, senza esporre credenziali o URL interni al client.

**Utilità**: Coerente con il principio di accesso centralizzato. Intercetta richieste a immagini placeholder (URL contenente `"placeholder"`) restituendo `HTTP 404`, gestendo uniformemente l'assenza di copertina.

### 5.7 UI di Login e Registrazione Animata (Custom Flutter)

**Descrizione**: Interfaccia di autenticazione Flutter custom animata, che evita il reindirizzamento alle pagine predefinite di Keycloak.

**Implementazione**: Toggle animato tra form Login e Registrazione; validazione locale con dialog informativi; `POST /utente/login` con persistenza `access_token`/`refresh_token` in `SharedPreferences`; `POST /utente/addUtente` per la registrazione; toggle visibilità password; supporto al parametro `popAfterLogin` per navigazione contestuale.

**Utilità e Innovazione**: Mantiene l'esperienza utente coerente con il design system, mascherando la complessità IAM. Il flusso **Direct Access Grants** è appropriato per applicazioni client native di fiducia, in cui le credenziali sono inviate direttamente all'endpoint token del backend senza redirect browser.

### 5.8 Drag-and-Drop per l'Upload di File

**Descrizione**: `DropTarget` (`desktop_drop`) per documenti e immagini di copertina nella schermata Upload.

**Implementazione**: Due aree di drop distinte con feedback visivo durante il trascinamento (`_isDraggingDoc`, `_isDraggingCover`). Compatibilità con `FilePicker` per alternare tra drag-and-drop e selezione tradizionale.

**Utilità**: Migliora l'ergonomia su piattaforme desktop e web, riducendo il numero di click e avvicinando l'esperienza ai moderni strumenti di produttività.

### 5.9 Deduplicazione Semantica Pre-Upload (Vettoriale)

**Descrizione**: Doppia deduplicazione pre-upload: identità del titolo (Cosmos DB) e similarità semantica del contenuto (AI Search, soglia 0.90).

**Motivazione Architetturale**: Il solo controllo sul titolo è insufficiente: articoli quasi identici con titoli diversi eluderebbero il controllo. La soglia del 90% di similarità coseno nello spazio degli embedding rileva contenuti riformulati o leggermente modificati. L'esecuzione prima dell'upload su Blob risparmia sia storage che crediti OpenAI per contenuti destinati al rifiuto.

---

## 6. Trasparenza IA e Metodologia di Sviluppo

Il progetto è stato condotto secondo una metodologia *"Review-driven development"*: interazione iterativa con agenti AI per la definizione architetturale, la code review e il raffinamento del codice. Gli agenti AI sono stati impiegati come strumenti di supporto e verifica; la logica applicativa, il design architetturale e la scrittura del codice principale sono stati condotti dallo studente.

### 6.1 Registro delle Interazioni (Log degli Agenti AI)

| Feature / Task | Agente | Prompt Principale | Sintesi Azione |
|---|---|---|---|
| Revisione IaC Bicep, Commenti e README | Claude Sonnet 4.6 | "Verifica la correttezza dei file Bicep. Aggiungi commenti esplicativi e genera il README con istruzioni per Azure CLI." | Validazione Bicep con commenti esplicativi. Generazione README con comandi `az login`, `az group create`, `az deployment`. |
| Refactoring Bicep OpenAI — conformità region policy `italynorth` | Claude Sonnet 4.6 | "Adatta il modulo Bicep OpenAI ai vincoli Azure for Students UniCal (italynorth obbligatorio). Solo account base; deployment modelli via Azure AI Studio." | Refactoring `openai.bicep`: rimossi blocchi deployment modelli (lasciati in commento per riferimento); aggiornati `main.bicep`, `parameters.json`, `README.md` e la relazione. |
| Verifica formattazione e mappatura `.env` | Claude Sonnet 4.6 | "Genera `backend/.env` e `backend/.env.example` mappando le variabili d'ambiente secondo la struttura Bicep." | Validazione sintassi variabili d'ambiente. Verifica corrispondenza con SDK Python. Generazione `.env.example` privo di credenziali. Verifica `.gitignore`. |
| Code Review Task 2.4 — Metadati AI (LangChain + Azure OpenAI) | Claude Sonnet 4.6 | "Code review Task 2.4: integrazione AzureChatOpenAI, Pydantic structured output, gestione errori, conflitti runtime asincrono FastAPI." | Identificati e corretti 3 bug: (1) `await` mancante su `generate_ai_metadata()` in `articles.py`; (2) nome variabile errato `AZURE_OPENAI_API_KEY` → `AZURE_OPENAI_KEY`; (3) deployment hardcoded `"gpt-4.1-mini"` sostituito con `settings.AZURE_OPENAI_CHAT_DEPLOYMENT`. |
| Code Review Task 2.6 — Indicizzazione AI Search | Claude Sonnet 4.6 | "Code review `index_chunk_to_ai_search`: uso di `zip()`, `enumerate()`, serializzazione Pydantic, client asincrono, blocco TEST_MODE." | **Codice scritto interamente dallo studente.** Identificati e corretti 4 bug: (1) import sincrono → asincrono (`aio.SearchClient`); (2) chiave errata `AZURE_SEARCH_KEY` → `AZURE_SEARCH_ADMIN_KEY`; (3) assenza blocco TEST_MODE; (4) indentazione errata. |
| Scelta del protocollo di sicurezza (ADR) | Gemini 1.5 Pro | "Valuta JWT custom vs MSAL per il progetto." | Analisi comparativa. Scelta motivata verso Keycloak+OIDC per il principio "Don't roll your own crypto", aggiramento dei limiti della sottoscrizione accademica. |
| Implementazione Keycloak e review upload copertine | Gemini 1.5 Pro | "Implementa i servizi Keycloak e code review sull'upload con immagini." | Fix deadlock asincroni upload. Implementazione `get_current_user` e `get_keycloak_public_key`. Verifica architetturale integrazione Keycloak. |
| Generazione e Refinement UI Home Page Flutter (Task 4.1) | Claude Opus 4.6 | "Implementa la Home Page in `main.dart`: AppBar, Drawer, Infinite Scroll su GridView.builder di Card." | Implementazione iterativa `main.dart`: struttura completa; sistema colori globale (`colorePrincipale = #1B1B1B`, `coloreSecondario = #9B111E`); coerenza cromatica estesa. Dati mock per sostituzione con chiamate HTTP. |
| Implementazione UI Login Animata (Frontend) | Gemini 1.5 Pro | "Adatta una schermata di login animata al mio codice Flutter per non usare le pagine predefinite di Keycloak." | Trasposizione animazione in widget Flutter nativi. Adattamento al design system. Fix bug overlay nei field di testo. Preparazione per integrazione Direct Access Grants. |

---

## 7. Conclusioni e Sviluppi Futuri

### 7.1 Conclusioni

Il progetto ha realizzato con successo un sistema cloud-native completo per la gestione e la ricerca intelligente di un archivio di notizie, basato interamente su Microsoft Azure. L'architettura adottata — caratterizzata dalla separazione dei layer di presentazione, orchestrazione e persistenza — garantisce scalabilità, manutenibilità e sicurezza. L'integrazione della pipeline RAG con Azure OpenAI e Azure AI Search consente un accesso semantico ai contenuti di qualità editoriale, superando significativamente le capacità di un sistema di ricerca tradizionale per parola chiave.

Le scelte tecnologiche adottate (FastAPI per le prestazioni asincrone, LangChain per l'orchestrazione AI, Flutter per la cross-platform UI, Keycloak per l'IAM standard) sono state selezionate e motivate per massimizzare la qualità del sistema nel rispetto dei vincoli infrastrutturali della sottoscrizione accademica.

Le **funzionalità extra-traccia** implementate — chat AI contestuale, generazione PDF lato client, eliminazione cascata multi-layer, drag-and-drop, deduplicazione semantica vettoriale, proxy backend per copertine, aggiornamento selettivo dei metadati — arricchiscono significativamente il valore applicativo del sistema, trasformandolo da una prova di concetto architetturale in un'applicazione fruibile con caratteristiche di prodotto reale.

### 7.2 Sviluppi Futuri

- **Containerizzazione e Deploy su Azure Container Apps**: sfruttare il modulo `acr.bicep` predisposto per un deployment scalabile con auto-scaling in base al numero di richieste;
- **Hybrid Search avanzato**: combinare ricerca vettoriale e full-text BM25 per migliorare la precisione su query brevi o con termini specifici;
- **Re-indicizzazione vettoriale automatica**: ricalcolo degli embedding al momento dell'aggiornamento del testo tramite `PUT /articles/{id}/update`;
- **Supporto formati aggiuntivi**: estensione di `ingestion_service.py` per HTML, EPUB, PPTX;
- **Refresh Token automatico**: logica di refresh del JWT prima della scadenza, eliminando la necessità di ri-login.

---

*Documento redatto nell'ambito del corso di Sistemi Distribuiti e Cloud Computing — Università della Calabria.*
*Data ultima revisione: Settembre 2026.*
