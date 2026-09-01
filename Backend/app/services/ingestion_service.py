import io
import json
from docx import Document
import PyPDF2

def extract_text_from_file(file_bytes: bytes, filename: str)-> str:
    """Funzione che estrae il testo da un file avente una delle estensioni ammesse """
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
