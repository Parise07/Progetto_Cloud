# Relazione di Progetto: Sistema RAG per l'Archiviazione e Ricerca di Notizie

## 1. Introduzione e Obiettivi

### 1.1 Contesto
Il presente documento descrive la progettazione e l'implementazione di un sistema cloud-native per la gestione di un archivio di notizie. In un contesto in cui il volume di informazioni cresce esponenzialmente, si rende necessario un sistema intelligente capace non solo di archiviare, ma anche di analizzare, indicizzare e ricercare contenuti testuali in modo efficiente.

### 1.2 Requisiti di traccia
Il sistema richiede la realizzazione di un'applicazione basata su piattaforma cloud in grado di gestire il caricamento di articoli testuali in formati standard (TXT, Markdown, JSON) e facoltativamente in formati complessi (DOCX, PDF). Una volta caricato, l'articolo necessita dell'estrazione del contenuto, della generazione automatica di metadati descrittivi e dell'indicizzazione per consentire sia ricerche tradizionali che interrogazioni in linguaggio naturale tramite l'integrazione di un sistema RAG (Retrieval-Augmented Generation). L'intera infrastruttura deve essere obbligatoriamente basata su Microsoft Azure.

### 1.3 Obiettivi del sistema
Gli obiettivi principali consistono nella realizzazione di un'architettura disaccoppiata (decoupled), scalabile e resiliente. Si mira a fornire un'interfaccia utente multipiattaforma accessibile, supportata da un backend robusto in grado di orchestrare pipeline di intelligenza artificiale avanzate per l'arricchimento semantico dei documenti e la successiva fase di retrieval.

## 2. Architettura del Sistema

### 2.1 Panoramica decoupled
L'architettura proposta prevede una netta separazione delle responsabilità attraverso un approccio a tre layer: Frontend, Backend e Servizi Cloud. Questa modularità garantisce la possibilità di evolvere, scalare e manutenere i singoli componenti in maniera indipendente, limitando l'accoppiamento architetturale.

![Diagramma Architetturale](images_rel/architettura.png)

### 2.2 Motivazioni dell'architettura multi-layer
Si è optato per un'architettura multi-layer per massimizzare la flessibilità del sistema. Il frontend, operando come client autonomo, comunica tramite protocollo HTTP/REST (JSON) con il backend, il quale funge da orchestratore centrale della logica di business e delle pipeline di intelligenza artificiale. I servizi Azure sottostanti operano come layer di persistenza e computazione specializzata, accessibili esclusivamente tramite le API del backend, garantendo un controllo centralizzato sulla sicurezza e sui flussi di dati.

### 2.3 Gestione delle Identità e Sicurezza (Autenticazione)
Per proteggere gli endpoint sensibili e differenziare l'utenza pubblica da quella autenticata, il sistema richiede un'infrastruttura di Identity and Access Management (IAM).
In linea con le best practice di sicurezza cloud ("Don't roll your own crypto"), si è deciso di non implementare una soluzione custom, ma di delegare la gestione delle identità, delle password e dei token a un Identity Provider (IdP) certificato. A causa delle stringenti limitazioni sui permessi di amministrazione della directory imposti dalla sottoscrizione Azure for Students (che inibiscono la creazione di un tenant Azure Entra ID B2C), l'autenticazione è stata demandata a Keycloak. Questa scelta architetturale garantisce l'uso dei flussi standard OAuth2.0 / OpenID Connect, mantenendo il sistema sicuro, flessibile e pronto per un'eventuale federazione con altri provider in scenari di produzione reali, senza violare i vincoli infrastrutturali della traccia.

## 3 Tecnologie e Strumenti

### 3.1 Servizi Azure

#### Azure Blob Storage
Per l'archiviazione dei file originali (TXT, MD, JSON, DOCX, PDF) si è scelto Azure Blob Storage. L'adozione di tale servizio è motivata dalla sua natura di standard de-facto per l'object storage in ambiente Azure, in grado di offrire scalabilità virtualmente illimitata, elevata affidabilità e un'integrazione nativa con gli altri strati cloud.

#### Azure Cosmos DB
La gestione dei metadati, sia manuali che auto-generati, è affidata ad Azure Cosmos DB (API NoSQL). Essendo lo schema degli articoli fortemente eterogeneo e variabile nel tempo, l'adozione di un database documentale JSON-native risulta strutturalmente superiore a un approccio relazionale rigido. L'utilizzo in modalità Serverless è stato scelto per ottimizzare i costi operativi e garantire una risposta prestazionale istantanea per query sui metadati.

#### Azure AI Search
Per l'indicizzazione vettoriale dei frammenti di testo (chunk) e la ricerca semantica è stato adottato Azure AI Search. Tale componente unisce funzionalità di ricerca vettoriale (tramite algoritmi HNSW) e di ricerca full-text tradizionale (Hybrid Search) all'interno di un unico servizio gestito, eliminando la necessità di orchestrare database vettoriali di terze parti e abbassando la complessità operativa.

#### Azure OpenAI Service
L'integrazione dei modelli linguistici per la generazione dei metadati e il motore RAG si basa su Azure OpenAI Service. Si è adottato tale servizio per garantire conformità, bassa latenza e un'integrazione nativa e sicura all'interno dell'ecosistema cloud Azure. I modelli selezionati, `text-embedding-ada-002` per gli embedding e `gpt-4o-mini` per le operazioni di natural language processing, rappresentano lo stato dell'arte in termini di compromesso tra capacità elaborativa ed efficienza.

