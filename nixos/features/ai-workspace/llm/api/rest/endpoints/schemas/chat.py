from pydantic import BaseModel
from typing import List, Optional

class Message(BaseModel):
    role: str  # "user" oder "assistant"
    content: str

class ChatRequest(BaseModel):
    model: str
    messages: List[Message]
    temperature: Optional[float] = 0.7
    top_p: Optional[float] = 0.9
    stream: Optional[bool] = False
    context_length: Optional[int] = 4096
    stop: Optional[List[str]] = None

class ChatResponse(BaseModel):
    model: str
    message: Message
    done: bool
    total_duration: Optional[float] = None
    load_duration: Optional[float] = None
    prompt_eval_duration: Optional[float] = None