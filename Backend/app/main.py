from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers.articles import router as articles_router
from app.routers.search import router as search
from app.routers.utente import router as utente_router
from app.services.search_service import setup_ai_search_index


@asynccontextmanager
async def lifespan(app: FastAPI):
    # --- FASE DI AVVIO ---
    print("🚀 Avvio dell'applicazione. Controllo l'infrastruttura...")
    await setup_ai_search_index()

    yield  # Qui l'applicazione è in funzione e accetta richieste

    # --- FASE DI SPEGNIMENTO ---
    print("🛑 Spegnimento dell'applicazione in corso...")

app = FastAPI(
    title="Sistema RAG — NewsArchive",
    description="Backend API per l'archiviazione e ricerca intelligente di articoli. Vai su /docs per la documentazione Swagger.",
    version="1.0",
    lifespan=lifespan
)

# Configurazione CORS (specifica quali domini esterni sono autorizzati ad accedere)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# test CI

app.include_router(articles_router, prefix="", tags=["Articles"])
app.include_router(search, prefix="", tags=["Search"])
app.include_router(utente_router)



@app.get("/")
def root():
    return {"message": "Benvenuto nelle API di NewsArchive RAG. Vai su /docs per la documentazione."}