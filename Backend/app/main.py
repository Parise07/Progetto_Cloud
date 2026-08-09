from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.health import router as health_router
app = FastAPI(
    title="Sistema Rag",
    description= "Primo test per ceck settaggio Backend",
    version="1.0"
)

# configurazione CORS(per specificare quali  domini esterni sono autorizzati ad accedere)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router, prefix="/api/v1" ,tags=["health"])

@app.get("/")
def root():
    return {"message": "Benvenuto nelle API di NewsArchive RAG. Vai su /docs per la documentazione."}