from fastapi import APIRouter, HTTPException,status
from app.services.cosmos_service import search_by_keywords
from app.models.chunk import RagSearchQuery, GenericSearchQuery
from app.services.ai_service import generate_embedding_for_chunks, generate_rag_aswer
from app.services.search_service import search_relevant_chunks

router = APIRouter(prefix="/search", tags=["Search"])



@router.post("/rag")
async def search_rag_articles(query: RagSearchQuery):
    if query.question is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    # 1 embedding della query
    query_embedding = await  generate_embedding_for_chunks([query.question])
    question = query_embedding[0]

    #2 estraiamo i chunk rilevanti
    relevant_chunks = await  search_relevant_chunks(question)
    if not relevant_chunks:
        return {
            "question": query.question,
            "answer": "Non ho trovato documenti pertinenti alla tua domanda nel nostro archivio.",
            "sources": []
        }
    answer= await generate_rag_aswer(relevant_chunks = relevant_chunks, question = query.question)

    return {
        "question": query.question,
        "answer": answer,
        "relevant_chunks": relevant_chunks
    }

@router.post("/generic")
async def search_generic_articles(query: GenericSearchQuery):
    if not query.keyword or not query.keyword.strip() == "":
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