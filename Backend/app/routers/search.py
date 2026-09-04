from fastapi import APIRouter, HTTPException, status, Depends
from app.config import settings
from app.services.cosmos_service import search_by_keywords, get_article_by_id
from app.models.chunk import RagSearchQuery, GenericSearchQuery, ArticleChatQuery
from app.services.ai_service import generate_embedding_for_chunks, generate_rag_answer, generate_chat_answer
from app.services.search_service import search_relevant_chunks, search_relevant_chunks_chat
from autentication.keycloack_service import get_current_user

router = APIRouter(prefix="/search", tags=["Search"])



@router.post("/rag")
async def search_rag_articles(query: RagSearchQuery, current_user: dict = Depends(get_current_user)):
    """
        Endpoint asincrono per la ricerca RAG (Retrieval-Augmented Generation) nell'archivio articoli.
        Richiede l'autenticazione dell'utente, poiché consuma crediti per embedding e completion
        su Azure OpenAI. Converte la domanda in vettori, recupera i frammenti più pertinenti,
        genera la risposta AI e restituisce le fonti complete.
        :param query: Modello Pydantic contenente la domanda dell'utente (question) e opzionalmente i parametri di limite (top_k).
        :param current_user: Dizionario con i dati dell'utente autenticato, iniettato tramite dipendenza.
        :return dict: Dizionario con la domanda originale, la risposta generata (answer) e la lista
                      degli articoli completi usati come fonti (relevant_chunks), senza duplicati.
    """
    if query.question is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    query_embedding = await  generate_embedding_for_chunks([query.question])
    question = query_embedding[0]

    relevant_chunks = await search_relevant_chunks(
        question, top_k=query.top_k or settings.RAG_TOP_K
    )
    if not relevant_chunks:
        return {
            "question": query.question,
            "answer": "Non ho trovato documenti pertinenti alla tua domanda nel nostro archivio.",
            "relevant_chunks": []
        }
    answer= await generate_rag_answer(relevant_chunks = relevant_chunks, question = query.question)


    article_ids = []
    for chunk in relevant_chunks:
        a_id = chunk.get("article_id")
        if a_id and a_id not in article_ids:
            article_ids.append(a_id)

    full_articles = []
    for a_id in article_ids:
        article_doc = get_article_by_id(a_id)
        if article_doc:
            full_articles.append(article_doc)

    return {
        "question": query.question,
        "answer": answer,
        "relevant_chunks": full_articles
    }

@router.post("/generic")
async def search_generic_articles(query: GenericSearchQuery):
    """
        Endpoint per la ricerca testuale generica tramite parole chiave.
        Rotta volutamente pubblica e non autenticata (utilizzata ad esempio dalla home).
        Interroga direttamente Cosmos DB senza consumare servizi AI a consumo.
        :param query: Modello Pydantic contenente le parole chiave da ricercare (keyword).
        :return dict: Dizionario con le keyword cercate, un messaggio descrittivo e la
                      lista dei documenti trovati nel database.
        """
    if not query.keyword or  query.keyword.strip() == "":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    results = search_by_keywords(query.keyword)
    if not results:
        return {
            "keywords": query.keyword,
            "message" : "Nessuna corrispondenza trovata",
            "results": []
        }
    return {
        "keywords": query.keyword,
        "message": f"Trovate {len(results)} corrispondenze ",
        "results": results
    }

@router.post("/article-chat")
async def chat_articles(query: ArticleChatQuery, current_user: dict = Depends(get_current_user)):
    """
        Endpoint asincrono per la chat contestuale relativa all'articolo attualmente in lettura.
        Richiede autenticazione. Recupera prioritariamente i frammenti dell'articolo in esame
        e, secondariamente, quelli dal resto dell'archivio, fornendo all'LLM un contesto misto.
        :param query: Modello Pydantic con la domanda e l'ID dell'articolo corrente (current_article_id).
        :param current_user: Dizionario con i dati dell'utente autenticato, iniettato tramite dipendenza.
        :return dict: Dizionario contenente esclusivamente la risposta testuale (answer) dell'AI.
    """
    if not query.question:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    query_embedding = await generate_embedding_for_chunks([query.question])
    question = query_embedding[0]
    own_chunks  = await search_relevant_chunks_chat(question,top_k=4,article_id= query.current_article_id)

    global_chunks = await search_relevant_chunks(question, top_k=3)
    other_chunks = [c for c in global_chunks if c.get("article_id") != query.current_article_id]

    relevant_chunks = own_chunks + other_chunks

    if not relevant_chunks:
        return {
            "answer": "Non ho trovato altri riferimenti nel database per aiutarti con questa domanda."
        }
    answer= await generate_chat_answer(relevant_chunks = relevant_chunks, question = query.question, current_article_id = query.current_article_id)
    return {
        "answer": answer
    }
