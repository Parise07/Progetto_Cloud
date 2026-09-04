import io
import json
from docx import Document
import PyPDF2

def extract_text_from_file(file_bytes: bytes, filename: str)-> str:
    '''
        Funzione che riceve il contenuto di un file sotto forma di byte ed estrae il testo
        al suo interno in base all'estensione del file stesso. Supporta la lettura e
        l'estrazione da formati TXT, MD, JSON, DOCX e PDF.
        :param file_bytes: Il contenuto del file grezzo in formato bytes, letto direttamente
                           dall'upload o dallo storage.
        :param filename: Il nome completo del file (inclusa l'estensione), utilizzato per
                         identificare il formato e applicare la corretta logica di estrazione.
        :return: Una stringa contenente tutto il testo estratto dal documento. Solleva
                 un'eccezione ValueError se il formato del file non è tra quelli supportati.
    '''
    extension = filename.split(".")[-1].lower()
    if extension in ['txt','md']:
        return file_bytes.decode("utf-8")
    elif extension == 'json':
        data = json.loads(file_bytes.decode("utf-8"))
        return json.dumps(data)
    elif extension == 'docx':
        doc = Document(io.BytesIO(file_bytes))
        text = '\n'.join([para.text for para in doc.paragraphs])
        return text
    elif extension == 'pdf':
        pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_bytes))
        text = ''
        for page in pdf_reader.pages:
            text += page.extract_text()
        return text
    else:
        raise ValueError(f"Formato file non supportato: {extension}")
