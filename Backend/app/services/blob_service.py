from azure.core.exceptions import ResourceExistsError

from app.azure_clients import blob_service_client
from app.config import settings
from fastapi import HTTPException

async def uploaded_file_to_blob(filename: str, file_content: bytes) -> str:
    try:
        container_client = blob_service_client.get_container_client(settings.AZURE_STORAGE_CONTAINER_NAME)
        try:
            await container_client.create_container()
        except ResourceExistsError:
            # Il container esiste già, ignoriamo l'errore e procediamo
            pass
        blob_client = container_client.get_blob_client(filename)
        await blob_client.upload_blob(file_content, overwrite=True)
        return blob_client.url

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante l'upload su Azure Blob: {str(e)}"
        )