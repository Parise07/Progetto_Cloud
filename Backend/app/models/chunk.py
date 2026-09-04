from pydantic import BaseModel, Field


class RagSearchQuery(BaseModel):
    question : str
    # Se omesso vale settings.RAG_TOP_K.
    top_k: int | None = Field(default=None, ge=1, le=50)

class GenericSearchQuery(BaseModel):
    keyword: str

class ArticleChatQuery(BaseModel):
    question: str
    current_article_id: str