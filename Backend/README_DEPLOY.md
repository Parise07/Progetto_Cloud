# Procedura per deploiare il backend 

Prima di iniziare la procedura stare attenti ai nomi e ai comandi bash, pochè avendo particolari (lettere maiuscole e punti) potrebbero essere causa di eventuali crash nella procedura.
## Fase 1

### Creare il Dockerfile 
All'interno della cartella principale del tuo backend (esattamente dove si trova il file requirements.txt), crea un nuovo file e chiamalo Dockerfile (con la D maiuscola e senza alcuna estensione come .txt o .py).
Copia e incolla questo contenuto al suo interno:
```
# 1. Usa l'immagine ufficiale di Python basata su un sistema Linux leggero
FROM python:3.10-slim

# 2. Imposta la directory di lavoro all'interno del container
WORKDIR /app

# 3. Copia il file delle dipendenze per sfruttare la cache di Docker
COPY requirements.txt .

# 4. Installa le dipendenze Python necessarie
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copia tutto il resto del codice backend nella cartella /app
COPY . .

# 6. Esponi la porta 8000 (quella usata da FastAPI)
EXPOSE 8000

# 7. Comando di avvio del server FastAPI
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```
# Crea il file .dockerignore
Nella stessa cartella, crea un altro file chiamato `.dockerignore` (nota il punto iniziale). Questo file è cruciale per evitare che i tuoi segreti (come il file .env) o la cartella dell'ambiente virtuale (venv) vengano copiati per sbaglio all'interno dell'immagine pubblica.
Incolla questo contenuto:
```
venv/
.env
__pycache__/
*.pyc
.git/
.vscode/
.idea/
```
# Costruisci l'immagine (Build)
Ora che i file esistono, apri il terminale nella cartella del backend (assicurandoti che Docker Desktop sia aperto) e lancia il comando per costruire l'immagine. Sostituisci tuousername con il tuo reale username di Docker Hub:
```
docker build -t tuousername/newsarchive-backend:latest .
```
# Testa il container in locale 
Avvia il container appena creato passando il file .env in modo che il codice Python abbia accesso ai database:
```
docker run -p 8000:8000 --env-file .env tuousername/newsarchive-backend:latest
```
Se vedi i log di Uvicorn che partono, tutto funziona! Ferma il server premendo CTRL+C nel terminale.
# Pubblichiamo su Docker Hub (Push)
Ora carichiamo l'immagine sul cloud in modo che Azure possa scaricarla successivamente. Accedi al tuo account da terminale ed effettua il push:
```
docker login
docker push tuousername/newsarchive-backend:latest
```
## Fase 2 

# Creazione del file Bicep per i container 
Nella cartella dove tieni i tuoi file infrastrutturali (dove hai main.bicep), crea un nuovo file chiamato containers.bicep.

Questo script creerà un Azure Container Group. La genialità di questa risorsa è che permette di far girare sia il tuo Backend che Keycloak all'interno della stessa macchina logica, condividendo lo stesso indirizzo IP pubblico ma esponendo porte diverse (8000 e 8080).

Incolla questo codice al suo interno:
```
@description('Location delle risorse (es. italynorth)')
param location string = resourceGroup().location

@description('Un prefisso unico per il link pubblico')
param dnsNameLabel string = 'newsarchive-api-${uniqueString(resourceGroup().id)}'

// Parametri segreti che passeremo dal terminale
@secure()
param storageConnectionString string
@secure()
param cosmosEndpoint string
@secure()
param cosmosKey string
@secure()
param searchEndpoint string
@secure()
param searchKey string
@secure()
param openAiEndpoint string
@secure()
param openAiKey string

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: 'newsarchive-containers'
  location: location
  properties: {
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      ports: [
        { protocol: 'TCP', port: 8000 } // FastAPI
        { protocol: 'TCP', port: 8080 } // Keycloak
      ]
      dnsNameLabel: dnsNameLabel
    }
    containers: [
      {
        name: 'fastapi-backend'
        properties: {
          // La tua immagine caricata su Docker Hub!
          image: 'parise09/newsarchive-backend:latest'
          ports: [ { port: 8000 } ]
          resources: {
            requests: { cpu: 1, memoryInGB: 2 }
          }
          environmentVariables: [
            { name: 'TEST_MODE', value: 'False' }
            { name: 'AZURE_STORAGE_CONNECTION_STRING', secureValue: storageConnectionString }
            { name: 'COSMOS_ENDPOINT', value: cosmosEndpoint }
            { name: 'COSMOS_KEY', secureValue: cosmosKey }
            { name: 'AZURE_SEARCH_ENDPOINT', value: searchEndpoint }
            { name: 'AZURE_SEARCH_ADMIN_KEY', secureValue: searchKey }
            { name: 'AZURE_OPENAI_ENDPOINT', value: openAiEndpoint }
            { name: 'AZURE_OPENAI_KEY', secureValue: openAiKey }
            // Keycloak si trova nello stesso "pod", quindi si parlano su localhost!
            { name: 'KEYCLOAK_SERVER_URL', value: 'http://localhost:8080' }
          ]
        }
      }
      {
        name: 'keycloak-iam'
        properties: {
          // L'immagine ufficiale di Keycloak
          image: 'quay.io/keycloak/keycloak:24.0.2'
          command: ['/opt/keycloak/bin/kc.sh', 'start-dev']
          ports: [ { port: 8080 } ]
          resources: {
            requests: { cpu: 1, memoryInGB: 2 }
          }
          environmentVariables: [
            { name: 'KEYCLOAK_ADMIN', value: 'admin' }
            { name: 'KEYCLOAK_ADMIN_PASSWORD', secureValue: 'Admin123!' }
          ]
        }
      }
    ]
  }
}

// Questo ti stamperà il link finale a cui collegare la tua app Flutter
output fqdn string = containerGroup.properties.ipAddress.fqdn
```
## Prepara il file dei parametri
Dato che hai molte chiavi segrete, lanciarle tutte tramite riga di comando è scomodo. Crea un file chiamato containers.parameters.json nella stessa cartella e compila i campi vuoti copiandoli dal tuo file .env:
```
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "storageConnectionString": { "value": "INCOLLA_QUI_IL_VALORE" },
    "cosmosEndpoint": { "value": "INCOLLA_QUI_IL_VALORE" },
    "cosmosKey": { "value": "INCOLLA_QUI_IL_VALORE" },
    "searchEndpoint": { "value": "INCOLLA_QUI_IL_VALORE" },
    "searchKey": { "value": "INCOLLA_QUI_IL_VALORE" },
    "openAiEndpoint": { "value": "INCOLLA_QUI_IL_VALORE" },
    "openAiKey": { "value": "INCOLLA_QUI_IL_VALORE" }
  }
}
```
# Passiamo ad eseguirlo su Azure 
Apri il terminale ed esegui il comando per avviare la creazione dei tuoi container sul cloud. (Assicurati di usare il nome corretto del tuo Resource Group, suppongo progettocloud-rg):
```
az deployment group create --resource-group progettocloud-rg --template-file containers.bicep --parameters containers.parameters.json
```