from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    #Azure Storage
    AZURE_STORAGE_CONNECTION_STRING: str
    AZURE_STORAGE_CONTAINER_NAME: str = "articles-raw"
    AZURE_STORAGE_IMAGE_CONTAINER : str = "articles-image"

    #Azure Cosmos DB
    COSMOS_ENDPOINT: str
    COSMOS_PRIMARY_KEY: str
    COSMOS_DATABASE_NAME: str = "newsdb"
    COSMOS_ARTICLES_CONTAINER: str = "articles"
    COSMOS_CHUNKS_CONTAINER: str = "chunks"

    #Azure AI Search
    AZURE_SEARCH_ENDPOINT: str
    AZURE_SEARCH_ADMIN_KEY: str
    AZURE_SEARCH_INDEX_NAME: str = "news-index"

    

    #Azure OpenAI
    AZURE_OPENAI_ENDPOINT: str
    AZURE_OPENAI_KEY: str
    AZURE_OPENAI_CHAT_DEPLOYMENT: str = "gpt-4o-mini"
    AZURE_OPENAI_EMBEDDING_DEPLOYMENT: str = "text-embedding-ada-002"
    AZURE_OPENAI_API_VERSION: str = "2024-07-18"

    #keycloack
    KEYCLOAK_SERVER_URL: str
    KEYCLOAK_REALM: str
    KEYCLOAK_CLIENT_ID: str

    TEST_MODE: bool = False

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra="ignore"

settings = Settings()