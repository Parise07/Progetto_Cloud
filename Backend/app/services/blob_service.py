from azure.core.exceptions import ResourceExistsError, ResourceNotFoundError
from urllib.parse import urlparse
import os
from app.azure_clients import blob_service_client
from app.config import settings
from fastapi import HTTPException,UploadFile

async def uploaded_file_to_blob(filename: str, file_content: bytes, container_name : str=settings.AZURE_STORAGE_CONTAINER_NAME) -> str:
    """
    Funzione che carica un file nel container blob
    :param filename:
    :param file_content:
    :param container_name:
    :return str: url blob
    """
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
    """
    Funzione che carica la cover legata all'articolo nel conteiner dedicato
    :param article_id:
    :param cover_image:
    :return str: cover url
    """
    cover_url = "https://tuo_dominio/placeholder.png"
    if not cover_image or not cover_image.filename:
        return cover_url
    try:
        img_extension = cover_image.filename.split(".")[-1].lower()
        img_filename = f"{article_id}-cover.{img_extension}"
        img_bytes = await cover_image.read()
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


async def download_file(filename :str, container_name: str = settings.AZURE_STORAGE_CONTAINER_NAME) -> tuple[bytes, str]:
    """
    Funzione che prepara il file contenuto nel blob storage e lo prepara per il download
    :param filename:
    :param container_name:
    :return:
    """
    try:
        container_client = blob_service_client.get_container_client(container_name)
        blob_client = container_client.get_blob_client(filename)
        try:
            downloader = await blob_client.download_blob()
        except ResourceNotFoundError:
            raise HTTPException(
                status_code=404,
                detail=f"File '{filename}' non trovato su Azure Blob."
            )

        file_bytes = await downloader.readall()
        properties = await blob_client.get_blob_properties()
        content_type = properties.content_settings.content_type or "application/octet-stream"
        return file_bytes, content_type
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante il download da Azure Blob: {str(e)}"
        )



async def delete_blob(blob_url: str, container_name: str = settings.AZURE_STORAGE_CONTAINER_NAME):
    """
    Ricevuto l'URL elimina il File dal blob storage
    :param blob_url:
    :param container_name:
    """
    if not blob_url or "placeholder" in blob_url:
        return
    try:
        filename = os.path.basename(urlparse(blob_url).path)
        container_client = blob_service_client.get_container_client(container_name)
        blob_client = container_client.get_blob_client(filename)
        await blob_client.delete_blob()
    except ResourceNotFoundError:
        print(f"File {blob_url} già inesistente, procedo.")
    except Exception as e:
        print(f"Errore eliminazione blob {blob_url}: {e}")