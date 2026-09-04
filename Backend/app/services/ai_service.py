from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import AzureChatOpenAI, AzureOpenAIEmbeddings
from fastapi import HTTPException
from langchain_text_splitters import RecursiveCharacterTextSplitter
from app.config import settings
from app.models.article import MetadataIA
from app.services.cosmos_service import get_titles_by_ids


llm = AzureChatOpenAI(
    azure_deployment=settings.AZURE_OPENAI_CHAT_DEPLOYMENT,
    api_version=settings.AZURE_OPENAI_API_VERSION,
    azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
    api_key=settings.AZURE_OPENAI_KEY,
    temperature=0.2,
    max_retries=2
)
ai_embedding= AzureOpenAIEmbeddings(
    azure_deployment=settings.AZURE_OPENAI_EMBEDDING_DEPLOYMENT,
    api_version=settings.AZURE_OPENAI_API_VERSION,
    azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
    api_key=settings.AZURE_OPENAI_KEY,
)
structured_llm = llm.with_structured_output(MetadataIA)
prompt = ChatPromptTemplate.from_messages([
    (
        "system",
        "Sei un assistente editoriale esperto in analisi testuale e NLP. "
        "Il tuo compito è analizzare articoli giornalistici ed estrarre informazioni chiave in modo oggettivo e fedele al testo originale.\n\n"
        "REGOLE DI ESTRAZIONE:\n"
        "- RIASSUNTO: genera un riassunto di almeno 3-4 frasi corpose, basato ESCLUSIVAMENTE sui fatti presenti nel testo. "
        "Non aggiungere interpretazioni, opinioni o informazioni non presenti nell'articolo.\n"
        "- SOTTOTITOLO: genera un sottotitolo descrittivo e accattivante, ma NON sensazionalistico o fuorviante rispetto al contenuto reale (no clickbait).\n"
        "- KEYWORDS: estrai parole chiave rilevanti e distinte tra loro, evitando sinonimi ridondanti.\n"
        "- ENTITÀ: estrai solo entità esplicitamente nominate nel testo (persone, luoghi, organizzazioni), specificandone il tipo. Non inferire entità non citate.\n"
        #"- CATEGORIE: suggerisci solo categorie coerenti con il contenuto effettivo, evitando categorie generiche se non pertinenti.\n"
        "- LINGUA: rileva la lingua originale del testo, non tradurre.\n"
        "- Se il testo fornito è troppo breve o ambiguo per un'estrazione affidabile, genera comunque i campi ma mantieni "
        "riassunto e sottotitolo aderenti a ciò che è effettivamente presente, senza inventare dettagli mancanti."
    ),
    (
        "human",
        "Analizza il seguente testo ed estrai i metadati richiesti:\n\n{text_content}"
    )
])

ai_metadata_chain = prompt | structured_llm

async def generate_ai_metadata(text_content: str) -> MetadataIA:
    """
        Funzione asincrona che analizza il testo di un articolo tramite Azure OpenAI
        per estrarre metadati strutturati (riassunto, sottotitolo, keywords, entità, lingua).
        In modalità TEST_MODE, restituisce un oggetto fittizio per non consumare crediti.
        :param text_content: Stringa contenente il testo completo dell'articolo da analizzare.
        :return MetadataIA: Modello Pydantic contenente i metadati estratti strutturati.
        """
    if settings.TEST_MODE:
        print("🛠️ MOCK MODE: Metadati finti (Zero Crediti Consumati)")
        return MetadataIA(
            summary="Riassunto di test generato in locale.",
            subtitle="Sottotitolo locale",
            keywords=["test", "locale", "mock"],
            category=["Tecnologia"],
            language="it",
            entities=["persona: Utente Locale"]
        )
    try:
        result: MetadataIA = await ai_metadata_chain.ainvoke({"text_content": text_content})
        return result
    except Exception as e:
       
        raise HTTPException(
            status_code=503,
            detail=f"Errore durante la generazione dei metadati AI (Azure OpenAI): {str(e)}"
        )