A causa delle restrizioni della policy della sottoscrizione **Azure for Students** dell'Università della Calabria — che impone l'uso esclusivo della regione `italynorth` e blocca il provisioning automatico verso regioni esterne — il provisioning tramite Bicep è limitato alla creazione dell'account base del servizio. I deployment dei modelli (`text-embedding-ada-002` e `gpt-4o-mini`) vengono distribuiti manualmente tramite **Azure AI Studio / Portale Azure** al termine del deploy IaC. Questa scelta architetturale, motivata da vincoli di policy e sicurezza imposti dalla piattaforma accademica, preserva la riproducibilità dell'infrastruttura base e garantisce la piena conformità con le policy della sottoscrizione.

#### Azure Bicep — Infrastructure as Code
Per il provisioning automatico e riproducibile delle risorse Azure si è adottato Azure Bicep come strumento nativo di Infrastructure as Code (IaC). Tale scelta, in netta contrapposizione alla configurazione manuale tramite portale web, è stata privilegiata anzitutto per motivi di sicurezza e controllo delle risorse: la gestione dichiarativa dell'infrastruttura azzera il rischio di errori umani (quali errate configurazioni di rete, dimenticanze sulle policy di cifratura o errate impostazioni sui livelli di accesso dei container) e consente di applicare rigorosi standard di sicurezza omogenei su tutte le risorse distribuite.

Dal punto di vista architetturale e metodologico, l'adozione di Azure Bicep garantisce:

Versionabilità e Tracciabilità: L'intera infrastruttura è trattata come codice sorgente e gestita direttamente all'interno della repository Git del progetto, permettendo di tracciare ogni modifica e mantenere uno storico completo delle evoluzioni architetturali.

Riproducibilità degli Ambienti: Consente di ricreare o scalare l'intero stack applicativo (dallo storage al database NoSQL, fino ai servizi di ricerca vettoriale) in modo del tutto identico e automatizzato, facilitando la gestione di ambienti separati di sviluppo, test e produzione.

Gestione Nativa dello Stato e Vantaggi Rispetto all'Approccio Manuale: Essendo lo strumento IaC nativo di Microsoft Azure, Bicep offre una sintassi dichiarativa fortemente semplificata rispetto ai tradizionali e complessi ARM template in formato JSON. Inoltre, a differenza di framework terzi (come Terraform), si integra nativamente con le API di Azure senza richiedere la gestione complessa e delicata di file di stato locali o remoti (.tfstate), allineando pienamente il progetto agli standard professionali e accademici più avanzati del settore.

### 3.2 FastAPI
Il layer backend è stato sviluppato in Python utilizzando il framework FastAPI. La scelta è ricaduta su tale tecnologia in virtù delle sue eccellenti prestazioni, del supporto nativo alla programmazione asincrona e dell'integrazione nativa con Pydantic per la validazione formale dei dati in ingresso, elementi cruciali per la realizzazione di API REST performanti in un sistema distribuito.

### 3.3 LangChain
Per l'orchestrazione delle pipeline di intelligenza artificiale si è optato per il framework LangChain. Rispetto alle alternative disponibili, LangChain offre una maggiore maturità e astrazione per la costruzione di catene RAG personalizzate, fornendo al contempo un'integrazione nativa ottimizzata con i servizi Azure OpenAI e Azure AI Search utilizzati.

### 3.4 Flutter/Dart
Il layer di presentazione (Frontend) è stato progettato utilizzando il framework Flutter (Dart). L'adozione di tale tecnologia consente di sviluppare un'applicazione client cross-platform a partire da un'unica base di codice, assicurando prestazioni native e un'interfaccia utente moderna e reattiva, requisiti essenziali per la fruizione ottimale dell'archivio notizie.

## 4. Dettagli Implementativi

### 4.1 Struttura del Backend (FastAPI)

Il backend è organizzato secondo una struttura modulare a layer, che separa nettamente la configurazione, i modelli dati, i router HTTP e i servizi di business logic:

```
backend/
├── app/
│   ├── main.py               # Entry point FastAPI: CORS, router, health-check
│   ├── config.py             # Settings Pydantic (lettura da .env)
│   ├── azure_clients.py      # Singleton client SDK Azure (Blob, Cosmos, Search, OpenAI)
│   ├── models/
│   │   ├── article.py        # Modelli Pydantic: ManualMetadata, ArticleDocument, EmbeddingDocument
│   │   └── chunk.py          # Modelli Pydantic: RagSearchQuery, GenericSearchQuery
│   ├── routers/
│   │   ├── articles.py       # Endpoint CRUD articoli (upload, lista, dettaglio)
│   │   └── search.py         # Endpoint ricerca RAG e keyword
│   └── services/
│       ├── blob_service.py        # Upload su Azure Blob Storage (client asincrono)
│       ├── cosmos_service.py      # CRUD metadati su Cosmos DB (articoli e chunk)
│       ├── search_service.py      # Indicizzazione e ricerca vettoriale su Azure AI Search
│       ├── ai_service.py          # Generazione metadati AI, embedding, risposta RAG (LangChain)
│       └── ingestion_service.py   # Parser multiformat (TXT/MD/JSON/DOCX/PDF)
├── autentication/
│   ├── keycloack_service.py  # Verifica JWT tramite Keycloak (OIDC/RS256)
│   └── docker-compose.yml    # Stack Keycloak locale per sviluppo
├── requirements.txt
└── .env / .env.example
```

#### Gestione della Configurazione (`config.py`)
La configurazione dell'applicazione è centralizzata nel modulo `config.py`, che sfrutta `pydantic-settings` (`BaseSettings`) per il caricamento tipizzato e validato delle variabili d'ambiente dal file `.env`. Questa scelta garantisce il fail-fast in fase di avvio: se una credenziale obbligatoria è assente, l'applicazione non si avvia, prevenendo errori runtime difficili da diagnosticare. Le variabili gestite includono le stringhe di connessione e le API key per tutti e quattro i servizi Azure (Blob Storage, Cosmos DB, AI Search, OpenAI).

