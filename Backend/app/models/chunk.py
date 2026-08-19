from pydantic import BaseModel


class RagSearchQuery(BaseModel):
    question : str

class GenericSearchQuery(BaseModel):
    keyword: str