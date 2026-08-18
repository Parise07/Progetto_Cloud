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

