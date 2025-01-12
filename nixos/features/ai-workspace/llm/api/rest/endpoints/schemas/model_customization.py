from pydantic import BaseModel, ConfigDict
from typing import List, Optional
from datetime import datetime

class ModelTemplateConfig(BaseModel):
    # Deaktiviere protected namespaces Warnung
    model_config = ConfigDict(protected_namespaces=())

    # Fields
    base_model: str  # Umbenannt von model_name zu base_model
    custom_name: str
    system_prompt: str
    template: str