#### Client Azure Centralizzati (`azure_clients.py`)
I client degli SDK Azure sono istanziati come singleton a livello di modulo in `azure_clients.py`. Una scelta progettuale rilevante riguarda il client di Azure Blob Storage: si è adottato il client **asincrono** (`azure.storage.blob.aio.BlobServiceClient`) anziché quello sincrono. Questa decisione è stata motivata dalla necessità di compatibilità con il runtime asincrono di FastAPI: l'uso del client sincrono all'interno di una funzione `async def` avrebbe provocato un blocco del thread dell'event loop, degradando le prestazioni sotto carico. L'uso del client asincrono garantisce che le operazioni I/O-bound verso Azure Blob non blocchino il server durante l'attesa della risposta.

### 4.2 Modelli Dati (Pydantic)

I modelli dati sono definiti con Pydantic in `app/models/article.py` e strutturati gerarchicamente:

- **`ManualMetadata`**: Incapsula i metadati inseriti manualmente dall'utente al momento dell'upload (`title`, `author`, `category`, `description`, `tags`). Tutti i campi sono opzionali, permettendo upload parziali senza errori di validazione.
- **`MetadataIA`**: Modello Pydantic che formalizza lo schema dei metadati generati dal modello linguistico. Definisce i campi `subtitle`, `keywords`, `category`, `language`, `summary` ed `entities`, tutti tipizzati e opzionali. La definizione di questo modello come schema Pydantic non assolve solo a una funzione di validazione: viene passato direttamente a `llm.with_structured_output(MetadataIA)` di LangChain, che utilizza lo schema JSON Schema derivato automaticamente da Pydantic per istruire il modello a produrre un output strutturato e deterministico (function calling).
- **`ArticleDocument`**: Rappresenta il documento completo persistito su Cosmos DB. Aggrega `id`, `blob_url`, `uploaded_at`, `manual_metadata` e il campo `IA_metadata` di tipo `MetadataIA`. La struttura gerarchica e separata per tipologia di metadati garantisce massima flessibilità per evoluzione futura dello schema senza migrazioni distruttive.

### 4.3 Ingestion & Parsing Multiformat (`ingestion_service.py`)

Il modulo `ingestion_service.py` implementa la funzione `extract_text_from_file(file_bytes, filename)`, responsabile dell'estrazione del contenuto testuale grezzo da tutti i formati supportati:

| Formato | Libreria | Strategia di estrazione |
|---------|----------|------------------------|
| `.txt`, `.md` | Built-in Python | Decodifica UTF-8 diretta |
| `.json` | `json` (stdlib) | Parse + re-serializzazione come stringa |
| `.docx` | `python-docx` | Estrazione paragrafo per paragrafo via `Document.paragraphs` |
| `.pdf` | `PyPDF2` | Estrazione pagina per pagina via `PdfReader.pages` |

Per i formati non riconosciuti viene sollevata una `ValueError` con messaggio esplicativo, che il layer superiore potrà catturare e trasformare in una risposta HTTP `400 Bad Request`.

### 4.4 Endpoint di Upload (`POST /articles/upload`)

L'endpoint `POST /articles/upload`, implementato in `app/routers/articles.py`, orchestra l'intera pipeline di ingestion per un singolo articolo. Il flusso eseguito è il seguente:

1. **Validazione dell'input**: Verifica che il file sia presente e che il filename non sia vuoto; in caso contrario restituisce `HTTP 400`.
2. **Generazione ID univoco**: Creazione di un UUID v4 tramite il modulo standard `uuid`, utilizzato sia come identificatore del documento su Cosmos DB sia come nome del blob (`{article_id}.{ext}`).
3. **Controllo duplicazione titolo**: Prima di procedere, viene invocata `check_title_exists(title)` che esegue una query su Cosmos DB per verificare se esiste già un documento con lo stesso titolo. In caso affermativo, l'endpoint restituisce `HTTP 400` con un messaggio esplicativo, impedendo la duplicazione di articoli nella raccolta.
4. **Controllo similarità semantica (deduplicazione vettoriale)**: I primi 500 caratteri del testo estratto vengono convertiti in embedding tramite `generate_embedding_for_chunks()`. Il vettore ottenuto viene passato a `check_similarity()`, che interroga Azure AI Search in modalità vettoriale con `k=1` e verifica se il punteggio del documento più vicino supera la soglia di 0.90. Se supera la soglia, l'upload viene bloccato con `HTTP 400` per prevenire l'inserimento di contenuti semanticamente quasi identici.
5. **Upload su Azure Blob Storage**: Il contenuto binario del file viene caricato nel container `articles-raw` tramite `blob_service.uploaded_file_to_blob()`. L'operazione è `await`-ata, sfruttando il client asincrono. Se il form include un'immagine di copertina (`cover_image`), viene caricata separatamente tramite `upload_cover()`, restituendo un `cover_url` associato all'articolo.
6. **Estrazione testo**: Il contenuto binario viene passato a `ingestion_service.extract_text_from_file()` per ottenere la stringa di testo grezzo su cui operano le pipeline AI successive.
7. **Costruzione dei metadati manuali**: I campi del form (`title`, `author`, `category`, `description`, `tags`) vengono istanziati in un oggetto `ManualMetadata`. I tag, ricevuti come stringa CSV, vengono normalizzati in lista Python.
8. **Generazione metadati AI**: Il testo estratto viene passato ad `ai_service.generate_ai_metadata()` (chiamata `await`-ata) che invoca la chain LangChain e restituisce un oggetto `MetadataIA` popolato.
9. **Creazione del documento**: Viene costruito un oggetto `ArticleDocument` aggregando `id`, `blob_url`, `cover_url`, timestamp UTC, `manual` e `IA_metadata`.
10. **Persistenza su Cosmos DB**: Il documento viene serializzato in JSON tramite `.model_dump(mode='json')` e salvato su Cosmos DB tramite `cosmos_service.save_article_metadata()`.
11. **Chunking e persistenza chunk**: Il testo viene suddiviso tramite `chunking()` e i chunk salvati su Cosmos DB (container `chunks`) tramite `save_chunks_metadata()`.
12. **Embedding e indicizzazione**: Gli embedding dei chunk vengono generati (con `await`) e caricati su Azure AI Search tramite `index_chunk_to_ai_search()`.
13. **Risposta**: L'endpoint restituisce `HTTP 201 Created` con un payload JSON contenente `status`, `message`, `filename`, `blob_url` e `cover_url`.

