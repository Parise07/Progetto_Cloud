from fastapi import APIRouter, Depends
from pydantic import BaseModel

from autentication.keycloack_service import (
    addUtente,
    get_current_user,
    login_user,
    logout_user,
    refresh_user_token,
)

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


class TokenResponse(BaseModel):
    """Risposta di login e refresh.

    `expires_in` e `refresh_expires_in` sono in secondi e servono al client per
    programmare il rinnovo *prima* della scadenza, evitando all'utente di
    incappare in un 401.
    """
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int | None = None
    refresh_expires_in: int | None = None
    session_state: str | None = None
    scope: str | None = None


@router.post("/addUtente")
async def registra_utente(utente: UtenteRegistration):
    # Chiamiamo la funzione del servizio
    user_id = addUtente(
        username=utente.username,
        email=utente.email,
        password=utente.password
    )
    return {"message": "Utente registrato con successo", "user_id": user_id}


@router.post("/login", response_model=TokenResponse, summary="Autentica l'utente")
async def login(utente: UtenteLogin):
    return login_user(username=utente.username, password=utente.password)


@router.post("/refresh", response_model=TokenResponse, summary="Genera un nuovo access token")
async def refresh_token_endpoint(request: RefreshRequest):
    """Rinnova la coppia di token.

    In caso di fallimento risponde 401 con codice `REFRESH_EXPIRED`: il client
    deve terminare la sessione. Un 503 con `AUTH_UNAVAILABLE` indica invece un
    problema temporaneo di Keycloak, per cui conviene riprovare.
    """
    return refresh_user_token(request.refresh_token)


@router.post("/logout", summary="Termina la sessione")
async def logout(request: RefreshRequest):
    """Revoca il refresh token su Keycloak, chiudendo la sessione lato server."""
    return logout_user(request.refresh_token)


@router.get("/me", summary="Profilo dell'utente autenticato")
async def me(current_user: dict = Depends(get_current_user)):
    """Restituisce i dati dell'utente corrente validandone l'access token.

    Il client la usa all'avvio per capire se la sessione salvata è ancora
    utilizzabile, senza dover sondare una rotta di dominio.
    """
    return {
        "user_id": current_user.get("sub"),
        "username": current_user.get("preferred_username"),
        "email": current_user.get("email"),
        "expires_at": current_user.get("exp"),
    }
