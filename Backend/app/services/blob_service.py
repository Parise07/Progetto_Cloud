from azure.core.exceptions import ResourceExistsError

from app.azure_clients import blob_service_client
from app.config import settings
from fastapi import HTTPException,UploadFile

async def uploaded_file_to_blob(filename: str, file_content: bytes, container_name : str=settings.AZURE_STORAGE_CONTAINER_NAME) -> str:
    try:
        container_client = blob_service_client.get_container_client(container_name)
        try:
            await container_client.create_container()
        except ResourceExistsError:
            pass
        blob_client = container_client.get_blob_client(filename)
        await blob_client.upload_blob(file_content, overwrite=True)
        return blob_client.url
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante l'upload su Azure Blob: {str(e)}"
        )

async def upload_cover(article_id :str, cover_image: UploadFile | None) -> str:
    cover_url = "https://tuo_dominio/placeholder.png"
    if not cover_image or not cover_image.filename:
        return cover_url
    try:
        img_extension = cover_image.filename.split(".")[-1].lower()
        img_filename = f"{article_id}-cover.{img_extension}"
        img_bytes = await cover_image.read()

        # Sfruttiamo la funzione generica passando il container per le immagini
        cover_url = await uploaded_file_to_blob(
            filename=img_filename,
            file_content=img_bytes,
            container_name = settings.AZURE_STORAGE_IMAGE_CONTAINER
        )
        return cover_url
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante il caricamento della copertina: {str(e)}"
        )