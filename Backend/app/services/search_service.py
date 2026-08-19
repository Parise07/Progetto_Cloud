from azure.core.credentials import AzureKeyCredential
from azure.search.documents.aio import SearchClient  
from app.config import settings
from app.models.article import EmbeddingDocument
from fastapi import HTTPException
from azure.search.documents.models import VectorizedQuery

search_client = SearchClient(
        endpoint=settings.AZURE_SEARCH_ENDPOINT,
        index_name=settings.AZURE_SEARCH_INDEX_NAME,
        credential=AzureKeyCredential(settings.AZURE_SEARCH_ADMIN_KEY)
    )

async def index_chunk_to_ai_search(article_id: str, chunks: list[str], embedding: list[list[float]]):
        
    if settings.TEST_MODE:
        print(f"🛠️ MOCK MODE: Indicizzazione simulata per article_id={article_id} ({len(chunks)} chunks). Zero crediti consumati.")
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

async def check_similarity(vector: list[float], threshold: float = 0.90) -> bool :
    if settings.TEST_MODE:
        print("🛠️ MOCK MODE: Controllo similarità vettoriale saltato.")
        return False


    vector_query = VectorizedQuery(
        vector= vector,
        k_nearest_neighbors=1,
        fields="embedding"
    )
    try:
        async with search_client:
            # Eseguiamo la ricerca
            results = await search_client.search(
                search_text=None,
                vector_queries=[vector_query],
                top=1
            )

            # Leggiamo il punteggio del risultato migliore
            async for result in results:
                score = result.get("@search.score", 0)
                print(f" Punteggio di similarità rilevato: {score}")


                if score >= threshold:
                    return True

            return False

    except Exception as e:
        print(f"Errore durante il controllo di similarità: {e}")
        return False


async def search_relevant_chunks(question: list[float], top_k: int = 3) ->list[dict]:
    ''' trova i top_k chunck più vicini al vettore question '''
    if settings.TEST_MODE:
        print("🛠️ MOCK MODE: ricerca finta eseguita ")
        return [
            {
                "article_id": "test-1234",
                "chunk_text": "questo è un testo di prova",
                "score" : 0.99
            }
        ]
    vector_query = VectorizedQuery(
        vector= question,
        k_nearest_neighbors=top_k,
        fields="embedding"
    )
    result_list = []
    try:
        async with search_client:
            # Eseguiamo la ricerca
            results = await search_client.search(
                search_text=None,
                vector_queries=[vector_query],
                top=top_k
            )

            # Leggiamo il punteggio del risultato migliore
            async for result in results:
                result_list.append(
                    {
                        "article_id": result.get("article_id"),
                        "chunk_text": result.get("text"),
                        "score" : result.get("@search.score", 0)
                    }
                )
        return result_list
    except Exception as e:
        print(f"Errore durante la ricerca in AI Search: {e}")
        return []
