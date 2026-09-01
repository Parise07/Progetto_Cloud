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
    '''Riceve un: file, immagine di copertina e i metadati manuali e provvede a generare I metadati attraverso
    L'uso dell'IA e a salvare il file all'interno del blob storage e i metadati all'interno di cosmos.
    Prima che il file e gli altri dati vengano caricati il sistema effettua un check multiplo.
    1° sull'esistenza di un titolo uguale
    2° su una similarità elevata con un altro file
    3° se l'utente è loggato con  current_user: dict = Depends(get_current_user) '''

    if not file.filename:
        raise HTTPException(status_code=400, detail="nessun file fornito")

    if check_title_exists(title):
        raise HTTPException(status_code=400, detail="titolo già esistente inserirne uno diverso ")

    # id univoco per ogni articolo
    article_id = str(uuid.uuid4())
    extension = file.filename.split(".")[-1].lower() if "." in file.filename else "txt"
    blob_filename = f"{article_id}.{extension}"

    #estrapolo id dell'utente dal token
    user_id= current_user.get("sub")

    # 2. Leggo il file e parser
    file_bytes = await file.read()
    parser_file = extract_text_from_file(file_bytes, blob_filename)

    #3 genero un vettore civeta
    vector= parser_file[:500]
    vector_embedding = await generate_embedding_for_chunks([vector])
    extract_vector= vector_embedding[0]

    # 2° controllo di similarità fatto così in basso per poter effettuare il chuncking una sola volta
    if await check_similarity(extract_vector):
        raise HTTPException(status_code=400, detail=" Documento molto simile a uno già esistente")


    # 4. carico file su blob
    blob_url = await uploaded_file_to_blob(blob_filename, file_bytes)
    cover_url = await upload_cover(article_id=article_id, cover_image=cover_image)


    # 5. Formatto i tag
    tag_list = [tag.strip() for tag in tags] if tags else []
    cat_list = [cat.strip() for cat in category] if category else []

    manual_meta = ManualMetadata(
        title=title,
        author=author,
        category=cat_list,
        description=description,
        tags=tag_list
    )

    metadata_ia = await generate_ai_metadata(parser_file)
    # 6. Creo il JSON da caricare in cosmos
    article_doc = ArticleDocument(
        id = article_id,
        user_id= user_id,
        blob_url=blob_url,
        cover_url = cover_url,
        uploaded_at = datetime.now(timezone.utc).isoformat(),
        manual=manual_meta,
        IA_metadata = metadata_ia

    )


   # Salvataggio su cosmos nella raccolta articles
    chunks = chunking(parser_file)
    save_article_metadata(article_doc.model_dump(mode='json'))

    # salvo i chunck nella raccolta chunks
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
    articles = get_articles_list(decreasing=decreasing, category=category, skip=skip, limit=limit)
    return{
        "status": "success",
        "returned_items": len(articles),
        "articles": articles,
        "skip": skip,
        "limit": limit
    }
@router.get("/articles/me", summary="Recupera gli articoli dell'utente loggato ")
async def get_articles_by_user_id(keyword: str = Query(None, description="Parola chiave per la ricerca nella cronologia"),current_user: dict = Depends(get_current_user)):
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
    update_article_metadata(article_id, update_dict)
    return {"status": "success",
            "message": "Articolo aggiornato con successo"}