### 4.5 Generazione Metadati via LLM (LangChain + Azure OpenAI)

La generazione automatica dei metadati rappresenta il nucleo della componente di intelligenza artificiale del sistema e risponde direttamente al requisito di traccia che impone l'"estrazione automatica di metadati descrittivi" dall'articolo caricato. Il modulo responsabile è `app/services/ai_service.py`, il cui funzionamento si articola nelle seguenti fasi.

#### Definizione dello Schema di Output (Pydantic + Structured Output)

Il primo elemento architetturale rilevante è la definizione del modello `MetadataIA` in `app/models/article.py` come schema Pydantic. Tale modello descrive formalmente i sei campi di metadati che il sistema deve estrarre:

| Campo | Tipo | Semantica |
|-------|------|-----------|
| `subtitle` | `str` | Sottotitolo editoriale sintetico dell'articolo |
| `summary` | `str` | Riassunto dei contenuti principali (2-4 frasi) |
| `keywords` | `List[str]` | Parole chiave tematiche estratte dal testo |
| `category` | `List[str]` | Categorie giornalistiche (es. Politica, Economia) |
| `language` | `str` | Lingua rilevata dell'articolo (es. `it`, `en`) |
| `entities` | `List[str]` | Entità nominate: persone, luoghi, organizzazioni (formato `"tipo: nome"`) |

Lo schema Pydantic viene passato al metodo `llm.with_structured_output(MetadataIA)` di LangChain, che utilizza la funzionalità di **function calling** dell'API di Azure OpenAI per vincolare il modello linguistico a produrre un output JSON strettamente conforme allo schema derivato automaticamente da Pydantic. Questo approccio elimina la necessità di parsing manuale dell'output testuale e garantisce che il JSON restituito sia sempre deserializzabile nell'oggetto `MetadataIA`, con validazione automatica dei tipi da parte di Pydantic.

#### Costruzione della Chain LangChain (Prompt → LLM Strutturato)

L'orchestrazione della pipeline di generazione avviene tramite LangChain, secondo il pattern LCEL (LangChain Expression Language), che compone i componenti della chain tramite l'operatore `|`:

```python
ai_metadata_chain = prompt | structured_llm
```

Il `ChatPromptTemplate` definisce due messaggi:
- **System message**: istruisce il modello sul suo ruolo di "assistente editoriale esperto", stabilisce l'obiettivo dell'analisi e vincola il formato della risposta.
- **Human message**: inietta dinamicamente il testo dell'articolo estratto dal parser tramite la variabile `{text_content}`.

La chain viene invocata in modalità asincrona tramite il metodo `ainvoke()`, garantendo la compatibilità con il runtime `asyncio` di FastAPI senza bloccare il thread del server durante l'attesa della risposta da Azure OpenAI.

#### Integrazione nella Pipeline di Upload

Nella pipeline dell'endpoint `POST /articles/upload`, dopo l'estrazione del testo tramite il parser multiformat, il testo grezzo viene passato alla funzione `generate_ai_metadata(text_content)`. Il risultato, un oggetto `MetadataIA` validato da Pydantic, viene inserito nel campo `IA_metadata` dell'`ArticleDocument` e persistito su Cosmos DB insieme ai metadati manuali. Il documento finale su Cosmos DB contiene quindi, per ogni articolo, sia i metadati forniti dall'utente sia quelli generati automaticamente dall'LLM, in un unico documento JSON dalla struttura gerarchica estensibile.

#### Gestione degli Errori

In caso di errore durante l'invocazione del modello (es. timeout, quota esaurita, risposta malformata), la funzione `generate_ai_metadata` solleva una `HTTPException` con codice `503 Service Unavailable` e un messaggio esplicativo. Questa strategia di gestione degli errori è preferibile rispetto al rilancio di un'eccezione generica non gestita, in quanto garantisce che FastAPI restituisca sempre una risposta HTTP con codice e corpo controllati, migliorando la diagnosticabilità del sistema in produzione.

### 4.6 Chunking, Embedding e Indicizzazione Vettoriale

La pipeline di preparazione dei dati per la ricerca semantica si articola in tre fasi sequenziali, orchestrate nell'endpoint di upload dopo la persistenza dei metadati su Cosmos DB.

#### Chunking del testo (`ai_service.chunking`)

Il testo grezzo estratto dal parser viene suddiviso in frammenti (*chunk*) di dimensione controllata tramite il `RecursiveCharacterTextSplitter` di LangChain. I parametri adottati (`chunk_size=500`, `chunk_overlap=50`) garantiscono che ogni chunk sia abbastanza ridotto da essere rappresentato in modo semanticamente coerente da un singolo vettore embedding, e che la sovrapposizione di 50 caratteri tra chunk adiacenti preservi il contesto ai margini di ogni frammento, evitando interruzioni semantiche nette.

#### Generazione degli Embedding (`ai_service.generate_embedding_for_chunks`)

La lista di chunk testuali viene passata alla funzione asincrona `generate_embedding_for_chunks`, che invoca `AzureOpenAIEmbeddings.aembed_documents()` tramite LangChain. Il modello `text-embedding-ada-002` trasforma ogni frammento in un vettore denso a 1536 dimensioni, restituendo una lista parallela di vettori `list[list[float]]` nel medesimo ordine dei chunk in ingresso. Questa proprietà di parallelismo posizionale è fondamentale per la fase successiva.

