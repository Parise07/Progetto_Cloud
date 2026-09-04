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
    """Ricerca RAG: richiede l'autenticazione.

    L'endpoint consuma embedding e completion di Azure OpenAI, quindi il
    controllo va fatto prima di generare la risposta e non lato client.
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

    # I chunk arrivano ordinati per rilevanza e piu' chunk possono appartenere
    # allo stesso articolo: si eliminano i duplicati conservando l'ordine, cosi'
    # le fonti restano mostrate dalla piu' pertinente alla meno pertinente.
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
    """Ricerca per parole chiave: volutamente pubblica.

    E' la ricerca della home, usata anche dagli utenti non autenticati
    (`main.dart`, `_performSearch`), e non consuma servizi a consumo.
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
    """Chat sull'articolo in lettura: richiede l'autenticazione.

    Come per /rag, il vincolo di login mostrato dalla UI viene ora applicato
    anche lato server, prima di chiamare Azure OpenAI.
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
