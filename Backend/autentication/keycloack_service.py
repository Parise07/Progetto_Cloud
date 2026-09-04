"""
Servizio di autenticazione basato su Keycloak (OIDC / OAuth 2.0).

Il modulo copre tre responsabilità:
  - verifica dei token in ingresso (`get_current_user`), con cache locale del JWKS;
  - ciclo di vita della sessione (login, refresh, logout);
  - registrazione degli utenti tramite Admin API.

Gli errori di autenticazione restituiscono sempre un codice applicativo
(`AuthErrorCode`) nel corpo della risposta, così che il client possa distinguere
"token scaduto, rinnovalo in silenzio" da "sessione persa, rifai il login" e
automatizzare il refresh senza mostrare errori all'utente.
"""
import asyncio
import time

import httpx
from fastapi import Security, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt
from jose.exceptions import ExpiredSignatureError, JOSEError

from app.config import settings
from keycloak import KeycloakAdmin, KeycloakError, KeycloakConnectionError, KeycloakOpenID

security = HTTPBearer()


class AuthErrorCode:
    """Codici applicativi restituiti al client insieme al 401/503.

    Il client li usa per decidere l'azione: rinnovare il token in silenzio
    oppure terminare la sessione e mostrare la schermata di login.
    """
    TOKEN_EXPIRED = "TOKEN_EXPIRED"        # access token scaduto -> chiama /utente/refresh
    TOKEN_INVALID = "TOKEN_INVALID"        # token alterato o non riconosciuto -> logout
    REFRESH_EXPIRED = "REFRESH_EXPIRED"    # refresh scaduto o revocato -> logout
    INVALID_CREDENTIALS = "INVALID_CREDENTIALS"
    AUTH_UNAVAILABLE = "AUTH_UNAVAILABLE"  # Keycloak irraggiungibile -> riprovare più tardi


def _auth_error(code: str, message: str, status_code: int = status.HTTP_401_UNAUTHORIZED) -> HTTPException:
    """Costruisce l'eccezione di autenticazione con il relativo codice applicativo.

    Sul 401 viene incluso anche l'header `WWW-Authenticate` previsto dalla
    RFC 6750, per i client che preferiscono leggere l'header invece del corpo.
    """
    headers = None
    if status_code == status.HTTP_401_UNAUTHORIZED:
        headers = {"WWW-Authenticate": f'Bearer error="invalid_token", error_description="{code}"'}
    return HTTPException(
        status_code=status_code,
        detail={"code": code, "message": message},
        headers=headers,
    )


# --------------------------------------------------------------------------- #
# Client Keycloak
# --------------------------------------------------------------------------- #

# Il costruttore di KeycloakOpenID non effettua chiamate di rete: può restare
# a livello di modulo.
keycloak_openid = KeycloakOpenID(
    server_url=settings.KEYCLOAK_SERVER_URL,
    client_id=settings.KEYCLOAK_CLIENT_ID,
    realm_name=settings.KEYCLOAK_REALM,
    client_secret_key=settings.KEYCLOAK_CLIENT_SECRET,
)

# KeycloakAdmin invece si autentica già nel costruttore: viene creato al primo
# utilizzo, altrimenti l'API non parte se Keycloak non è ancora pronto (caso
# tipico su Azure Container Instances, dove i due container avviano insieme).
_keycloak_admin: KeycloakAdmin | None = None


def get_keycloak_admin() -> KeycloakAdmin:
    """Restituisce il client Admin, istanziandolo alla prima chiamata."""
    global _keycloak_admin
    if _keycloak_admin is None:
        try:
            _keycloak_admin = KeycloakAdmin(
                server_url=settings.KEYCLOAK_SERVER_URL,
                client_id="admin-cli",
                realm_name=settings.KEYCLOAK_REALM,
                user_realm_name=settings.KEYCLOAK_ADMIN_REALM,
                username=settings.KEYCLOAK_ADMIN_USERNAME,
                password=settings.KEYCLOAK_ADMIN_PASSWORD,
                verify=True,
            )
        except KeycloakError as e:
            print(f"Impossibile connettersi all'Admin API di Keycloak: {e}")
            raise _auth_error(
                AuthErrorCode.AUTH_UNAVAILABLE,
                "Server di autenticazione non raggiungibile.",
                status.HTTP_503_SERVICE_UNAVAILABLE,
            )
    return _keycloak_admin


# --------------------------------------------------------------------------- #
# Cache del JWKS (chiavi pubbliche del realm)
# --------------------------------------------------------------------------- #

_jwks_cache: dict | None = None
_jwks_fetched_at: float = 0.0
_jwks_lock = asyncio.Lock()

