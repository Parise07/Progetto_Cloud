from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import AzureChatOpenAI, AzureOpenAIEmbeddings
from fastapi import HTTPException
from langchain_text_splitters import RecursiveCharacterTextSplitter
from app.config import settings
from app.models.article import MetadataIA


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
        "Il tuo compito è analizzare articoli giornalistici ed estrarre informazioni chiave. "
        "Estrai sempre il riassunto, le parole chiave, un sottotitolo appropriato, "
        "le entità rilevanti (persone, luoghi, organizzazioni), la lingua e le categorie. "
        "Rispondi esclusivamente nel formato strutturato richiesto."
    ),
    (
        "human",
        "Analizza il seguente testo ed estrai i metadati richiesti:\n\n{text_content}"
    )
])

ai_metadata_chain = prompt | structured_llm

async def generate_ai_metadata(text_content: str) -> MetadataIA:
    if settings.TEST_MODE:
        print("🛠️ MOCK MODE: Metadati finti (Zero Crediti Consumati)")
        return MetadataIA(
            summary="Riassunto di test generato in locale.",
            subtitle="Sottotitolo locale",
            keywords=["test", "locale", "mock"],
            suggested_categories=["Tecnologia"],
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

#TODO verificare chuncking

def chunking(text_content: str) -> list[str]:
    text_splitter= RecursiveCharacterTextSplitter(
        chunk_size=500,
        chunk_overlap= 50,
    )
    #divido il test
    chunks = text_splitter.split_text(text_content)
    return chunks

async def generate_embedding_for_chunks(chunks: list[str])-> list[list[float]]:
    if settings.TEST_MODE:
        print("🛠️ MOCK MODE: Embeddings finti generati.")
        return [[0.0] * 1536 for _ in chunks]
    try:
        embeddings = await ai_embedding.aembed_documents(chunks)
        return embeddings
    except Exception as e:
        # 3. Aggiunta la protezione degli errori come fatto per i metadati
        raise HTTPException(
            status_code=503,
            detail=f"Errore durante la generazione degli embeddings (Azure OpenAI): {str(e)}"
        )

async def generate_rag_aswer(relevant_chunks : list[dict], question: str) -> str:
        '''Prende la domanda dell'utente e i chunk recuperati  e costruisce un prompt
        per poter chiedere a Azure Openai di generare una risposta '''
        if settings.TEST_MODE:
            print("🛠️ MOCK MODE: Generazione risposta Rag")
            return "Questa è una risposta generata in automatico e di prova"

        context_text=[]
        for chunk in relevant_chunks:
            testo = chunk.get("testo","")
            art_id = chunk.get("art_id","Sconosciuto")
            context_text.append(f"--- Documento ID: {art_id} ---\n{testo}")
        full_text = "\n\n".join(context_text)

        rag_prompt = ChatPromptTemplate.from_messages(
            [
                (
                    "system",
                    "Sei un assistente virtuale per un archivio di notizie giornalistiche. "
                    "Il tuo compito è rispondere alle domande degli utenti basandoti ESCLUSIVAMENTE sulle informazioni "
                    "fornite nel CONTESTO qui sotto. Non inventare informazioni, non usare conoscenze esterne. "
                    "Se la risposta non è presente nel contesto, rispondi: 'Mi dispiace, non ho trovato informazioni sufficienti nei documenti in archivio.'\n\n"
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
             "question": question
            })
            return response.content
        except Exception as e:
            print("Errore durante la generazione della risposta RAG ")
            raise HTTPException(
                status_code=503,
                detail= f"Errore di comunicazione con Azure OpenAI: {str(e)}"
            )