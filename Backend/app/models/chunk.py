from pydantic import BaseModel


class RagSearchQuery(BaseModel):
    question : str

class GenericSearchQuery(BaseModel):
    keyword: str

class ArticleChatQuery(BaseModel):
    question: str
    current_article_id: str