from fastapi import APIRouter, HTTPException
from ...schemas.model_customization import ModelTemplateConfig 
import requests

OLLAMA_API = "http://localhost:11434/api"
router = APIRouter()

@router.post("/")
async def create_model_template(config: ModelTemplateConfig):
    """Create a new model with custom template and behavior"""
    try:
        modelfile = f"""
        FROM {config.base_model}
        
        SYSTEM "{config.system_prompt}"
        
        TEMPLATE "{config.template}"
        """
        
        response = requests.post(f"{OLLAMA_API}/create", json={
            "name": config.custom_name,
            "modelfile": modelfile
        })
        
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code)
            
        return {
            "status": "success", 
            "model": config.custom_name
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))