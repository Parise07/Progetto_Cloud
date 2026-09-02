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