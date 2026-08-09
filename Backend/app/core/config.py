# pyrefly: ignore [missing-import]
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    #Azure Storage
    AZURE_STORAGE_CONNECTION_STRING: str
    AZURE_STORAGE_CONTAINER_NAME: str = "articles-raw"

    #Azure Cosmos DB
    COSMOS_ENDPOINT: str
    COSMOS_PRIMARY_KEY: str
    COSMOS_DATABASE_NAME: str = "newsdb"
    COSMOS_ARTICLES_CONTAINER: str = "articles"

    #Azure AI Search
    AZURE_SEARCH_ENDPOINT: str
    AZURE_SEARCH_KEY: str
    AZURE_SEARCH_INDEX_NAME: str = "news-index"
    

    #Azure OpenAI
    AZURE_OPENAI_ENDPOINT: str
    AZURE_OPENAI_KEY: str
    AZURE_OPENAI_CHAT_DEPLOYMENT: str = "gpt-4o-mini"
    AZURE_OPENAI_EMBEDDING_DEPLOYMENT: str = "text-embedding-ada-002"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()