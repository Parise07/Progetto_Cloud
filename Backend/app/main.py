from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers.articles import router as articles_router
from app.routers.search import router as search
app = FastAPI(
    title="Sistema RAG — NewsArchive",
    description="Backend API per l'archiviazione e ricerca intelligente di articoli. Vai su /docs per la documentazione Swagger.",
    version="1.0"
)

# Configurazione CORS (specifica quali domini esterni sono autorizzati ad accedere)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(articles_router, prefix="", tags=["Articles"])
app.include_router(search, prefix="", tags=["Search"])


@app.get("/")
def root():
    return {"message": "Benvenuto nelle API di NewsArchive RAG. Vai su /docs per la documentazione."}