from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import AzureChatOpenAI
from fastapi import HTTPException

from app.config import settings
from app.models.article import MetadataIA

# Bug fix #1: AZURE_OPENAI_KEY (non AZURE_OPENAI_API_KEY) — allineato a config.py
# Bug fix #2: deployment letto da settings.AZURE_OPENAI_CHAT_DEPLOYMENT (non hardcoded)
llm = AzureChatOpenAI(
    azure_deployment=settings.AZURE_OPENAI_CHAT_DEPLOYMENT,
    api_version=settings.AZURE_OPENAI_API_VERSION,
    azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
    api_key=settings.AZURE_OPENAI_KEY,
    temperature=0.2,
    max_retries=2
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
    try:
        result: MetadataIA = await ai_metadata_chain.ainvoke({"text_content": text_content})
        return result
    except Exception as e:
       
        raise HTTPException(
            status_code=503,
            detail=f"Errore durante la generazione dei metadati AI (Azure OpenAI): {str(e)}"
        )