from azure.core.credentials import AzureKeyCredential
from azure.cosmos import CosmosClient
from azure.search.documents.aio import SearchClient
from openai import AzureOpenAI

from app.core.config import settings
from azure.storage.blob import BlobServiceClient

blob_service_client = BlobServiceClient.from_connection_string(settings.AZURE_STORAGE_CONNECTION_STRING)

cosmos_client = CosmosClient(settings.COSMOS_ENDPOINT,
                             credential = settings.COSMOS_PRIMARY_KEY)

search_client = SearchClient(endpoint=settings.AZURE_SEARCH_ENDPOINT,
                             index_name=settings.AZURE_SEARCH_INDEX_NAME,
                             credential=AzureKeyCredential(settings.AZURE_SEARCH_ADMIN_KEY)
                             )
openai_client = AzureOpenAI(azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
                            api_key=settings.AZURE_OPENAI_KEY,
                            api_version= "2024-02-01")

