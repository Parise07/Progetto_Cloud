from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    #Azure Storage
    AZURE_STORAGE_CONNECTION_STRING: str
    AZURE_STORAGE_CONTAINER_NAME: str = "articles-raw"
    AZURE_STORAGE_IMAGE_CONTAINER : str = "articles-image"

    #Azure Cosmos DB
    COSMOS_ENDPOINT: str
    COSMOS_PRIMARY_KEY: str
    COSMOS_DATABASE_NAME: str = "newsarchive"
    COSMOS_ARTICLES_CONTAINER: str = "articles"
    COSMOS_CHUNKS_CONTAINER: str = "chunks"
    COSMOS_CATEGORIES_CONTAINER: str = "categories"

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
    # Valorizzare solo se il client viene reso "confidential" su Keycloak.
    KEYCLOAK_CLIENT_SECRET: str | None = None
    # Credenziali dell'account di servizio usato per la registrazione utenti.
    KEYCLOAK_ADMIN_USERNAME: str = "admin"
    KEYCLOAK_ADMIN_PASSWORD: str = "admin"
    KEYCLOAK_ADMIN_REALM: str = "master"
    # Secondi di validita' della cache locale delle chiavi pubbliche (JWKS).
    KEYCLOAK_JWKS_CACHE_TTL: int = 3600
    # Se True, rifiuta i token emessi per un client diverso da KEYCLOAK_CLIENT_ID.
    KEYCLOAK_VERIFY_AZP: bool = False

    #Ricerca RAG
    # Numero di chunk recuperati da AI Search per rispondere. Piu' alto = piu'
    # articoli distinti fra le fonti, ma prompt piu' lungo verso Azure OpenAI.
    RAG_TOP_K: int = 10

    TEST_MODE: bool = False

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra="ignore"

settings = Settings()