def chunking(text_content: str) -> list[str]:
    """
        Funzione che suddivide un testo lungo in frammenti (chunk) più piccoli,
        ottimizzati per l'indicizzazione vettoriale. Utilizza un RecursiveCharacterTextSplitter
        con dimensione massima di 500 caratteri e un overlap di 50 caratteri per mantenere il contesto.
        :param text_content: Stringa contenente il testo intero da suddividere.
        :return list[str]: Lista di stringhe in cui ogni elemento è un frammento (chunk) del testo originale.
    """
    text_splitter= RecursiveCharacterTextSplitter(
        chunk_size=500,
        chunk_overlap= 50,
    )
    chunks = text_splitter.split_text(text_content)
    return chunks

async def generate_embedding_for_chunks(chunks: list[str])-> list[list[float]]:
    '''
        Funzione asincrona che converte una lista di frammenti di testo nei rispettivi
        vettori di embedding numerici sfruttando il modello di Azure OpenAI.
        In modalità TEST_MODE, restituisce vettori composti da zeri.
        :param chunks: Lista di stringhe (i frammenti di testo dell'articolo).
        :return list[list[float]]: Lista di vettori di float, dove ogni vettore rappresenta l'embedding di un chunk.
        '''
    if settings.TEST_MODE:
        print("🛠️ MOCK MODE: Embeddings finti generati.")
        return [[0.0] * 1536 for _ in chunks]
    try:
        embeddings = await ai_embedding.aembed_documents(chunks)
        return embeddings
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"Errore durante la generazione degli embeddings (Azure OpenAI): {str(e)}"
        )

def _componi_contesto(relevant_chunks: list[dict]) -> str:
    '''
    Compone il contesto per l'LLM identificando ogni frammento con il titolo
    dell'articolo di provenienza invece che con il suo UUID crittografico.
    Gli UUID occupano token inutili e degradano l'attenzione del modello.
    Risolvendoli nei titoli editoriali reali (tramite Cosmos DB), il modello
    può citare le fonti in modo naturale e discorsivo.
    :param relevant_chunks: Lista di dizionari che rappresentano i frammenti restituiti da Azure AI Search.
    :return str: Il contesto testuale formattato e pronto per essere inserito nel prompt dell'LLM.
    '''
    titoli = get_titles_by_ids([c.get("article_id") for c in relevant_chunks])

    blocchi = []
    for chunk in relevant_chunks:
        testo = chunk.get("chunk_text", "")
        if not testo:
            continue
        art_id = chunk.get("article_id", "")
        # Se il titolo non è recuperabile si ripiega sull'id, per non perdere
        # comunque il riferimento alla fonte.
        fonte = titoli.get(art_id) or art_id or "Sconosciuto"
        blocchi.append(f'--- Documento: "{fonte}" ---\n{testo}')
    return "\n\n".join(blocchi)


async def generate_rag_answer(relevant_chunks : list[dict], question: str) -> str:
        '''
    Prende la domanda dell'utente e i frammenti pertinenti recuperati dalla ricerca
    vettoriale, compone il contesto e costruisce un prompt strutturato per far generare
    ad Azure OpenAI una risposta chiara, oggettiva e basata unicamente sui documenti forniti.

    :param relevant_chunks: Lista di frammenti testuali estratti come risultato della query vettoriale.
    :param question: Stringa che rappresenta la domanda posta dall'utente.
    :return str: La risposta testuale generata dall'LLM.
    '''
        if settings.TEST_MODE:
            print("🛠️ MOCK MODE: Generazione risposta Rag")
            return "Questa è una risposta generata in automatico e di prova"

        full_text = _componi_contesto(relevant_chunks)

        rag_prompt = ChatPromptTemplate.from_messages(
            [
                (
                    "system",
                    "Sei un assistente virtuale per un archivio di notizie giornalistiche.\n\n"
                    "REGOLE FONDAMENTALI:\n"
                    "1. Rispondi ESCLUSIVAMENTE basandoti sulle informazioni presenti nel CONTESTO qui sotto. "
                    "Non usare conoscenze esterne, non inventare fatti, nomi, numeri o eventi non presenti nel contesto.\n"
                    "2. Se la risposta non è presente o è insufficiente nel contesto, rispondi esattamente: "
                    "'Mi dispiace, non ho trovato informazioni sufficienti nei documenti in archivio.'\n"
                    "3. Quando usi un'informazione, indica da quale articolo proviene citandone il titolo tra virgolette, "
                    "ad esempio: (Fonte: \"Titolo dell'articolo\").\n"
                    "4. Se due documenti nel contesto si contraddicono su uno stesso fatto, segnalalo esplicitamente citando entrambe le fonti, invece di sceglierne una arbitrariamente.\n"
                    "5. Se nel contesto sono presenti più articoli sullo stesso argomento con date diverse, dai priorità alle informazioni più recenti, specificandolo se rilevante.\n"
                    "6. Mantieni un tono giornalistico neutro e oggettivo. Rispondi in modo sintetico (max 4-5 frasi) a meno che la domanda non richieda esplicitamente maggiore dettaglio.\n"
                    "7. Rispondi sempre nella stessa lingua della domanda dell'utente.\n\n"
                    "CONTESTO:\n{context}"
                ),
                (
                    "human",
                    "Domanda dell'utente: {question}"
                )
            ])

        rag_chain = rag_prompt | llm
        try:
            response= await rag_chain.ainvoke({
             "context" : full_text,
             "question": question,
            })
            return response.content
        except Exception as e:
            print("Errore durante la generazione della risposta RAG ")
            raise HTTPException(
                status_code=503,
                detail= f"Errore di comunicazione con Azure OpenAI: {str(e)}"
            )

