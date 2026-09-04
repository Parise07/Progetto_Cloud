from azure.cosmos.exceptions import CosmosHttpResponseError
from fastapi import HTTPException
from app.config import settings
from app.azure_clients import cosmos_client
database = cosmos_client.get_database_client(settings.COSMOS_DATABASE_NAME)
articles_container = database.get_container_client(settings.COSMOS_ARTICLES_CONTAINER)
chunks_container = database.get_container_client(settings.COSMOS_CHUNKS_CONTAINER)
categories_container= database.get_container_client(settings.COSMOS_CATEGORIES_CONTAINER)

def save_chunks_metadata(article_id: str, chunks: list[str]):
    """
    Funzione che crea un collegamento tra l'articolo e i suoi chunck e li acrica su cosmos
    nel container chunk
    :param article_id:
    :param chunks:
    :return:
    """
    try:
        for index, text in enumerate(chunks):
            chunk_document = {
                "id": f"{article_id}-chunk-{index}",
                "article_id": article_id,
                "chunk_index": index,
                "text": text
            }
            chunks_container.create_item(body=chunk_document)

    except CosmosHttpResponseError as e:
        print(f"Errore durante il salvataggio dei chunk su Cosmos DB: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante il salvataggio dei chunk su Cosmos DB: {str(e)}"
        )

def save_article_metadata(manual_data: dict) -> dict:
    """
    Funzione che riceve i metadati inseriti dall'utente e li carica su cosmos
    :param manual_data:
    :return dict:
    """
    try:
        created_item= articles_container.create_item(body=manual_data)
        return created_item
    except CosmosHttpResponseError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante il salvataggio su Cosmos DB: {str(e)}"
        )

def check_title_exists(title: str) -> bool:
    """Funzione di check (primo blocco) sulla similarità dei titoli
    evitando che due articoli abbiano stesso titolo
    :param title: titolo file inserito dall'utente
    :return boolean:
    """

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
        print(f"Errore durante la query su Cosmos DB: {e}")
        raise

