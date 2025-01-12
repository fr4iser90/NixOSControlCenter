from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from ...schemas.chat import ChatRequest, ChatResponse
import json
import httpx
import logging

logger = logging.getLogger(__name__)
router = APIRouter()
OLLAMA_API = "http://localhost:11434/api"

@router.post("/stream")
async def chat_stream(request: ChatRequest):
    """Streaming Chat mit einem Modell"""
    async def generate():
        async with httpx.AsyncClient() as client:
            async with client.stream(
                'POST', 
                f"{OLLAMA_API}/chat",
                json=request.dict(),
                timeout=30.0
            ) as response:
                async for line in response.aiter_lines():
                    if line:
                        try:
                            data = json.loads(line)
                            if "message" in data:
                                yield f"data: {json.dumps({'content': data['message']['content']})}\n\n"
                            if data.get("done", False):
                                break
                        except json.JSONDecodeError:
                            continue
                
    return StreamingResponse(
        generate(), 
        media_type="text/event-stream"
    )

@router.post("/sync")
async def chat_sync(request: ChatRequest) -> ChatResponse:
    """Synchroner Chat mit einem Modell (komplette Antwort auf einmal)"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{OLLAMA_API}/chat",
                json=request.dict(),
                timeout=30.0
            )
            
            if response.status_code == 200:
                data = response.json()
                return ChatResponse(
                    model=request.model,
                    message=data["message"],
                    done=True,
                    total_duration=data.get("total_duration")
                )
            raise HTTPException(status_code=response.status_code)
    except Exception as e:
        logger.error(f"Chat error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))