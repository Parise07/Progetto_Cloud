from fastapi import Security, HTTPException, status, security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
import urllib.request
import json
from app.config import settings
from keycloak import KeycloakAdmin, KeycloakError, KeycloakOpenID


keycloak_admin = KeycloakAdmin(
    server_url= settings.KEYCLOAK_SERVER_URL,
    client_id= "admin-cli",
    realm_name= settings.KEYCLOAK_REALM,
    user_realm_name="master",
    username="admin",
    password="admin",
    verify = True
)

keycloak_openid = KeycloakOpenID(
    server_url=settings.KEYCLOAK_SERVER_URL,
    client_id=settings.KEYCLOAK_CLIENT_ID,
    realm_name=settings.KEYCLOAK_REALM
)

security = HTTPBearer()



def get_keycloak_public_keys():
    ''' funzione che scarica le chiavi pubbliche e verifica matematicamente che il token
     non sia stato modificato'''
    url = f"{settings.KEYCLOAK_SERVER_URL}/realms/{settings.KEYCLOAK_REALM}/protocol/openid-connect/certs"
    try:
        with urllib.request.urlopen(url) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        print(f"Errore di connessione a Keycloak: {e}")
        raise HTTPException(status_code=500, detail="Impossibile contattare il server di autenticazione")

async def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security)):
    ''' verifica la correttezza del token '''
    token = credentials.credentials

    try:
        jwks = get_keycloak_public_keys()
        payload = jwt.decode(
            token,
            jwks,
            algorithms=["RS256"],  # L'algoritmo usato da Keycloak
            issuer=f"{settings.KEYCLOAK_SERVER_URL}/realms/{settings.KEYCLOAK_REALM}",
            options={"verify_aud": False}  # Disattivato per semplificare i test locali
        )
        return payload

    except JWTError:
        # Se il token è finto, scaduto o alterato, blocchiamo la richiesta
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token non valido, alterato o scaduto.",
            headers={"WWW-Authenticate": "Bearer"},
        )


def addUtente(username: str, email: str, password: str):

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
        user_id = keycloak_admin.create_user(new_user)
        keycloak_admin.set_user_password(user_id=user_id, password=password, temporary=False)
        print(f"Utente {username} creato con successo in Keycloak. ID: {user_id}")
        return user_id

    except KeycloakError as e:
        print(f"Errore durante la creazione dell'utente su Keycloak: {e}")
        # Se l'utente esiste già o c'è un errore, blocchiamo la richiesta HTTP
        raise HTTPException(status_code=400, detail="Impossibile creare l'utente. Potrebbe già esistere.")


def login_user(username: str, password: str):
    """
    Invia username e password a Keycloak e restituisce i token JWT.
    """
    try:
        # Recupera il token da Keycloak usando il flusso "Direct Access"
        token = keycloak_openid.token(username, password)
        print(f"Utente {username} loggato con successo.")
        return token
    except KeycloakError as e:
        print(f"Errore di login su Keycloak: {e}")
        raise HTTPException(status_code=401, detail="Username o password non validi")


def refresh_user_token(refresh_token: str):
    """
    Metodo che ha il compito di rigenerare l'access_token dato il suo refresh token
    :parameter refresh_token str:
    """
    try:
        new_tokens = keycloak_openid.refresh_token(refresh_token)
        print("Token aggiornato con successo in background.")
        return new_tokens
    except KeycloakError as e:
        print(f"Errore durante il refresh del token: {e}")
        raise HTTPException(status_code=401, detail="Refresh token non valido o scaduto. Effettuare di nuovo il login.")

