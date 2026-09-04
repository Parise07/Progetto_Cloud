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
    """
        Endpoint per la registrazione di un nuovo utente su Keycloak.
        :param utente: Modello Pydantic contenente i dati di registrazione (username, email, password).
        :return dict: Un dizionario contenente un messaggio di successo e lo user_id generato da Keycloak.
    """
    user_id = addUtente(
        username=utente.username,
        email=utente.email,
        password=utente.password
    )
    return {"message": "Utente registrato con successo", "user_id": user_id}


@router.post("/login", response_model=TokenResponse, summary="Autentica l'utente")
async def login(utente: UtenteLogin):
    """
        Endpoint per l'autenticazione dell'utente. Invia le credenziali a Keycloak
        e restituisce i token di accesso e refresh.
        :param utente: Modello Pydantic contenente le credenziali (username e password).
        :return TokenResponse: Modello Pydantic con access_token, refresh_token e relativi tempi di scadenza.
    """
    return login_user(username=utente.username, password=utente.password)


@router.post("/refresh", response_model=TokenResponse, summary="Genera un nuovo access token")
async def refresh_token_endpoint(request: RefreshRequest):
    """
    Endpoint per rinnovare la coppia di token (access e refresh).
    In caso di fallimento risponde 401 con codice `REFRESH_EXPIRED`: il client
    deve terminare la sessione. Un 503 con `AUTH_UNAVAILABLE` indica invece un
    problema temporaneo di Keycloak.
    :param request: Modello Pydantic contenente il refresh_token attuale.
    :return TokenResponse: Modello Pydantic con i nuovi token generati.
    """
    return refresh_user_token(request.refresh_token)


@router.post("/logout", summary="Termina la sessione")
async def logout(request: RefreshRequest):
    """
        Endpoint per terminare la sessione dell'utente.
        Revoca il refresh token su Keycloak, chiudendo la sessione lato server.

        :param request: Modello Pydantic contenente il refresh_token da invalidare.
        :return dict: Risposta dalla funzione di servizio che conferma l'avvenuto logout.
    """
    return logout_user(request.refresh_token)


@router.get("/me", summary="Profilo dell'utente autenticato")
async def me(current_user: dict = Depends(get_current_user)):
    """
    Endpoint protetto che restituisce i dati dell'utente corrente validandone l'access token.
    Utilizzato dal client all'avvio per verificare se la sessione salvata è ancora valida.
    :param current_user: Dizionario con i dati decodificati dell'utente, iniettato dalla
                         dipendenza 'get_current_user' dopo la convalida del token.
    :return dict: Dizionario contenente user_id (sub), username, email e scadenza token (exp).
    """
    return {
        "user_id": current_user.get("sub"),
        "username": current_user.get("preferred_username"),
        "email": current_user.get("email"),
        "expires_at": current_user.get("exp"),
    }
