from fastapi import APIRouter, HTTPException
import requests

router = APIRouter()
OLLAMA_API = "http://localhost:11434/api"

@router.delete("/{model_name}")
async def delete_model(model_name: str):
    """Modell löschen"""
    try:
        response = requests.delete(f"{OLLAMA_API}/delete", json={"name": model_name})
        if response.status_code == 200:
            return {"status": "success", "message": f"Model {model_name} deleted"}
        raise HTTPException(status_code=response.status_code)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))