JWKS_URL = f"{settings.KEYCLOAK_SERVER_URL}/realms/{settings.KEYCLOAK_REALM}/protocol/openid-connect/certs"


async def _download_jwks() -> dict:
    """Scarica le chiavi pubbliche del realm da Keycloak."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(JWKS_URL)
            response.raise_for_status()
            return response.json()
    except httpx.HTTPError as e:
        print(f"Errore di connessione a Keycloak per il download del JWKS: {e}")
        raise _auth_error(
            AuthErrorCode.AUTH_UNAVAILABLE,
            "Impossibile contattare il server di autenticazione.",
            status.HTTP_503_SERVICE_UNAVAILABLE,
        )


async def get_keycloak_public_keys(force_refresh: bool = False) -> dict:
    """Restituisce il JWKS del realm, servendolo dalla cache quando possibile.

    Senza cache il JWKS verrebbe riscaricato ad ogni richiesta autenticata,
    aggiungendo un round-trip verso Keycloak e legando la latenza dell'API a
    quella dell'Identity Provider. La cache viene invalidata allo scadere del
    TTL oppure su richiesta esplicita, quando arriva un token firmato con un
    `kid` sconosciuto (segno che le chiavi del realm sono state ruotate).

    :param force_refresh: ignora la cache e riscarica le chiavi
    :return dict: il documento JWKS
    """
    global _jwks_cache, _jwks_fetched_at

    is_fresh = (
        _jwks_cache is not None
        and (time.monotonic() - _jwks_fetched_at) < settings.KEYCLOAK_JWKS_CACHE_TTL
    )
    if is_fresh and not force_refresh:
        return _jwks_cache

    # Il lock evita che N richieste concorrenti scarichino N volte lo stesso JWKS.
    async with _jwks_lock:
        # Un'altra coroutine potrebbe aver già aggiornato la cache mentre
        # attendevamo il lock: ricontrolliamo prima di uscire in rete.
        already_updated = (
            _jwks_cache is not None
            and (time.monotonic() - _jwks_fetched_at) < settings.KEYCLOAK_JWKS_CACHE_TTL
        )
        if already_updated and not force_refresh:
            return _jwks_cache

        _jwks_cache = await _download_jwks()
        _jwks_fetched_at = time.monotonic()
        return _jwks_cache


def _jwks_contains_kid(jwks: dict, kid: str) -> bool:
    """Verifica se il JWKS contiene la chiave con l'identificativo indicato."""
    return any(key.get("kid") == kid for key in jwks.get("keys", []))


# --------------------------------------------------------------------------- #
# Verifica del token in ingresso
# --------------------------------------------------------------------------- #

async def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security)) -> dict:
    """Verifica firma e validità dell'access token e ne restituisce i claim.

    Distingue esplicitamente il token scaduto (TOKEN_EXPIRED, il client può
    rinnovarlo) dal token non valido (TOKEN_INVALID, la sessione va chiusa):
    è questa distinzione a rendere possibile il refresh automatico lato client.
    """
    token = credentials.credentials

    try:
        kid = jwt.get_unverified_header(token).get("kid")
    except JOSEError:
        raise _auth_error(AuthErrorCode.TOKEN_INVALID, "Token non leggibile.")

    jwks = await get_keycloak_public_keys()
    if kid and not _jwks_contains_kid(jwks, kid):
        # Chiave sconosciuta: probabile rotazione delle chiavi del realm.
        jwks = await get_keycloak_public_keys(force_refresh=True)

    try:
        payload = jwt.decode(
            token,
            jwks,
            algorithms=["RS256"],  # L'algoritmo usato da Keycloak
            issuer=f"{settings.KEYCLOAK_SERVER_URL}/realms/{settings.KEYCLOAK_REALM}",
            options={"verify_aud": False},  # Keycloak popola `azp`, non `aud`, per i client pubblici
        )
    except ExpiredSignatureError:
        raise _auth_error(AuthErrorCode.TOKEN_EXPIRED, "Access token scaduto.")
    except JOSEError:
        # Copre sia JWTError (firma/claim non validi) sia JWKError (chiave assente).
        raise _auth_error(AuthErrorCode.TOKEN_INVALID, "Token non valido o alterato.")

    if settings.KEYCLOAK_VERIFY_AZP and payload.get("azp") != settings.KEYCLOAK_CLIENT_ID:
        raise _auth_error(AuthErrorCode.TOKEN_INVALID, "Token emesso per un client diverso.")

    return payload


# --------------------------------------------------------------------------- #
# Ciclo di vita della sessione
# --------------------------------------------------------------------------- #

