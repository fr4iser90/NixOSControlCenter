from pydantic import BaseModel
from typing import Optional

class ModelInfo(BaseModel):
    name: str
    size: Optional[int]
    digest: Optional[str]
    modified_at: Optional[str]

class ModelPull(BaseModel):
    name: str
    insecure: Optional[bool] = False