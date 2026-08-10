from azure.cosmos.exceptions import CosmosHttpResponseError
from fastapi import HTTPException
from app.config import settings
from app.azure_clients import cosmos_client
database = cosmos_client.get_database_client(settings.COSMOS_DATABASE_NAME)
articles_container = database.get_container_client(settings.COSMOS_ARTICLES_CONTAINER)



def save_article_metadata(manual_data: dict) -> dict:
    try:
        created_item= articles_container.create_item(body=manual_data)
        return created_item
    except CosmosHttpResponseError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante il salvataggio su Cosmos DB: {str(e)}"
        )
