from fastapi import APIRouter, HTTPException
from ...schemas.chat import ChatRequest, ChatResponse
import requests
import logging

logger = logging.getLogger(__name__)
router = APIRouter()
OLLAMA_API = "http://localhost:11434/api"

@router.post("/", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Chat mit einem Modell"""
    try:
        response = requests.post(f"{OLLAMA_API}/chat", json={
            "model": request.model,
            "messages": [msg.dict() for msg in request.messages]
        })
        return response.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))