import os
import uuid
from urllib.parse import urlparse
from fastapi import APIRouter, UploadFile, File, HTTPException, status, Form, Query,Depends, Response
from datetime import datetime, timezone
from app.config import settings
from app.models.article import ManualMetadata, ArticleDocument, ArticleUpdateModel
from app.services.blob_service import uploaded_file_to_blob, upload_cover, download_file, delete_blob
from app.services.cosmos_service import save_article_metadata, save_chunks_metadata, get_articles_list, \
    get_article_by_id, get_chunks_by_article_id, get_article_by_user, delete_article_metadata, update_article_metadata
from app.services.ai_service import generate_ai_metadata, chunking, generate_embedding_for_chunks
from app.services.ingestion_service import extract_text_from_file
from app.services.cosmos_service import check_title_exists
from app.services.cosmos_service import get_all_categories, add_category_if_not_exists
from app.services.search_service import index_chunk_to_ai_search, check_similarity, delete_article_chunk
from autentication.keycloack_service import get_current_user
router = APIRouter()

@router.post("/articles/upload", status_code=status.HTTP_201_CREATED, summary="Carica un articolo su Blob Storage")

async def upload_file(
        file: UploadFile = File(...),
        cover_image: UploadFile = File(None, description="Immagine di copertina"),
        title: str = Form(None),
        author: str = Form(None),
        category: list[str] = Form(None),
        description: str = Form(None),
        tags: list[str] = Form(None),
        current_user: dict = Depends(get_current_user)):
    """
        Endpoint protetto per il caricamento di un nuovo articolo. Riceve il file testuale,
        un'immagine di copertina e i metadati manuali. Provvede a generare ulteriori metadati
        tramite IA, salva i file nel Blob Storage, indicizza i frammenti su Azure AI Search
        e registra il tutto all'interno di Cosmos DB.
        Effettua tre controlli di validazione prima di procedere:
        1. Verifica l'assenza di titoli duplicati a sistema.
        2. Verifica tramite AI Search che non esista un documento troppo simile (similarità vettoriale).
        3. Verifica che l'utente sia regolarmente autenticato.
        :param file: Oggetto UploadFile obbligatorio che rappresenta il file dell'articolo.
        :param cover_image: Oggetto UploadFile opzionale per la copertina.
        :param title: Stringa contenente il titolo dell'articolo.
        :param author: Stringa contenente il nome dell'autore.
        :param category: Lista di stringhe per le categorie di appartenenza.
        :param description: Stringa per la descrizione manuale.
        :param tags: Lista di stringhe rappresentanti i tag liberi.
        :param current_user: Dizionario con i dati dell'utente autenticato.
        :return dict: Risultato dell'operazione, contenente stato, messaggio e URL (file e cover) generati.
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="nessun file fornito")

    if check_title_exists(title):
        raise HTTPException(status_code=400, detail="titolo già esistente inserirne uno diverso ")

    article_id = str(uuid.uuid4())
    extension = file.filename.split(".")[-1].lower() if "." in file.filename else "txt"
    blob_filename = f"{article_id}.{extension}"

    user_id= current_user.get("sub")

    file_bytes = await file.read()
    parser_file = extract_text_from_file(file_bytes, blob_filename)

    vector= parser_file[:500]
    vector_embedding = await generate_embedding_for_chunks([vector])
    extract_vector= vector_embedding[0]

    if await check_similarity(extract_vector):
        raise HTTPException(status_code=400, detail=" Documento molto simile a uno già esistente")

    blob_url = await uploaded_file_to_blob(blob_filename, file_bytes)
    cover_url = await upload_cover(article_id=article_id, cover_image=cover_image)


    tag_list = [tag.strip() for tag in tags] if tags else []
    cat_list = [cat.strip() for cat in category] if category else []

    for cat in cat_list:
        add_category_if_not_exists(cat)

    manual_meta = ManualMetadata(
        title=title,
        author=author,
        category=cat_list,
        description=description,
        tags=tag_list
    )

    metadata_ia = await generate_ai_metadata(parser_file)
    article_doc = ArticleDocument(
        id = article_id,
        user_id= user_id,
        blob_url=blob_url,
        cover_url = cover_url,
        uploaded_at = datetime.now(timezone.utc).isoformat(),
        manual=manual_meta,
        IA_metadata = metadata_ia

    )


    chunks = chunking(parser_file)
    save_article_metadata(article_doc.model_dump(mode='json'))

    save_chunks_metadata(article_id=article_id, chunks=chunks)
    embeddings = await generate_embedding_for_chunks(chunks)

    await index_chunk_to_ai_search(article_id=article_id , chunks=chunks, embedding=embeddings)

    return {
        "status": "success",
        "message": "file caricato con successo",
        "filename": file.filename,
        "blob_url": blob_url,
        "cover_url": cover_url
    }

@router.get("/articles", summary="Lista di articoli")
async def list_articles(
        decreasing: bool = Query(False, description="ordinamento degli articoli"),
        category: str = Query(None, description="Categorie dell'articoli"),
        skip: int = Query(0, description="Numero di articoli prima di arrivare alla fine"),
        limit: int = Query(10, description= "Numero massimo di elementi da restituire")
):
    """
        Endpoint per recuperare la lista paginata degli articoli presenti in archivio.
        Supporta filtri opzionali per categoria e permette di invertire l'ordinamento cronologico.

        :param decreasing: Booleano per impostare l'ordine (True = meno recente, False = più recente).
        :param category: Stringa opzionale per filtrare gli articoli appartenenti a una specifica categoria.
        :param skip: Intero che indica l'offset di impaginazione.
        :param limit: Intero per il limite massimo di documenti restituiti.
        :return dict: Dizionario con stato, numero di articoli restituiti e la lista completa degli oggetti articolo.
        """
    articles = get_articles_list(decreasing=decreasing, category=category, skip=skip, limit=limit)
    return{
        "status": "success",
        "returned_items": len(articles),
        "articles": articles,
        "skip": skip,
        "limit": limit
    }

@router.get("/articles/categories", summary="Lista di tutte le categorie disponibili")
async def list_categories():
    """
        Restituisce l'elenco completo delle categorie salvate a sistema, ottimizzato
        in modo che il frontend non debba mai ricostruirlo interrogando tutti gli articoli.
        :return dict: Dizionario con stato, numero di categorie trovate e la relativa lista di stringhe.
        """
    categories = get_all_categories()
    return {
        "status": "success",
        "returned_items": len(categories),
        "categories": categories
    }

@router.get("/articles/me", summary="Recupera gli articoli dell'utente loggato ")
async def get_articles_by_user_id(keyword: str = Query(None, description="Parola chiave per la ricerca nella cronologia"),current_user: dict = Depends(get_current_user)):
    """
        Endpoint protetto che recupera esclusivamente gli articoli pubblicati dall'utente
        attualmente loggato. Permette una ricerca testuale rapida (keyword) tra i propri documenti.
        :param keyword: Stringa opzionale per filtrare i propri documenti per titolo o descrizione.
        :param current_user: Dizionario con i dati decodificati dell'utente connesso.
        :return dict: Dizionario con stato, conteggio e lista degli articoli appartenenti all'utente.
        """
    user_id = current_user.get("sub")
    if not user_id:
        raise HTTPException(status_code=404, detail="Username non esistente")
    articles = get_article_by_user(user_id=user_id, keyword=keyword )
    return {
        "status": "success",
        "returned_items": len(articles),
        "articles": articles
    }


@router.get("/articles/{article_id}", summary="Scheda Articolo")
async def get_article_details(article_id: str ):
    """
        Endpoint per recuperare i dettagli completi di un singolo articolo e i suoi
        relativi frammenti testuali (chunk), partendo dal suo ID univoco.

        :param article_id: Stringa contenente l'ID dell'articolo da consultare.
        :return dict: Dizionario con lo stato, l'oggetto articolo completo (metadati) e la lista dei chunk.
    """
    article = get_article_by_id(article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Articulo non existe")
    article_chunks= get_chunks_by_article_id(article_id)
    return {
        "status": "success",
        "returned_items": len(article_chunks),
        "article": article,
        "chunks": article_chunks
    }

@router.get("/articles/{article_id}/download", summary="Download articolo ")
async def download_article(article_id: str):
    """
        Endpoint per scaricare il file fisico originale dell'articolo ospitato su Blob Storage.
        Imposta i corretti header HTTP per forzare il download del file sul client.
        :param article_id: Stringa contenente l'ID dell'articolo da scaricare.
        :return Response: Oggetto Response di FastAPI configurato per lo streaming binario del file.
    """
    article = get_article_by_id(article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Articolo non esistente")
    blob_url = article.get("blob_url") if isinstance(article, dict) else article.blob_url
    if not blob_url:
        raise HTTPException(status_code=404, detail="Nessun file associato a questo articolo")
    blob_filename = os.path.basename(urlparse(blob_url).path)

    file_bytes, content_type = await download_file(blob_filename)

    return Response(
        content=file_bytes,
        media_type=content_type,
        headers={"Content-Disposition": f'attachment; filename="{blob_filename}"'}
    )



@router.get("/articles/{article_id}/cover", summary="Recupera l'immagine di copertina")
async def get_cover_image(article_id: str):
    """
        Endpoint che recupera e serve in streaming l'immagine di copertina di un articolo.
        Se l'immagine manca o corrisponde a un placeholder, solleva un errore 404 (gestito dal frontend).
        :param article_id: Stringa che identifica univocamente l'articolo.
        :return Response: Oggetto Response di FastAPI contenente i byte dell'immagine con il corretto media_type.
    """
    article = get_article_by_id(article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Articolo non trovato")
    cover_url = article.get("cover_url") if isinstance(article, dict) else article.cover_url
    if not cover_url or "placeholder" in cover_url:
        raise HTTPException(status_code=404, detail="Copertina non presente")
    filename = os.path.basename(urlparse(cover_url).path)
    file_bytes, content_type = await download_file(filename, settings.AZURE_STORAGE_IMAGE_CONTAINER)
    return Response(content=file_bytes, media_type=content_type)


@router.delete("/articles/{article_id}/delete", summary="Elimina un articolo")
async def delete_article(article_id: str, current_user: dict = Depends(get_current_user)):
    """
        Endpoint protetto per l'eliminazione profonda di un articolo dall'archivio.
        Verifica che l'utente richiedente sia il proprietario del documento prima di
        procedere all'eliminazione di: file testuale, immagine di copertina, metadati
        su Cosmos DB e vettori su Azure AI Search.
        :param article_id: Stringa che indica l'ID dell'articolo da eliminare.
        :param current_user: Dizionario con i dati dell'utente autenticato.
        :return dict: Risposta con lo stato e il messaggio di conferma dell'avvenuta eliminazione.
    """
    user_id = current_user.get("sub")
    article = get_article_by_id(article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Articolo non trovato")
    if article.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Non hai i permessi per eliminare questo articolo")
    await delete_blob(article.get("blob_url"), settings.AZURE_STORAGE_CONTAINER_NAME)
    await delete_blob(article.get("cover_url"), settings.AZURE_STORAGE_IMAGE_CONTAINER)
    chunk_count =delete_article_metadata(article_id)
    await delete_article_chunk(article_id, chunk_count)
    return {"status": "success",
            "message": "Articolo e risorse collegate eliminati definitivamente"}


@router.put("/articles/{article_id}/update", summary="Modifica i metadati di un articolo")
async def update_article(
        article_id: str,
        update_data: ArticleUpdateModel,
        current_user: dict = Depends(get_current_user)
):
    """
        Endpoint protetto per l'aggiornamento dei metadati manuali di un articolo.
        Esegue il controllo sui permessi utente e applica l'aggiornamento parziale
        ai campi specificati nel database Cosmos. Registra in automatico eventuali nuove categorie.
        :param article_id: Stringa che indica l'ID dell'articolo da aggiornare.
        :param update_data: Modello Pydantic contenente esclusivamente i campi da modificare.
        :param current_user: Dizionario con i dati dell'utente loggato.
        :return dict: Dizionario che conferma il successo o segnala se non ci sono state modifiche.
        """
    user_id = current_user.get("sub")
    existing_article = get_article_by_id(article_id)
    if not existing_article:
        raise HTTPException(status_code=404, detail="Articolo non trovato")
    if existing_article.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Non hai i permessi per modificare questo articolo")
    update_dict = update_data.model_dump(exclude_unset=True)
    if not update_dict:
        return {"status": "success",
                "message": "Nessuna modifica richiesta"}


    new_categories = update_dict.get("category")
    if new_categories:
        for cat in new_categories:
            add_category_if_not_exists(cat)

    update_article_metadata(article_id, update_dict)
    return {"status": "success",
            "message": "Articolo aggiornato con successo"}