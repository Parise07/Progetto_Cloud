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
                "id": f"{article_id}-chunk-{index}",  # ID univoco del chunk
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
       results = list(query_items)
       print(f"Trovati duplicati: {len(results)}")

       if len(results) > 0:
           return True
       return False
    except CosmosHttpResponseError as e:
        # Gestisci eventuali errori di connessione
        print(f"Errore durante la query su Cosmos DB: {e}")
        raise

def search_by_keywords(keywords: str) -> list[dict]:
    '''Ricerca normale attraverso keywords '''
    query = """
            SELECT c.id, c.manual.title, c.manual.author, 
                   c.manual.description, c.manual.tags, 
                   c.blob_url, c.manual.category,c.cover_url
            FROM c 
            WHERE CONTAINS(c.manual.title, @keywords, true)
            OR CONTAINS(c.manual.description, @keywords, true)
            OR CONTAINS(c.manual.category, @keywords, true)
            OR CONTAINS(c.manual.author, @keywords, true)
            OR EXISTS(SELECT VALUE t FROM t IN c.manual.tags WHERE CONTAINS(t, @keywords, true)) """


    parameters = [
        {"name": "@keywords", "value": keywords}
    ]

    try:
        results = articles_container.query_items(
            query=query,
            parameters=parameters,
            enable_cross_partition_query=True
        )
        return list(results)
    except CosmosHttpResponseError as e:
        print(f"Errore durante la query su Cosmos DB: {e}")
        return []

def get_articles_list(decreasing: bool = False, category: str = None, skip: int =0 , limit: int = 10) -> list[dict]:
    ''' funzione che restituisce una lista di articoli nella pagina per
    l'inifinite scroll e ordina per data di inserimento per avere gli articoli più recenti'''

    query = """
            SELECT c.id, c.manual.title, c.manual.author, 
                   c.manual.category, c.blob_url,c.cover_url, c.uploaded_at
            FROM c 
        """
    parameters = []

    if category:
        query += " WHERE c.manual.category = @category"
        parameters.append({"name": "@category", "value": category})

    if decreasing:
        query += " ORDER BY c.uploaded_at ASC OFFSET @skip LIMIT @limit"
    else:
        query += " ORDER BY c.uploaded_at DESC OFFSET @skip LIMIT @limit"
    parameters.extend([
        {"name": "@skip", "value": skip},
        {"name": "@limit", "value": limit}
    ])
    try:
        results = articles_container.query_items(
            query=query,
            parameters=parameters,
            enable_cross_partition_query=True
        )
        return list(results)
    except CosmosHttpResponseError as e:
        print(f"Errore recupero lista articoli: {e}")
        return []

def get_article_by_id(article_id: str) -> dict:
    '''Restituisce un singolo articolo dato il suo ID'''
    try:
        return articles_container.read_item(item=article_id, partition_key= article_id)
    except CosmosHttpResponseError as e:
        print(f"Errore recupero metadatione: {e}")
        return {}
def get_chunks_by_article_id(article_id: str) -> list[dict]:
    '''Recupera tutti i frammenti di un articolo dato il suo ID'''
    query = "SELECT c.chunk_index, c.text FROM c WHERE c.article_id = @article_id ORDER BY c.chunk_index ASC"
    parameters = [{"name": "@article_id", "value": article_id}]
    try:
        results = chunks_container.query_items(
            query=query,
            parameters=parameters,
            enable_cross_partition_query=True
        )
        return list(results)
    except CosmosHttpResponseError as e:
        print(f"Errore recupero metadatione: {e}")
        return []