#### Accoppiamento e Indicizzazione su Azure AI Search (`search_service.index_chunk_to_ai_search`)

La funzione `index_chunk_to_ai_search` riceve le due liste parallele — `chunks: list[str]` e `embedding: list[list[float]]` — e le percorre in modo sincrono tramite `zip(chunks, embedding)` dentro un ciclo `enumerate`. L'uso combinato di `zip` ed `enumerate` garantisce che ad ogni iterazione il testo e il suo vettore corrispondente vengano accoppiati in modo deterministico, e che venga generato un `chunk_id` univoco nella forma `{article_id}-chunk-{index}`. Per ogni coppia viene istanziato un oggetto Pydantic `EmbeddingDocument` e serializzato in dizionario tramite `.model_dump()`, producendo il formato JSON atteso dall'SDK `azure-search-documents`.

L'intera lista di documenti viene caricata su Azure AI Search con una singola chiamata batch a `upload_documents`, minimizzando la latenza di rete. Il client utilizzato è quello **asincrono** (`azure.search.documents.aio.SearchClient`), necessario per la compatibilità con l'event loop di FastAPI: l'uso del client sincrono in un contesto `async def` bloccherebbe il thread del server. Il client viene istanziato e chiuso all'interno di un `async with`, garantendo il rilascio corretto delle risorse HTTP.

In modalità `TEST_MODE=True`, la funzione ritorna immediatamente con un messaggio di log, senza effettuare alcuna chiamata al cloud, coerentemente con il pattern di mock adottato nelle funzioni `generate_ai_metadata` e `generate_embedding_for_chunks`.

| Oggetto Pydantic | Campo | Ruolo in Azure AI Search |
|---|---|---|
| `EmbeddingDocument` | `chunk_id` | Chiave primaria del documento nell'indice |
| `EmbeddingDocument` | `article_id` | Campo di filtro per recuperare tutti i chunk di un articolo |
| `EmbeddingDocument` | `chunk_text` | Campo testo su cui opera la ricerca full-text (BM25) |
| `EmbeddingDocument` | `embedding` | Campo vettore su cui opera la ricerca semantica (HNSW) |

### 4.7 Motore RAG e Risposta Finale (`POST /search/rag`)

L'endpoint `POST /search/rag`, implementato in `app/routers/search.py`, implementa la pipeline RAG completa per la ricerca in linguaggio naturale sull'archivio di articoli.

#### Flusso della pipeline RAG

1. **Embedding della domanda**: La stringa di testo della domanda (`query.question`) viene convertita in un vettore embedding a 1536 dimensioni tramite `generate_embedding_for_chunks([query.question])`. Il risultato è una lista con un singolo vettore, da cui si estrae il primo elemento (`query_embedding[0]`).

2. **Ricerca dei chunk rilevanti** (`search_relevant_chunks`): Il vettore della domanda viene passato a `search_service.search_relevant_chunks()`, che esegue una ricerca vettoriale su Azure AI Search tramite `VectorizedQuery` con `k_nearest_neighbors=3`. La funzione restituisce una lista di dizionari, ognuno contenente `article_id`, `chunk_text` e `score` (punteggio di rilevanza). Se nessun chunk supera la soglia, l'endpoint restituisce una risposta "non trovato" senza invocare il modello linguistico.

3. **Generazione della risposta RAG** (`generate_rag_answer`): I chunk rilevanti vengono assemblati in un unico contesto testuale e passati al modello `gpt-4o-mini` tramite un `ChatPromptTemplate` bipartito (system + human). Il **system message** vincola esplicitamente il modello a rispondere basandosi **esclusivamente** sul contesto fornito, senza accedere a conoscenze esterne, con fallback esplicito in caso di assenza di informazioni pertinenti. La chain `rag_prompt | llm` viene invocata in modo asincrono tramite `ainvoke()`, garantendo la piena compatibilità con il runtime di FastAPI.

4. **Risposta strutturata**: L'endpoint restituisce un payload JSON con tre campi: `question` (domanda originale), `answer` (testo generato dal LLM) e `relevant_chunks` (lista dei chunk sorgente con score e article_id, per tracciabilità delle fonti).

#### Endpoint di ricerca per keyword (`POST /search/generic`)

In parallelo al motore RAG, il sistema espone un endpoint `POST /search/generic` per la ricerca tradizionale per parola chiave. La funzione `cosmos_service.search_by_keywords()` esegue una query Cosmos DB SQL con `CONTAINS()` su cinque campi del documento (`title`, `description`, `category`, `author`, `tags`), con corrispondenza case-insensitive. L'endpoint è concepito per ricerche rapide e filtri informativi, complementari alla ricerca semantica RAG.

### 4.8 Endpoint di Lettura Articoli

#### `GET /articles` — Lista articoli con paginazione e filtri

L'endpoint restituisce una lista paginata di articoli, supportando i seguenti query parameter:

| Parametro | Tipo | Default | Semantica |
|-----------|------|---------|-----------|
| `decreasing` | `bool` | `false` | Ordine cronologico crescente (true) o decrescente (false) |
| `category` | `str` | `None` | Filtro per categoria tematica |
| `skip` | `int` | `0` | Offset per la paginazione (infinite scroll) |
| `limit` | `int` | `10` | Numero massimo di articoli restituiti per pagina |

La funzione `cosmos_service.get_articles_list()` costruisce la query Cosmos DB dinamicamente, aggiungendo la clausola `WHERE` solo se `category` è fornita, e applicando `ORDER BY c.uploaded_at` con la direzione appropriata. La proiezione SQL seleziona solo i campi necessari per la lista (`id`, `title`, `author`, `category`, `blob_url`, `cover_url`, `uploaded_at`), minimizzando il volume di dati trasferiti.

