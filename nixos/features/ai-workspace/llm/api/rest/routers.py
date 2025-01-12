from fastapi import APIRouter
import logging

# Logger konfigurieren
logger = logging.getLogger(__name__)

# CRUD Endpoints
from endpoints.crud.chat import create as chat_create, read as chat_read
from endpoints.crud.models import create as models_create, read as models_read, update as models_update, delete as models_delete
from endpoints.crud.model_customization import create as custom_create, read as custom_read, delete as custom_delete

# Vector Endpoints
from endpoints.vector import collections, embeddings

# Main API Router
api_router = APIRouter(prefix="/api/v1")


# Chat Routes
api_router.include_router(chat_create.router, prefix="/llm/chat", tags=["llm"])
api_router.include_router(chat_read.router, prefix="/llm/chat", tags=["llm"])

# Models Routes
api_router.include_router(models_create.router, prefix="/llm/models", tags=["llm"])
api_router.include_router(models_read.router, prefix="/llm/models", tags=["llm"])
api_router.include_router(models_update.router, prefix="/llm/models", tags=["llm"])
api_router.include_router(models_delete.router, prefix="/llm/models", tags=["llm"])

# Ollama Model Customization (nur für Templates/Verhalten)
api_router.include_router(custom_create.router, prefix="/llm/model-customization", tags=["llm"])
api_router.include_router(custom_read.router, prefix="/llm/model-customization", tags=["llm"])
api_router.include_router(custom_delete.router, prefix="/llm/model-customization", tags=["llm"])


# Vector Routes
api_router.include_router(collections.router, prefix="/vector/collections", tags=["vector"])
api_router.include_router(embeddings.router, prefix="/vector/embeddings", tags=["vector"])

# Debug: Alle registrierten Routen
logger.debug("All registered routes:")
for route in api_router.routes:
    logger.debug(f"{route.methods} {route.path}")