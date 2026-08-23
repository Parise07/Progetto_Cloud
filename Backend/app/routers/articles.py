import uuid
from fastapi import APIRouter, UploadFile, File, HTTPException, status, Form, Query,Depends
from datetime import datetime, timezone
from app.models.article import ManualMetadata, ArticleDocument
from app.services.blob_service import uploaded_file_to_blob,upload_cover
from app.services.cosmos_service import save_article_metadata, save_chunks_metadata, get_articles_list, get_article_by_id,get_chunks_by_article_id
from app.services.ai_service import generate_ai_metadata, chunking, generate_embedding_for_chunks
from app.services.ingestion_service import extract_text_from_file
from app.services.cosmos_service import check_title_exists
from app.services.search_service import index_chunk_to_ai_search,check_similarity
from autentication.keycloack_service import get_current_user
router = APIRouter()

@router.post("/articles/upload", status_code=status.HTTP_201_CREATED, summary="Carica un articolo su Blob Storage")
async def upload_file(
        file: UploadFile = File(...),
        cover_image: UploadFile = File(None, description="Immagine di copertina"),
        title: str = Form(None),
        author: str = Form(None),
        category: str = Form(None),
        description: str = Form(None),
        tags: str = Form(None),
        current_user: dict = Depends(get_current_user)):



    if not file.filename:
        raise HTTPException(status_code=400, detail="nessun file fornito")

    # 1. Genero un id univoco per distinguere gli articoli
    article_id = str(uuid.uuid4())
    extension = file.filename.split(".")[-1].lower() if "." in file.filename else "txt"
    blob_filename = f"{article_id}.{extension}"

    if check_title_exists(title):
        raise HTTPException(status_code=400, detail="titolo già esistente inserirne uno diverso ")

    # 2. Leggo il file e parser
    file_bytes = await file.read()
    parser_file = extract_text_from_file(file_bytes, blob_filename)

    #3 genero un vettore civeta
    vector= parser_file[:500]
    vector_embedding = await generate_embedding_for_chunks([vector])
    extract_vector= vector_embedding[0]

    # 3 bis controllo similarità
    if await check_similarity(extract_vector):

        raise HTTPException(status_code=400, detail=" Documento molto simile a uno già esistente")


    # 4. carico file su blob
    blob_url = await uploaded_file_to_blob(blob_filename, file_bytes)
    cover_url = await upload_cover(article_id=article_id, cover_image=cover_image)


    # 5. Formatto i tag
    tag_list = [tag.strip() for tag in tags.split(",")] if tags else []

    manual_meta = ManualMetadata(
        title=title,
        author=author,
        category=category,
        description=description,
        tags=tag_list
    )

    metadata_ia = await generate_ai_metadata(parser_file)
    # 6. Creo il JSON da caricare in cosmos
    article_doc = ArticleDocument(
        id = article_id,
        blob_url=blob_url,
        cover_url = cover_url,
        uploaded_at = datetime.now(timezone.utc).isoformat(),
        manual=manual_meta,
        IA_metadata = metadata_ia

    )


   # 7. Salvo su Cosmos e chunking
    chunks = chunking(parser_file)
    save_article_metadata(article_doc.model_dump(mode='json'))

    save_chunks_metadata(article_id=article_id, chunks=chunks)
    #8 embedding
    embeddings =generate_embedding_for_chunks(chunks)

    # 9 AI Search
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