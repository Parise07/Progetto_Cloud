from azure.core.credentials import AzureKeyCredential
from azure.search.documents.aio import SearchClient  
from app.config import settings
from app.models.article import EmbeddingDocument
from fastapi import HTTPException


async def index_chunk_to_ai_search(article_id: str, chunks: list[str], embedding: list[list[float]]):
        
    if settings.TEST_MODE:
        print(f"MOCK MODE: Indicizzazione simulata per article_id={article_id} ({len(chunks)} chunks). Zero crediti consumati.")
        return
    else:
        search_client = SearchClient(
            endpoint=settings.AZURE_SEARCH_ENDPOINT,
            index_name=settings.AZURE_SEARCH_INDEX_NAME,
            credential=AzureKeyCredential(settings.AZURE_SEARCH_KEY)
        )

    documents_to_upload = []
    for index, (text, emb) in enumerate(zip(chunks, embedding)):
        doc_model = EmbeddingDocument(
            chunk_id=f"{article_id}-chunk-{index}",
            article_id=article_id,
            chunk_text=text,
            embedding=emb
        )
        documents_to_upload.append(doc_model.model_dump())

    
    try:
        async with search_client:
            await search_client.upload_documents(documents=documents_to_upload)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante l'indicizzazione su Azure AI Search: {str(e)}"
        )