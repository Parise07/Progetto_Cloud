from azure.core.exceptions import ResourceExistsError, ResourceNotFoundError
from urllib.parse import urlparse
import os
from app.azure_clients import blob_service_client
from app.config import settings
from fastapi import HTTPException,UploadFile

async def uploaded_file_to_blob(filename: str, file_content: bytes, container_name : str=settings.AZURE_STORAGE_CONTAINER_NAME) -> str:
    """
    Funzione asincrona che carica un file all'interno di un container su Azure Blob Storage.
    Se il container non esiste, tenta di crearlo automaticamente prima dell'upload.
    Se un file con lo stesso nome esiste già, lo sovrascrive.
    :param filename: Stringa che rappresenta il nome con cui il file verrà salvato nel blob.
    :param file_content: Il contenuto grezzo del file in formato bytes.
    :param container_name: Stringa che indica il nome del container di destinazione (di default usa quello nelle impostazioni).
    :return str: L'URL pubblico/assoluto del blob appena caricato. (Solleva HTTPException in caso di errore).
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
    '''
    Funzione asincrona che gestisce il caricamento dell'immagine di copertina (cover)
    di un articolo in un container dedicato. Se non viene fornita alcuna immagine,
    restituisce di default un URL di placeholder.
    :param article_id: Stringa che rappresenta l'identificativo univoco dell'articolo a cui associare la cover.
    :param cover_image: Oggetto UploadFile che rappresenta l'immagine caricata dall'utente (può essere None).
    :return str: L'URL dell'immagine di copertina caricata su Blob Storage (o l'URL del placeholder).
    '''
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
    '''
    Funzione asincrona che recupera e scarica il contenuto di un file da Azure Blob Storage,
    restituendone i byte crudi e il relativo content type, preparandolo per essere
    inviato come risposta al client.
    :param filename: Stringa che rappresenta il nome del file da scaricare dal blob.
    :param container_name: Stringa che indica il nome del container in cui cercare il file.
    :return tuple[bytes, str]: Una tupla contenente i byte del file e il suo content_type (es. MIME type).
                               (Solleva HTTP 404 se il file non esiste, o 500 per altri errori).
    '''
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
    Funzione asincrona che, dato l'URL di un file ospitato su Azure Blob Storage,
    estrae dinamicamente il nome del file e procede alla sua eliminazione dal container.
    Ignora l'operazione in modo sicuro se l'URL appartiene a un placeholder o se il file non esiste.
    :param blob_url: Stringa contenente l'URL pubblico completo del file (blob) da eliminare.
    :param container_name: Stringa che indica il nome del container in cui si trova il file.
    :return: None.
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