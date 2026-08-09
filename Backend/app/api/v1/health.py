from fastapi import FastAPI, APIRouter
#file per verificare se il server sta girando e risponde alle richieste
router = APIRouter()

@router.get("/health")
def health_check():
    return{
        "status": "ok",
        "message" : "Il Backend è correttamente configurato e attivo "
    }