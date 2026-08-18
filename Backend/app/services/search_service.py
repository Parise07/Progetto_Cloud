from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from app.models.article import EmbeddingDocument

async def index_chunk_to_ai_search(article_id: str, chunks: list[str], embedding: list[list[float]]):
        diz = EmbeddingDocument(
            chunk_id= f"{article_id}-chunk-{index}",
            article_id=article_id,
            embedding=embedding,

        )