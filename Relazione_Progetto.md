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
│   │   └── article.py        # Modelli Pydantic: ManualMetadata, ArticleDocument
│   ├── routers/
│   │   └── articles.py       # Endpoint POST /articles/upload
│   └── services/
│       ├── blob_service.py        # Upload su Azure Blob Storage (client asincrono)
│       ├── cosmos_service.py      # Salvataggio metadati su Cosmos DB
│       └── ingestion_service.py   # Parser multiformat (TXT/MD/JSON/DOCX/PDF)
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
3. **Upload su Azure Blob Storage**: Il contenuto binario del file viene caricato nel container `articles-raw` tramite `blob_service.uploaded_file_to_blob()`. L'operazione è `await`-ata, sfruttando il client asincrono.
4. **Estrazione testo**: Il contenuto binario viene passato a `ingestion_service.extract_text_from_file()` per ottenere la stringa di testo grezzo su cui operano le pipeline AI successive.
5. **Costruzione dei metadati manuali**: I campi del form (`title`, `author`, `category`, `description`, `tags`) vengono istanziati in un oggetto `ManualMetadata`. I tag, ricevuti come stringa CSV, vengono normalizzati in lista Python.
6. **Generazione metadati AI**: Il testo estratto viene passato ad `ai_service.generate_ai_metadata()` (chiamata `await`-ata) che invoca la chain LangChain e restituisce un oggetto `MetadataIA` popolato.
7. **Creazione del documento**: Viene costruito un oggetto `ArticleDocument` aggregando `id`, `blob_url`, timestamp UTC, `manual_metadata` e `IA_metadata`.
8. **Persistenza su Cosmos DB**: Il documento viene serializzato in JSON tramite `.model_dump(mode='json')` e salvato su Cosmos DB tramite `cosmos_service.save_article_metadata()`.
9. **Risposta**: L'endpoint restituisce `HTTP 201 Created` con un payload JSON contenente `status`, `message`, `filename` e `blob_url`.

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

### 4.6 Chunking ed Embedding
*(Da completare in seguito)*

### 4.7 Motore RAG e risposta finale
*(Da completare in seguito)*

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



## 6. Conclusioni e Sviluppi Futuri
*(Da completare a fine progetto)*
