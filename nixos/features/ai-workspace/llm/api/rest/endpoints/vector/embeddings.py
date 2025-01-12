# llm/api/rest/endpoints/embeddings.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import requests
from pymilvus import connections, Collection, utility

router = APIRouter(prefix="/embeddings", tags=["embeddings"])

class EmbeddingRequest(BaseModel):
    text: str
    model: str = "llama2"  # Default model
    collection: Optional[str] = "default"

class SearchRequest(BaseModel):
    query: str
    collection: str
    limit: int = 5
    min_score: float = 0.7

@router.post("/generate")
async def generate_embedding(request: EmbeddingRequest):
    """Generate embeddings from text"""
    try:
        # Get embedding from Ollama
        response = requests.post(
            "http://localhost:11434/api/embeddings",
            json={"model": request.model, "prompt": request.text}
        )
        
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code)
            
        embedding_data = response.json()
        
        # Store in Milvus if collection specified
        if request.collection:
            connections.connect("default", host="localhost", port="19530")
            collection = Collection(request.collection)
            
            # Insert embedding
            collection.insert([
                [request.text],  # Original text
                [embedding_data["embedding"]]  # Vector
            ])
            
        return {
            "status": "success",
            "embedding": embedding_data["embedding"],
            "stored": bool(request.collection)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/search")
async def search_similar(request: SearchRequest):
    """Search for similar vectors"""
    try:
        # Connect to Milvus
        connections.connect("default", host="localhost", port="19530")
        
        # Get collection
        if not utility.has_collection(request.collection):
            raise HTTPException(status_code=404, detail=f"Collection {request.collection} not found")
            
        collection = Collection(request.collection)
        collection.load()
        
        # Generate query embedding
        embed_response = requests.post(
            "http://localhost:11434/api/embeddings",
            json={"model": "llama2", "prompt": request.query}
        )
        
        if embed_response.status_code != 200:
            raise HTTPException(status_code=embed_response.status_code)
            
        query_vector = embed_response.json()["embedding"]
        
        # Search
        search_params = {
            "metric_type": "L2",
            "params": {"nprobe": 10},
        }
        
        results = collection.search(
            data=[query_vector],
            anns_field="vector",
            param=search_params,
            limit=request.limit,
            output_fields=["text"]
        )
        
        # Filter by score and format results
        similar_docs = []
        for hits in results:
            for hit in hits:
                if hit.score >= request.min_score:
                    similar_docs.append({
                        "text": hit.entity.get("text"),
                        "score": hit.score
                    })
        
        return {
            "query": request.query,
            "results": similar_docs
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))