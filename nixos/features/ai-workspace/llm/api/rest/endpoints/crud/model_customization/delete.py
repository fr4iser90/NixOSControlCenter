from fastapi import APIRouter, HTTPException
import requests

OLLAMA_API = "http://localhost:11434/api"
router = APIRouter()

@router.delete("/{model_name}")
async def delete_custom_model(model_name: str):
    """Delete a customized model"""
    try:
        response = requests.delete(f"{OLLAMA_API}/delete", json={
            "name": model_name
        })
        
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code)
            
        return {
            "status": "success", 
            "message": f"Model {model_name} deleted"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))