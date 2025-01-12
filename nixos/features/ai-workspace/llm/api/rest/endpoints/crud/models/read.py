from fastapi import APIRouter, HTTPException
from ...schemas.models import ModelInfo
from typing import List
import requests

router = APIRouter()
OLLAMA_API = "http://localhost:11434/api"

@router.get("/", response_model=List[ModelInfo])
async def list_models():
    """Liste alle verfügbaren Modelle"""
    try:
        response = requests.get(f"{OLLAMA_API}/tags")
        if response.status_code == 200:
            return response.json().get("models", [])
        raise HTTPException(status_code=response.status_code)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{model_name}/info")
async def model_info(model_name: str):
    """Get detailed model information"""
    try:
        response = requests.post(f"{OLLAMA_API}/show", json={"name": model_name})
        if response.status_code == 200:
            return response.json()
        raise HTTPException(status_code=response.status_code)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))