def _normalize_token_response(raw: dict) -> dict:
    """Normalizza la risposta di Keycloak nel formato restituito al client.

    Espone in chiaro `expires_in` e `refresh_expires_in`: sono i valori con cui
    il client calcola quando rinnovare in anticipo, invece di attendere il 401.
    """
    return {
        "access_token": raw.get("access_token"),
        "refresh_token": raw.get("refresh_token"),
        "token_type": raw.get("token_type", "Bearer"),
        "expires_in": raw.get("expires_in"),
        "refresh_expires_in": raw.get("refresh_expires_in"),
        "session_state": raw.get("session_state"),
        "scope": raw.get("scope"),
    }


def addUtente(username: str, email: str, password: str):
    """Registra un nuovo utente su Keycloak e ne imposta la password."""
    admin = get_keycloak_admin()
    try:
        new_user = {
            "username": username,
            "email": email,
            "firstName": username,
            "lastName": "User",
            "enabled": True,
            "emailVerified": True,

        }
        # Chiamata al server Keycloak tramite l'oggetto admin
        user_id = admin.create_user(new_user)
        admin.set_user_password(user_id=user_id, password=password, temporary=False)
        print(f"Utente {username} creato con successo in Keycloak. ID: {user_id}")
        return user_id

    except KeycloakConnectionError as e:
        print(f"Keycloak irraggiungibile durante la registrazione: {e}")
        raise _auth_error(
            AuthErrorCode.AUTH_UNAVAILABLE,
            "Server di autenticazione non raggiungibile.",
            status.HTTP_503_SERVICE_UNAVAILABLE,
        )
    except KeycloakError as e:
        print(f"Errore durante la creazione dell'utente su Keycloak: {e}")
        # Se l'utente esiste già o c'è un errore, blocchiamo la richiesta HTTP
        raise HTTPException(status_code=400, detail="Impossibile creare l'utente. Potrebbe già esistere.")


def login_user(username: str, password: str) -> dict:
    """Autentica l'utente tramite Direct Access Grants e restituisce i token."""
    try:
        # Recupera il token da Keycloak usando il flusso "Direct Access"
        token = keycloak_openid.token(username, password)
        print(f"Utente {username} loggato con successo.")
        return _normalize_token_response(token)
    except KeycloakConnectionError as e:
        print(f"Keycloak irraggiungibile durante il login: {e}")
        raise _auth_error(
            AuthErrorCode.AUTH_UNAVAILABLE,
            "Server di autenticazione non raggiungibile.",
            status.HTTP_503_SERVICE_UNAVAILABLE,
        )
    except KeycloakError as e:
        print(f"Errore di login su Keycloak: {e}")
        raise _auth_error(AuthErrorCode.INVALID_CREDENTIALS, "Username o password non validi.")


def refresh_user_token(refresh_token: str) -> dict:
    """Rigenera l'access token a partire dal refresh token.

    Keycloak restituisce sempre anche un nuovo `refresh_token`: il client deve
    sovrascrivere entrambi i valori, non solo l'access token.

    :param refresh_token: il refresh token attualmente in possesso del client
    :return dict: la nuova coppia di token normalizzata
    """
    try:
        new_tokens = keycloak_openid.refresh_token(refresh_token)
        print("Token aggiornato con successo.")
        return _normalize_token_response(new_tokens)
    except KeycloakConnectionError as e:
        # Distinto dal refresh scaduto: qui la sessione è probabilmente ancora
        # valida, il client deve riprovare invece di sloggare l'utente.
        print(f"Keycloak irraggiungibile durante il refresh: {e}")
        raise _auth_error(
            AuthErrorCode.AUTH_UNAVAILABLE,
            "Server di autenticazione non raggiungibile.",
            status.HTTP_503_SERVICE_UNAVAILABLE,
        )
    except KeycloakError as e:
        print(f"Errore durante il refresh del token: {e}")
        raise _auth_error(
            AuthErrorCode.REFRESH_EXPIRED,
            "Refresh token non valido o scaduto. Effettuare di nuovo il login.",
        )


def logout_user(refresh_token: str) -> dict:
    """Termina la sessione su Keycloak revocando il refresh token.

    L'operazione è idempotente: se il token è già scaduto o revocato il logout
    viene comunque considerato riuscito, perché dal punto di vista del client il
    risultato desiderato (sessione chiusa) è raggiunto.
    """
    try:
        keycloak_openid.logout(refresh_token)
        return {"status": "success", "message": "Sessione terminata."}
    except KeycloakError as e:
        print(f"Logout su Keycloak non riuscito (token già invalido?): {e}")
        return {"status": "success", "message": "Sessione già terminata."}
