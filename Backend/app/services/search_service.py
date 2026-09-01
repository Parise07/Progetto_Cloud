from azure.core.credentials import AzureKeyCredential
from azure.core.exceptions import ResourceExistsError
from azure.search.documents.aio import SearchClient
from azure.search.documents.indexes.aio import SearchIndexClient

from app.config import settings
from app.models.article import EmbeddingDocument
from fastapi import HTTPException
from azure.search.documents.models import VectorizedQuery

#aggiunto con Ia per seguire best practice
from azure.search.documents.indexes.models import (
    SearchIndex,
    SimpleField,
    SearchableField,
    SearchField,
    SearchFieldDataType,
    VectorSearch,
    HnswAlgorithmConfiguration,
    VectorSearchProfile,
)



#generata con Ia generativa
async def setup_ai_search_index():
    """
    Controlla se l'indice vettoriale esiste su Azure AI Search.
    Se non esiste, lo crea in automatico con i campi corretti.
    """
    if settings.TEST_MODE:
        print("🛠️ MOCK MODE: Creazione automatica indice AI Search saltata.")
        return

    # Attenzione: Usiamo SearchIndexClient (per gestire la struttura), non SearchClient
    index_client = SearchIndexClient(
        endpoint=settings.AZURE_SEARCH_ENDPOINT,
        credential=AzureKeyCredential(settings.AZURE_SEARCH_ADMIN_KEY)
    )

    name = settings.AZURE_SEARCH_INDEX_NAME

    # 1. Definiamo i campi del nostro database vettoriale
    fields = [
        SimpleField(name="chunk_id", type=SearchFieldDataType.String, key=True),
        SimpleField(name="article_id", type=SearchFieldDataType.String, filterable=True),
        SearchField(name="chunk_text", type=SearchFieldDataType.String, searchable=True),
        SearchField(
            name="embedding",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=1536,
            vector_search_profile_name="news-vector-profile"
        )
    ]

    # 2. Configuriamo l'algoritmo HNSW per la ricerca vettoriale
    vector_search = VectorSearch(
        algorithms=[
            HnswAlgorithmConfiguration(name="news-hnsw-config")
        ],
        profiles=[
            VectorSearchProfile(
                name="news-vector-profile",
                algorithm_configuration_name="news-hnsw-config",
            )
        ]
    )

    # 3. Assembliamo l'indice
    index = SearchIndex(name=name, fields=fields, vector_search=vector_search)

    # 4. Tentiamo la creazione
    try:
        async with index_client:
            await index_client.create_index(index)
            print(f"✅ SETUP: Indice '{name}' creato con successo su Azure AI Search!")
    except ResourceExistsError:
        print(f"⚡ SETUP: L'indice '{name}' esiste già. Nessuna azione necessaria.")
    except Exception as e:
        print(f"❌ SETUP: Errore durante la creazione dell'indice: {e}")


async def index_chunk_to_ai_search(article_id: str, chunks: list[str], embedding: list[list[float]]):
        
    if settings.TEST_MODE:
        print(f" MOCK MODE: Indicizzazione simulata per article_id={article_id} ({len(chunks)} chunks). Zero crediti consumati.")
        return
    else:
        search_client = SearchClient(
            endpoint=settings.AZURE_SEARCH_ENDPOINT,
            index_name=settings.AZURE_SEARCH_INDEX_NAME,
            credential=AzureKeyCredential(settings.AZURE_SEARCH_ADMIN_KEY)
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
    local_search_client = SearchClient(
        endpoint=settings.AZURE_SEARCH_ENDPOINT,
        index_name=settings.AZURE_SEARCH_INDEX_NAME,
        credential=AzureKeyCredential(settings.AZURE_SEARCH_ADMIN_KEY)
    )
    try:
        async with local_search_client:
            # Eseguiamo la ricerca
            results = await local_search_client.search(
                search_text=None,
                vector_queries=[vector_query],
                top=1
            )
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
    ''' Dato un vettore Question trova e restituisce i top_k chunk più simili  '''
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
    local_search_client = SearchClient(
            endpoint=settings.AZURE_SEARCH_ENDPOINT,
            index_name=settings.AZURE_SEARCH_INDEX_NAME,
            credential=AzureKeyCredential(settings.AZURE_SEARCH_ADMIN_KEY)
        )
    try:
        async with local_search_client:
            results = await local_search_client.search(
                search_text=None,
                vector_queries=[vector_query],
                top=top_k
            )

            # Leggiamo il punteggio del risultato migliore
            async for result in results:
                result_list.append(
                    {
                        "article_id": result.get("article_id"),
                        "chunk_text": result.get("chunk_text"),
                        "score" : result.get("@search.score", 0)
                    }
                )
        return result_list
    except Exception as e:
        print(f"Errore durante la ricerca in AI Search: {e}")
        return []


async def delete_article_chunk(article_id: str, chunk_count: int):
    """dato un article id e il numero di chunk elimina tutti i vettori chunk
     dell'articolo """
    if settings.TEST_MODE:
        print(f"🛠️ MOCK MODE: Vettori dell'articolo {article_id} eliminati.")
        return
    documents_to_delete = [{"chunk_id": f"{article_id}-chunk-{i}"} for i in range(chunk_count)]

    if not documents_to_delete:
        return

    local_search_client = SearchClient(
        endpoint=settings.AZURE_SEARCH_ENDPOINT,
        index_name=settings.AZURE_SEARCH_INDEX_NAME,
        credential=AzureKeyCredential(settings.AZURE_SEARCH_ADMIN_KEY)
    )
    try:
        async with local_search_client:
            await local_search_client.delete_documents(documents=documents_to_delete)
    except Exception as e:
        print(f"Errore eliminazione vettori AI Search: {e}")