from fastapi import APIRouter, HTTPException
import requests

OLLAMA_API = "http://localhost:11434/api"
router = APIRouter()

@router.get("/")
async def list_custom_models():
    """List all customized models"""
    try:
        response = requests.get(f"{OLLAMA_API}/tags")
        if response.status_code == 200:
            return {
                "status": "success",
                "models": response.json().get("models", [])
            }
        raise HTTPException(status_code=response.status_code)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))