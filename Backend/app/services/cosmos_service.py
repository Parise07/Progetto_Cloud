from azure.cosmos.exceptions import CosmosHttpResponseError
from fastapi import HTTPException
from app.config import settings
from app.azure_clients import cosmos_client
database = cosmos_client.get_database_client(settings.COSMOS_DATABASE_NAME)
articles_container = database.get_container_client(settings.COSMOS_ARTICLES_CONTAINER)
chunks_container = database.get_container_client(settings.COSMOS_CHUNKS_CONTAINER)

def save_chunks_metadata(article_id: str, chunks: list[str]):
    try:
        # Usiamo enumerate per avere sia l'indice (0, 1, 2...) che il testo del chunk
        for index, text in enumerate(chunks):
            chunk_document = {
                "chunk_id": f"{article_id}-chunk-{index}",  # ID univoco del chunk
                "article_id": article_id,  # Riferimento all'articolo padre
                "chunk_index": index,  # Posizione del frammento
                "text": text  # Il testo effettivo
            }
            # Salva il singolo chunk nel contenitore dedicato
            chunks_container.create_item(body=chunk_document)

    except CosmosHttpResponseError as e:
        print(f"Errore durante il salvataggio dei chunk su Cosmos DB: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante il salvataggio dei chunk su Cosmos DB: {str(e)}"
        )

def save_article_metadata(manual_data: dict) -> dict:
    try:
        created_item= articles_container.create_item(body=manual_data)
        return created_item
    except CosmosHttpResponseError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante il salvataggio su Cosmos DB: {str(e)}"
        )

def check_title_exists(title: str) -> bool:
    query= "SELECT * FROM c WHERE c.manual.title = @title"

    parameters = [
        {"name": "@title", "value": title}
    ]
    try:
       query_items =  articles_container.query_items(query=query, parameters=parameters,enable_cross_partition_query=True)
       if len(list(query_items)) > 0:
            return True
       return False
    except CosmosHttpResponseError as e:
        # Gestisci eventuali errori di connessione
        print(f"Errore durante la query su Cosmos DB: {e}")
        raise

