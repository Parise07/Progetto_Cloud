from app.azure_clients import blob_service_client
from app.config import settings
from fastapi import UploadFile, HTTPException

'''
Metodo che ci permette di caricare un file generico in Azure Blob Storage.
Usa il client ASINCRONO (azure.storage.blob.aio) in linea con FastAPI async.
'''
async def uploaded_file_to_blob(file: UploadFile) -> str:
    try:
        # Legge i byte del file caricato tramite FastAPI
        file_content = await file.read()
        file_name = file.filename  # Corretto typo: era 'fine_name'

        # Usiamo async with per garantire la chiusura corretta della sessione HTTP
        # sia per il container_client che per il blob_client
        async with blob_service_client.get_container_client(settings.AZURE_STORAGE_CONTAINER_NAME) as container_client:
            blob_client = container_client.get_blob_client(file_name)
            # await OBBLIGATORIO: upload_blob sul client asincrono restituisce una coroutine
            await blob_client.upload_blob(file_content, overwrite=True)
            return blob_client.url

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante l'upload su Azure Blob: {str(e)}"
        )
