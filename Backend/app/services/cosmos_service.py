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
    Funzione che crea un collegamento strutturato tra un articolo e i suoi frammenti di testo (chunk),
    salvandoli nel container dedicato su Cosmos DB.
    :param article_id: Stringa che rappresenta l'identificativo univoco dell'articolo padre.
    :param chunks: Lista di stringhe, dove ogni elemento è un frammento di testo dell'articolo.
    :return: None. (Solleva un'eccezione HTTPException in caso di errore nel salvataggio).
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
    Funzione che riceve i metadati manuali di un articolo inseriti dall'utente e li
    registra nel container degli articoli su Cosmos DB come nuovo documento.
    :param manual_data: Dizionario contenente i dati e le informazioni del documento.
    :return dict: Il documento appena creato e restituito da Cosmos DB.
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
    """
    Funzione di controllo (primo blocco) che verifica se esiste già un articolo con il
    titolo specificato, al fine di evitare la creazione di documenti duplicati nell'archivio.
    :param title: Stringa che rappresenta il titolo dell'articolo inserito dall'utente.
    :return bool: True se viene trovato almeno un articolo con lo stesso titolo, False altrimenti.
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
    Funzione che esegue una ricerca full-text su Cosmos DB cercando corrispondenze
    delle parole chiave (case-insensitive) all'interno del titolo, della descrizione,
    dell'autore, delle categorie o dei tag di un articolo.
    :param keywords: Stringa contenente le parole chiave da ricercare.
    :return list[dict]: Lista di dizionari, dove ogni dizionario rappresenta un articolo che
                        soddisfa i criteri di ricerca.
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
    Funzione che restituisce una lista paginata di articoli presenti nel database.
    Permette di filtrare i risultati per categoria e di ordinarli cronologicamente.
    :param decreasing: Booleano che determina l'ordine temporale (True = ascendente, False = discendente).
    :param category: Stringa opzionale per filtrare gli articoli appartenenti a una specifica categoria.
    :param skip: Intero che indica il numero di documenti da saltare (offset per l'impaginazione, default 0).
    :param limit: Intero che indica il numero massimo di documenti da restituire (default 10).
    :return list[dict]: Lista di articoli estratti dal database.
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
    Funzione che, dato l'identificativo univoco di un articolo, effettua una lettura
    puntuale su Cosmos DB per restituirne tutti i metadati.
    :param article_id: Stringa che rappresenta l'ID dell'articolo da recuperare.
    :return dict: Dizionario contenente i dati dell'articolo (o un dizionario vuoto in caso di errore).
    """
    try:
        return articles_container.read_item(item=article_id, partition_key= article_id)
    except CosmosHttpResponseError as e:
        print(f"Errore recupero metadatione: {e}")
        return {}

def get_titles_by_ids(article_ids: list[str]) -> dict[str, str]:
    """
    Funzione che riceve una lista di ID di articoli e restituisce una mappa (ID -> Titolo)
    eseguendo un'unica query ottimizzata. Utile per le pipeline RAG per sostituire gli UUID
    con i titoli in linguaggio naturale prima di comporre il contesto per l'LLM, migliorandone le performance.
    :param article_ids: Lista di stringhe contenente gli ID degli articoli (anche con ripetizioni).
    :return dict[str, str]: Dizionario che mappa l'ID dell'articolo al suo titolo. (Gli ID non trovati vengono ignorati).
    """
    unici = [a for a in dict.fromkeys(article_ids) if a]
    if not unici:
        return {}

    # Un'unica query con ARRAY_CONTAINS invece di N letture puntuali.
    query = "SELECT c.id, c.manual.title FROM c WHERE ARRAY_CONTAINS(@ids, c.id)"
    parameters = [{"name": "@ids", "value": unici}]
    try:
        results = articles_container.query_items(
            query=query,
            parameters=parameters,
            enable_cross_partition_query=True
        )
        return {r["id"]: r.get("title") for r in results if r.get("title")}
    except CosmosHttpResponseError as e:
        print(f"Errore durante il recupero dei titoli: {e}")
        return {}


def get_chunks_by_article_id(article_id: str) -> list[dict]:
    """
    Funzione che interroga il container dei chunk per recuperare tutti i frammenti
    associati a uno specifico articolo, ordinandoli in base al loro indice sequenziale.
    :param article_id: Stringa che indica l'ID dell'articolo padre.
    :return list[dict]: Lista di dizionari contenenti i testi dei chunk e i relativi indici.
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
    Funzione che recupera dal database tutti gli articoli caricati o appartenenti a
    uno specifico utente, ordinandoli per data di caricamento. Supporta un filtro testuale opzionale.
    :param user_id: Stringa che identifica univocamente l'utente.
    :param keyword: Stringa opzionale per filtrare i risultati cercando nel titolo o nella descrizione.
    :return list[dict]: Lista degli articoli associati all'utente.
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
    Funzione che elimina definitivamente i metadati di un articolo dal relativo container
    e procede a cancellare anche tutti i chunk ad esso associati iterando sui loro ID.
    :param article_id: Stringa che rappresenta l'ID dell'articolo da eliminare.
    :return int: Numero totale di chunk eliminati dal database.
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
    Funzione che permette di aggiornare parzialmente i campi del blocco 'manual'
    di un articolo esistente su Cosmos DB, preservando gli altri dati del documento.
    :param article_id: Stringa che rappresenta l'ID dell'articolo da aggiornare.
    :param new_data: Dizionario contenente le chiavi e i nuovi valori da sostituire/aggiungere.
    :return dict: Il documento articolo aggiornato. (Solleva un'eccezione in caso di errore).
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
    Funzione che restituisce l'elenco di tutte le categorie esistenti, ordinate alfabeticamente.
    La lettura è ottimizzata in quanto interroga un container dedicato ("categories"), evitando
    onerose scansioni sull'intero database degli articoli.
    :return list[str]: Lista di stringhe contenente i nomi di tutte le categorie.
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
    Funzione che registra una nuova categoria nel container "categories" solo se questa
    non è già presente. Sfrutta una point-read sull'ID normalizzato per minimizzare
    i costi dell'operazione su Cosmos DB.
    :param category_name: Stringa che rappresenta il nome della categoria da inserire.
    :return bool: True se la categoria è stata creata con successo, False se esisteva già o in caso di errore.
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