async def generate_chat_answer(relevant_chunks : list[dict], question: str, current_article_id: str)->str:
    """
        Funzione per una chat contestuale (ad esempio mentre l'utente legge un articolo specifico).
        Fornisce all'agente maggiore libertà per rispondere prioritariamente usando i dati
        dell'articolo corrente, esplorando l'archivio globale solo per trovare argomenti
        simili o correlati in altri documenti, se esplicitamente richiesto.

        :param relevant_chunks: Lista di frammenti testuali pertinenti estratti dall'intero archivio.
        :param question: Stringa che rappresenta la domanda dell'utente.
        :param current_article_id: L'ID dell'articolo che l'utente sta attualmente visualizzando.
        :return str: La risposta conversazionale generata dall'LLM.
        """
    if settings.TEST_MODE:
        return "MOCK MODE: risposta di test generata automaticamente"
    full_text = _componi_contesto(relevant_chunks)
    # Anche l'articolo attualmente in lettura viene indicato per titolo.
    titolo_corrente = get_titles_by_ids([current_article_id]).get(
        current_article_id, current_article_id)
    prompt = ChatPromptTemplate.from_messages([
    (
        "system",
        "Sei un assistente editoriale intelligente. L'utente sta attualmente leggendo l'articolo intitolato: \"{titolo_corrente}\".\n\n"
        "Ho cercato nell'intero archivio e ho trovato questi frammenti correlati:\n\n"
        "CONTESTO GLOBALE:\n{context}\n\n"
        "REGOLE DI RISPOSTA:\n"
        "1. Rispondi basandoti ESCLUSIVAMENTE sulle informazioni presenti nel CONTESTO GLOBALE. Non inventare fatti, nomi, numeri o eventi non presenti nei frammenti.\n"
        "2. Se l'utente chiede spiegazioni sull'articolo in lettura, usa prioritariamente i frammenti del documento \"{titolo_corrente}\".\n"
        "3. Se l'utente chiede di articoli simili o cosa altro c'è in archivio sul tema, guarda i frammenti di documenti DIVERSI da \"{titolo_corrente}\". "
        "Se e SOLO SE ne trovi di realmente pertinenti alla domanda, rispondi con entusiasmo indicando il Titolo del documento e un breve riassunto fedele al contenuto.\n"
        "4. Se nel CONTESTO GLOBALE non ci sono informazioni pertinenti alla domanda (né nell'articolo corrente né altrove), dillo chiaramente: "
        "'Mi dispiace, non ho trovato informazioni pertinenti nell'archivio.' Non forzare una risposta positiva se il contesto non la supporta davvero.\n"
        "5. Cita sempre il titolo del documento quando riporti un'informazione specifica.\n"
        "6. Rispondi nella stessa lingua della domanda dell'utente."
    ),
    (
        "human",
        "Domanda dell'utente: {question}"
    )
    ])
    rag_chain = prompt | llm
    try:
        response = await rag_chain.ainvoke({
            "context": full_text,
            "question": question,
            "titolo_corrente": titolo_corrente
        })
        return response.content
    except Exception as e:
        print("Errore durante la chat contestuale")
        raise HTTPException(status_code=503, detail=str(e))
