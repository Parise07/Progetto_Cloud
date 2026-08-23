from fastapi import Security, HTTPException, status, security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
import urllib.request
import json
from app.config import settings
from keycloak import KeycloakAdmin

keycloak_admin = KeycloakAdmin(
    server_url= settings.KEYCLOAK_SERVER_URL,
    client_id= settings.KEYCLOAK_CLIENT_ID,
    realm_name= settings.KEYCLOAK_REALM
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
        # 2. Scarichiamo le chiavi da Keycloak
        jwks = get_keycloak_public_keys()
        # 3. Leggiamo e verifichiamo il token
        payload = jwt.decode(
            token,
            jwks,
            algorithms=["RS256"],  # L'algoritmo usato da Keycloak
            issuer=f"{settings.KEYCLOAK_SERVER_URL}/realms/{settings.KEYCLOAK_REALM}",
            options={"verify_aud": False}  # Disattivato per semplificare i test locali
        )

        # 4. Se il codice arriva qui, significa che il token è VERO e NON È SCADUTO!
        # Restituiamo i dati dell'utente (il payload) in modo che le rotte sappiano chi è loggato
        return payload

    except JWTError:
        # Se il token è finto, scaduto o alterato, blocchiamo la richiesta
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token non valido, alterato o scaduto.",
            headers={"WWW-Authenticate": "Bearer"},
        )