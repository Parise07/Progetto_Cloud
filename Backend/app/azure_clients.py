from azure.core.credentials import AzureKeyCredential
from azure.cosmos import CosmosClient
from azure.search.documents.aio import SearchClient
from openai import AzureOpenAI

from app.config import settings
# Utilizziamo il client ASINCRONO di Azure Blob Storage (azure.storage.blob.aio)
# per garantire la compatibilità con FastAPI (async/await) ed evitare il mix
# sincrono/asincrono che causa: ValueError: 'coroutine' object is not iterable
from azure.storage.blob.aio import BlobServiceClient as AsyncBlobServiceClient

blob_service_client = AsyncBlobServiceClient.from_connection_string(settings.AZURE_STORAGE_CONNECTION_STRING)

cosmos_client = CosmosClient(settings.COSMOS_ENDPOINT,
                             credential = settings.COSMOS_PRIMARY_KEY)

search_client = SearchClient(endpoint=settings.AZURE_SEARCH_ENDPOINT,
                             index_name=settings.AZURE_SEARCH_INDEX_NAME,
                             credential=AzureKeyCredential(settings.AZURE_SEARCH_ADMIN_KEY)
                             )
openai_client = AzureOpenAI(azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
                            api_key=settings.AZURE_OPENAI_KEY,
                            api_version= "2025-04-14")

