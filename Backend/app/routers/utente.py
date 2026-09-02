from fastapi import APIRouter
from pydantic import BaseModel
from autentication.keycloack_service import addUtente, refresh_user_token

from autentication.keycloack_service import login_user

router = APIRouter(prefix="/utente", tags=["Autenticazione"])

# Modello per ricevere i dati dal Frontend
class UtenteRegistration(BaseModel):
    username: str
    email: str
    password: str

class UtenteLogin(BaseModel):
    username: str
    password: str

class PasswordResetRequest(BaseModel):
    email: str


class RefreshRequest(BaseModel):
    refresh_token: str

@router.post("/addUtente")
async def registra_utente(utente: UtenteRegistration):
    # Chiamiamo la funzione del servizio
    user_id = addUtente(
        username=utente.username,
        email=utente.email,
        password=utente.password
    )
    return {"message": "Utente registrato con successo", "user_id": user_id}


@router.post("/login")
async def login(utente: UtenteLogin):
    token_response = login_user(username=utente.username, password=utente.password)
    return token_response

@router.post("/refresh", summary="Genera un nuovo access token")
async def refresh_token_endpoint(request: RefreshRequest):
    return refresh_user_token(request.refresh_token)