#### `GET /articles/{article_id}` — Dettaglio articolo

L'endpoint restituisce il documento completo di un articolo dato il suo UUID, arricchito con la lista dei chunk testali associati. La funzione `cosmos_service.get_article_by_id()` sfrutta la lettura a punto (`read_item`) di Cosmos DB, operazione a costo O(1) grazie alla chiave di partizione coincidente con `article_id`. I chunk vengono recuperati separatamente da `cosmos_service.get_chunks_by_article_id()` tramite una query sul container `chunks`, ordinata per `chunk_index ASC` per preservare l'ordine sequenziale del documento originale. In caso di `article_id` inesistente, l'endpoint restituisce `HTTP 404 Not Found`.

### 4.9 Autenticazione tramite Keycloak (OIDC/JWT)

Il sistema di autenticazione è implementato nel modulo `autentication/keycloack_service.py`, che espone una dipendenza FastAPI (`get_current_user`) riutilizzabile da qualsiasi endpoint che richieda protezione.

#### Architettura della verifica token

La verifica dei token si basa sullo standard **OpenID Connect (OIDC)** con algoritmo di firma **RS256** (RSA con SHA-256). Il flusso è il seguente:

1. **Estrazione Bearer token**: FastAPI estrae automaticamente il token JWT dall'header `Authorization: Bearer <token>` tramite `HTTPBearer`.
2. **Download delle chiavi pubbliche JWKS**: La funzione `get_keycloak_public_keys()` scarica dinamicamente il **JWKS (JSON Web Key Set)** dall'endpoint pubblico di Keycloak (`/realms/{realm}/protocol/openid-connect/certs`). Questo approccio elimina la necessità di distribuire le chiavi pubbliche staticamente nel backend: Keycloak gestisce la rotazione delle chiavi in modo trasparente.
3. **Verifica crittografica**: La libreria `python-jose` decodifica e verifica il token JWT verificando la firma RSA, la scadenza (`exp`) e l'issuer (`iss`) contro il realm Keycloak configurato.
4. **Restituzione payload**: Se la verifica ha successo, il payload del token (contenente `sub`, `preferred_username`, `roles` e gli altri claim OIDC standard) viene restituito come dizionario Python e iniettato nelle funzioni handler tramite `Depends(get_current_user)`.
5. **Risposta 401**: In caso di token assente, scaduto, alterato o con firma non valida, viene sollevata una `HTTPException 401 Unauthorized` con header `WWW-Authenticate: Bearer`.

L'infrastruttura Keycloak è orchestrata localmente tramite il file `docker-compose.yml` nel modulo `autentication/`, che avvia un'istanza containerizzata del server per lo sviluppo e il test.

### 4.10 Frontend Flutter — Home Page (`main.dart`)

L'implementazione della schermata principale del frontend Flutter costituisce il punto di ingresso dell'applicazione lato utente. Il file `main.dart` è strutturato come un unico `StatefulWidget` (`MyHomePage`) che incapsula l'intero layout della Home Page, predisposto per il collegamento con le API REST del backend.

#### Layout dell'AppBar

L'`AppBar` è organizzata orizzontalmente con quattro elementi funzionali, ordinati da sinistra a destra:

| Posizione | Widget | Funzionalità |
|-----------|--------|--------------|
| Sinistra | `Text` (titolo) | Identità dell'applicazione ("NewsArchive") |
| Centro-sinistra | `DropdownButton<String>` | Filtro per categoria tematica (Politica, Economia, Tecnologia, ecc.) con refresh automatico della lista al cambio selezione |
| Centro-destra | `TextField` con `OutlineInputBorder` circolare | Barra di ricerca testuale con `onSubmitted` predisposto per invocare gli endpoint di ricerca |
| Destra | `Switch` + `IconButton` (menu) | Toggle per alternare modalità di ricerca RAG (`POST /search/rag`) e Normale (`POST /search/generic`); icona hamburger per aprire il Drawer laterale |

#### Drawer di Navigazione (endDrawer)

Il `Drawer`, posizionato a destra (`endDrawer`) e attivato dall'icona hamburger nell'AppBar, espone le seguenti azioni di navigazione tramite `ListTile`:

- **Log-in**: Predisposto per la navigazione verso il flusso di autenticazione Keycloak (OAuth2.0/OIDC).
- **Cronologia articoli**: Accesso alla lista degli articoli visualizzati di recente.
- **Upload articolo**: Navigazione verso la schermata di caricamento (`upload_screen.dart`).
- **Informazioni**: Dialog `showAboutDialog` con dettagli sul sistema e versione.

#### Architettura Infinite Scroll

Il corpo della pagina implementa un pattern di **Infinite Scroll** tramite `GridView.builder` con `ScrollController`. Il meccanismo opera come segue:

1. Un `ScrollController` monitora la posizione di scroll dell'utente.
2. Quando la posizione raggiunge una soglia di 200 pixel dal fondo della lista, viene triggerato il caricamento della pagina successiva.
3. La funzione `_loadArticles()` invoca (in produzione) `GET /articles?skip=N&limit=10&category=...`, accumulando i risultati nella lista locale `_articles`.
4. Un `CircularProgressIndicator` (colori `coloreSecondario`/`colorePrincipale`) viene visualizzato come ultimo elemento della griglia durante il caricamento.
5. Il `RefreshIndicator` (pull-to-refresh) consente il reset completo della lista.

#### Design della Card

Ogni articolo è rappresentato da una `Card` con sfondo bianco, `elevation: 3`, ombra navy e `ClipBehavior.antiAlias`. Il layout verticale comprende:

