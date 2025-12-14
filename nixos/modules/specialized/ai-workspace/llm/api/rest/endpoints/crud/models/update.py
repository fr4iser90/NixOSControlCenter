from fastapi import APIRouter, HTTPException
import requests

router = APIRouter()
OLLAMA_API = "http://localhost:11434/api"

@router.post("/{model_name}/copy")
async def copy_model(model_name: str, new_name: str):
    """Copy/Create a model variant"""
    try:
        response = requests.post(f"{OLLAMA_API}/copy", json={
            "source": model_name,
            "destination": new_name
        })
        if response.status_code == 200:
            return {"status": "success", "message": f"Model {model_name} copied to {new_name}"}
        raise HTTPException(status_code=response.status_code)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))