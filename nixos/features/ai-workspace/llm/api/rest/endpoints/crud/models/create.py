from fastapi import APIRouter, HTTPException
from ...schemas.models import ModelPull
import requests

router = APIRouter()
OLLAMA_API = "http://localhost:11434/api"

@router.post("/pull")
async def pull_model(model: ModelPull):
    """Neues Modell herunterladen"""
    try:
        response = requests.post(f"{OLLAMA_API}/pull", json={
            "name": model.name,
            "insecure": model.insecure
        })
        if response.status_code == 200:
            return {"status": "success", "message": f"Model {model.name} pulled successfully"}
        raise HTTPException(status_code=response.status_code)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))