- **Parte superiore** (flex: 3): Immagine di copertina (`cover_url`) caricata via `Image.network` con `BoxFit.cover`. In assenza di immagine, un placeholder mostra un'icona contestuale alla categoria (es. bilancia per Politica, pallone per Sport) in `coloreSecondario`.
- **Parte inferiore** (flex: 2): Badge di categoria con sfondo `coloreSecondario` trasparente, titolo dell'articolo in `colorePrincipale` (massimo 2 righe, `TextOverflow.ellipsis`) e nome dell'autore con icona persona.
#### Implementazione UI di Autenticazione Animata (Custom Login)
Per garantire un'esperienza utente (UX) fluida e coerente con il design system dell'applicazione, si è scelto di non reindirizzare l'utente alle pagine web predefinite del server Keycloak. È stata invece progettata e implementata un'interfaccia di Login e Registrazione custom, animata nativamente in Flutter (sfruttando i widget Stack, AnimatedPositioned e Transform). Il frontend raccoglie in modo sicuro le credenziali dell'utente e sfrutta il flusso Direct Access Grants (Resource Owner Password Credentials) di OAuth2, comunicando tramite API REST con l'Identity Provider per l'emissione del token JWT. Questa scelta architettonica maschera all'utente la complessità del sistema IAM (Identity and Access Management) sottostante, mantenendolo all'interno dell'ambiente cloud-native senza interruzioni di navigazione.
## 5. Trasparenza IA e Metodologia di Sviluppo

Il progetto è stato condotto secondo una metodologia "Review-driven development", prevedendo un'interazione iterativa con agenti basati su intelligenza artificiale generativa per la definizione architetturale e la generazione del codice sorgente.

### Revisione IaC Bicep, Commenti e README
Per la Componente IaC gestita tramite **Azure Bicep**, L'IA è stata guidata per eseguire le seguenti attività di refactoring e refinement:
1. **Verifica della correttezza sintattica e strutturale:** Revisione dei file `.bicep` per garantire la piena conformità con le specifiche e le API ufficiali di Microsoft Azure.
2. **Arricchimento della documentazione interna:** Inserimento di commenti esplicativi dettagliati all'interno degli script Bicep per rendere chiare le dipendenze tra risorse (es. associazione tra Storage Account, Cosmos DB Serverless e Azure AI Search).
3. **Ottimizzazione delle prestazioni e dei costi:** Validazione delle opzioni di ridondanza (Standard LRS per Blob Storage) e dei tier serverless (per Cosmos DB) per minimizzare il consumo dei crediti del profilo Azure for Students.
4. **Stesura della documentazione operativa:** Generazione del file `README.md` all'interno della cartella `azure/`, contenente le istruzioni dettagliate passo-passo per l'esecuzione dei comandi da Azure CLI (`az deployment group create`).

### Verifica e Configurazione delle Variabili d'Ambiente (.env)
Durante la fase di collegamento tra l'infrastruttura provvisionata su Azure e il backend Python, l'agente IA è stato impiegato per esaminare la mappatura dei parametri di configurazione:
1. **Validazione e sintassi delle chiavi d'infrastruttura:** Verifica e cross-check tra i dati restituiti dai comandi Azure CLI (Connection String di Storage, Primary Key di Cosmos DB, Admin Key di AI Search, API Key di OpenAI, endpoint di servizio) e le variabili d'ambiente esposte dagli SDK Python (`azure-storage-blob`, `azure-cosmos`, `azure-search-documents`, `langchain-openai`). Questo intervento ha prevenuto errori formali nella formattazione delle stringhe di connessione e garantito l'adozione delle convenzioni di naming previste dal backend.
2. **Sicurezza e Gestione dei Segreti:** L'agente ha verificato la presenza delle regole di esclusione all'interno del file `.gitignore` per evitare l'upload accidentale del file `backend/.env` contenente credenziali riservate nella repository remota. Contestualmente, è stato generato il file `backend/.env.example`, privo di informazioni sensibili, come modello di riferimento per il versionamento del codice.



