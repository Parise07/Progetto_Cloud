from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class ManualMetadata(BaseModel):
    """Metadati inseriti manualmente dall'utente al momento dell'upload."""
    title: Optional[str] = Field(None, description="Titolo dell'articolo")
    author: Optional[str] = Field(None, description="Autore o fonte dell'articolo")
    category: Optional[str] = Field(None, description="Categoria tematica (es. Politica, Sport)")
    description: Optional[str] = Field(None, description="Breve descrizione manuale")
    tags: Optional[List[str]] = Field(default_factory=list, description="Lista di tag liberi")

class MetadataIA(BaseModel):
    """Metadati generati da un modello IA o tramite tecniche NLP"""
    subtitle: Optional[str] = Field(None, description="Sottotitolo dell'articolo")
    keywords: Optional[List[str]] = Field(None, description="Lista di parole chiave")
    category: Optional[List[str]] = Field(None, description="Lista di categorie")
    language: Optional[str] = Field(None, description="Lingua")
    summary: Optional[str] = Field(None, description="Breve sintesi dell'articolo")
    entities: Optional[List[str]] = Field(None, description="Entità rilevanti come persone, luoghi o organizzazioni (es. 'persona: Mario Rossi')")


class ArticleDocument(BaseModel):
    id: str = Field(..., description="UUID univoco dell'articolo (partition key)")
    blob_url: str = Field(..., description="URL del file grezzo su Azure Blob Storage")
    uploaded_at: datetime = Field(..., description="Timestamp ISO 8601 del caricamento")
    manual_metadata: Optional[ManualMetadata] = Field(
        None,
        description="Metadati inseriti manualmente dall'utente"
    )
    IA_metadata: Optional[MetadataIA] = Field(
        None,
    )