def search_by_keywords(keywords: str) -> list[dict]:
    """
    Funzione che effettua ricerca tramite keywords
    :param keywords:
    :return list[dict]: lista di articoli
    """
    query = """
            SELECT c.id, c.manual.title, c.manual.author, 
                   c.manual.description, c.manual.tags, 
                   c.blob_url, c.manual.category,c.cover_url
            FROM c 
            WHERE CONTAINS(c.manual.title, @keywords, true)
            OR CONTAINS(c.manual.description, @keywords, true)
            OR CONTAINS(c.manual.author, @keywords, true)
            OR EXISTS(SELECT VALUE cat FROM cat IN c.manual.category WHERE CONTAINS(cat, @keywords, true))
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
    """
    Funzione che restituisce una lista di articoli in un range compreso tra skip e limit
    :param decreasing:
    :param category:
    :param skip:
    :param limit:
    :return list[dict]: lista di articoli
    """

    query = """
            SELECT c.id, c.manual.title, c.manual.author, 
                   c.manual.category, c.blob_url,c.cover_url, c.uploaded_at
            FROM c 
        """
    parameters = []

    if category:
        query += " WHERE ARRAY_CONTAINS(c.manual.category, @category)"
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
    """
    Funzione che dato l'id dell'articolo ne restituisce le informazioni ad esso legato
    :param article_id:
    :return dict : articolo
    """
    try:
        return articles_container.read_item(item=article_id, partition_key= article_id)
    except CosmosHttpResponseError as e:
        print(f"Errore recupero metadatione: {e}")
        return {}

def get_chunks_by_article_id(article_id: str) -> list[dict]:
    """
    Recupera tutti i frammenti di un articolo dato il suo ID
    :param article_id:
    :return list[dict]: lista di chunk
    """

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

def get_article_by_user(user_id: str, keyword: str = None) -> list[dict]:
    """
    ricevuto uno lo user ID recupera tutti gli articoli collegati ad esso
     se richiesto filtra anche il risulta tramite keywords per una modifica più rapida
    :param user_id:
    :param keyword:
    :return list[dict]:
    """
    query = """
            SELECT c.id, c.manual.title, c.manual.author, 
                   c.manual.description, c.manual.tags,
                   c.manual.category, c.blob_url, c.cover_url, c.uploaded_at
            FROM c 
            WHERE c.user_id = @user_id
        """
    parameters = [{"name": "@user_id", "value": user_id}]
    if keyword and keyword.strip():
        query += """ AND (
                CONTAINS(c.manual.title, @keyword, true) 
                OR CONTAINS(c.manual.description, @keyword, true)
            )"""
        parameters.append({"name": "@keyword", "value": keyword.strip()})

    query += " ORDER BY c.uploaded_at DESC"
    try:
        results = articles_container.query_items(
            query=query,
            parameters=parameters,
            enable_cross_partition_query=True
        )
        return list(results)
    except CosmosHttpResponseError as e:
        print(f"Errore recupero articoli: {e}")
        return []


def delete_article_metadata(article_id: str) -> int:
    """
    Funzione che dato un id di un articolo elimina i sui metadati
    :param article_id:
    :return int: numero di chunk eliminati
    """
    chunk_count = 0
    try:
        chunks = get_chunks_by_article_id(article_id)
        chunk_count = len(chunks)
        for chunk in chunks:
            chunk_id = f"{article_id}-chunk-{chunk['chunk_index']}"
            try:
                chunks_container.delete_item(item=chunk_id, partition_key=chunk_id)
            except CosmosHttpResponseError:
                pass
        articles_container.delete_item(item=article_id, partition_key=article_id)
    except CosmosHttpResponseError as e:
        print(f"Errore durante l'eliminazione da Cosmos DB: {e}")

    return chunk_count


def update_article_metadata(article_id: str, new_data: dict) -> dict:
    """
    Funzione che aggiorna solo i metadati manuali
    :param article_id:
    :param new_data:
    :return dict:
    """
    try:
        article = articles_container.read_item(item=article_id, partition_key=article_id)
        if "manual" not in article or article["manual"] is None:
            article["manual"] = {}
        for key, value in new_data.items():
            if value is not None:
                article["manual"][key] = value
        updated_article = articles_container.replace_item(item=article_id, body=article)
        return updated_article
    except CosmosHttpResponseError as e:
        print(f"Errore durante la modifica su Cosmos DB: {e}")
        raise HTTPException(status_code=500, detail="Impossibile aggiornare l'articolo")


def get_all_categories() -> list[str]:
    """
    Funzione che restituisce l'elenco di tutte le categorie esistenti,
    ordinate alfabeticamente.
    Le categorie sono mantenute in un container dedicato ("categories")
    proprio per evitare di dover scansionare/interrogare tutti gli
    articoli ogni volta che serve conoscere le categorie disponibili:
    il container è piccolo e la lettura è quindi economica e veloce.
    :return list[str]: lista dei nomi delle categorie
    """
    query = "SELECT c.name FROM c ORDER BY c.name ASC"
    try:
        results = categories_container.query_items(
            query=query,
            enable_cross_partition_query=True
        )
        return [item["name"] for item in results]
    except CosmosHttpResponseError as e:
        print(f"Errore durante il recupero delle categorie da Cosmos DB: {e}")
        return []


def add_category_if_not_exists(category_name: str) -> bool:
    """
    Funzione che, data una categoria, la salva nel container "categories"
    solo se non esiste già (controllo case-insensitive tramite id normalizzato).
    Il controllo è fatto con una point-read sull'id (partition key = id),
    molto più economica di una query, così da poter chiamare questa
    funzione anche più volte senza costi elevati.
    :param category_name:
    :return bool: True se è stata creata una nuova categoria, False se esisteva già o in caso di errore
    """
    if not category_name or not category_name.strip():
        return False

    normalized_name = category_name.strip()
    category_id = normalized_name.lower()

    try:
        categories_container.read_item(item=category_id, partition_key=category_id)
        return False
    except CosmosHttpResponseError as e:
        if e.status_code != 404:
            print(f"Errore durante il controllo della categoria su Cosmos DB: {e}")
            return False

    try:
        categories_container.create_item(body={"id": category_id, "name": normalized_name})
        return True
    except CosmosHttpResponseError as e:
        print(f"Errore durante il salvataggio della categoria su Cosmos DB: {e}")
        return False