---
### 5.1 Registro delle Interazioni (Log degli Agenti AI)
| Feature / Task | Agente Utilizzato | Prompt Principale Fornito | Sintesi Risposta / Codice Generato |
|---|---|---|---|
 Revisione IaC Bicep, Commenti e README | Claude Sonnet 4.6 | "Agente, verifica la correttezza e l'ottimizzazione dei file Bicep per l'infrastruttura Azure. Aggiungi commenti esplicativi dettagliati all'interno del codice `.bicep` e genera il file `README.md` con le istruzioni per il deploy tramite Azure CLI." | Validazione degli script Bicep con inserimento di commenti esplicativi sulle singole risorse. Generazione del file `README.md` contenente i comandi `az login`, `az group create` e `az deployment` per il provisioning automatico dell'ambiente. |
 Refactoring modulo Bicep OpenAI — conformità region policy italynorth | Claude Sonnet 4.6 | "Adatta la configurazione Bicep per la risorsa Azure OpenAI a causa delle restrizioni della policy della sottoscrizione Azure for Students UniCal (italynorth obbligatorio, regioni esterne bloccate). Il modulo deve creare solo l'account base; i deployment dei modelli vengono gestiti manualmente via Azure AI Studio." | Refactoring di `openai.bicep`: rimossi i blocchi `embeddingDeployment` e `gptDeployment` (lasciati in commento per riferimento); aggiornati `main.bicep` (default `openAiLocation = 'italynorth'`), `parameters.json`, `README.md` (aggiunta sezione deployment manuale con tabella modelli), `implementation_plan.md` (Task 1.5 completato) e `Relazione_Progetto.md` (sezione Azure OpenAI + log). |
 Verifica formattazione e mappatura file .env | Claude Sonnet 4.6 | "Agente, ho completato il deploy Bicep ed eseguito i comandi Azure CLI. Genera o aggiorna il file backend/.env e backend/.env.example, mappando le variabili d'ambiente necessarie per il backend Python secondo la struttura esposta da Bicep (Storage, Cosmos, Search, OpenAI, ACR) e verificando il .gitignore." | Controllata e validata la sintassi delle variabili d'ambiente. Verificata la corrispondenza con i client del backend Python e generato il file .env.example privo di credenziali segrete per il commit su Git. |
 Code Review e Task 2.4 — Generazione metadati AI (LangChain + Azure OpenAI) | Claude Sonnet 4.6 | "Esegui code review architetturale e funzionale del Task 2.4. Verifica l'integrazione con AzureChatOpenAI e LangChain, l'uso di Pydantic per output JSON strutturato, la gestione degli errori e i conflitti con il runtime asincrono di FastAPI. Aggiorna implementation_plan.md e scrivi la sezione 4.5 della relazione." | Identificati e corretti 3 bug: (1) `await` mancante su `generate_ai_metadata()` in `articles.py` (coroutine mai eseguita); (2) nome variabile errato `AZURE_OPENAI_API_KEY` → `AZURE_OPENAI_KEY` in `ai_service.py`; (3) deployment hardcoded `"gpt-4.1-mini"` sostituito con `settings.AZURE_OPENAI_CHAT_DEPLOYMENT`. Migliorata gestione errori con `HTTPException 503`.|
 Code Review Task 2.6 — Indicizzazione vettoriale su Azure AI Search (`search_service.py`) | Claude Sonnet 4.6 | "Esegui la code review della funzione `index_chunk_to_ai_search`. Verifica l'uso corretto di `zip()` ed `enumerate()`, la serializzazione Pydantic con `model_dump()`, la gestione asincrona del client Search e la presenza del blocco TEST_MODE. Aggiorna la sezione 4.6 della relazione." | **Codice scritto interamente dallo studente.** L'IA è stata utilizzata esclusivamente come strumento di code review e validazione. Identificati e corretti 4 bug: (1) import errato `azure.search.documents.SearchClient` (sincrono) → `azure.search.documents.aio.SearchClient` (asincrono); uso del client sincrono con `await` e `async with` genera `TypeError` a runtime bloccando l'event loop di FastAPI; (2) chiave di configurazione inesistente `settings.AZURE_SEARCH_KEY` → `settings.AZURE_SEARCH_ADMIN_KEY` (nome corretto in `config.py`); (3) assenza del blocco `TEST_MODE` presente invece in tutti gli altri servizi; (4) rientro del codice errato (indentazione a doppio livello della funzione). |
| Scelta del protocollo di sicurezza | Gemini 1.5 Pro | "Ragiona come un Software Engineer professionista e valuta quale approccio per gestire l'autenticazione di un utente si adegua al mio progetto tra JWT e MSAL." | Analisi comparativa tra MSAL (Azure Entra ID B2C) e JWT custom. Stesura del documento di decisione architetturale (ADR) con scelta motivata verso JWT tramite FastAPI e Cosmos DB per dimostrare competenze backend, mantenere coesione dei dati ed evitare over-engineering infrastrutturale. |
| Implementazione Keycloak e Autenticazione | Gemini 1.5 Pro | "Ragiona come un web Security expert professionista e implementa i servizi di keycloack inoltre effettua una core rewie sull'aggiunta dell'upload dei file con immagini" | Code review funzionale per l'integrazione dell'upload delle copertine (`cover_url`) su Blob Storage e fix dei deadlock asincroni. Check architetturale di Keycloak come Identity Provider su infrastruttura Azure, abbandonando l'approccio Custom JWT per rispettare la best practice "Don't roll your own crypto" aggirando i limiti della sottoscrizione studentesca e implementazione delle funzioni get_current_user e get_keycloak_public_key nel file keycloak_service.py . |
| Generazione e Refinement UI Home Page Flutter (Task 4.1) | Claude Opus 4.6 | \"Agisci come Senior Flutter Developer. Implementa la UI della Home Page in `main.dart` seguendo il wireframe: AppBar con titolo, dropdown filtri, barra di ricerca e switch RAG/Normal; Drawer laterale destro con Login, Cronologia, Upload e Info; body con Infinite Scroll su GridView.builder di Card (cover_url, titolo, autore). Definisci `colorePrincipale` e `coloreSecondario` globali, raggruppa i controlli dell'AppBar in un Container unico con sfondo secondario e bordi arrotondati, applica elevation all'AppBar.\" | Implementazione iterativa del file `main.dart`: (1) generazione iniziale della struttura completa (AppBar, endDrawer, GridView.builder con Infinite Scroll e Card); (2) refactoring AppBar: controlli centrati, barra di ricerca allargata; (3) introduzione sistema colori globale (`colorePrincipale = #1B1B1B`, `coloreSecondario = #9B111E`) con `ThemeData` configurato, `AppBar` con `elevation: 6`, controlli raggruppati in `Container` pill-shaped con sfondo `coloreSecondario` e separatori verticali, label switch posizionata a destra; (4) estensione coerenza cromatica a tutto il body (Card, Drawer, loading indicators, empty state, placeholder). Dati mock predisposti per sostituzione con chiamate HTTP a `GET /articles` e `POST /search/rag`. |

| Implementazione UI Login Animata (Frontend) | Gemini 1.5 Pro | \"Ho trovato sul web una schermata di login animata. Riusciresti ad adattarla al mio codice Flutter per non usare la schermata preimpostata di Keycloak che risulta scarna?\" | Trasposizione di un'animazione complessa basata su offset (HTML/CSS) in widget Flutter nativi. Adattamento dell'interfaccia al design system custom e risoluzione dei bug di overlay (z-index) nei field di testo. Preparazione del form per l'integrazione API Direct Access Grants verso Keycloak. |

## 6. Conclusioni e Sviluppi Futuri
*(Da completare a fine progetto)*
