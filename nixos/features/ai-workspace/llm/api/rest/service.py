from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import logging  # Logging-Import hinzugefügt
from routers import api_router

# Logger konfigurieren
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)  # Logger-Instanz erstellen

app = FastAPI(
    title="AI Workspace API",
    description="LLM and Vector Search API",
    version="1.0.0",
    debug=True
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Zentraler Router
app.include_router(api_router)

@app.get("/")
async def root():
    return {
        "status": "online",
        "endpoints": {
            "llm": [
                "/chat",
                "/models",
                "/model-customization"
            ],
            "vector": [
                "/collections",
                "/embeddings"
            ]
        }
    }

# Startup Event mit korrekt definiertem logger
@app.on_event("startup")
async def startup_event():
    logger.debug("Registered routes:")
    for route in app.routes:
        logger.debug(f"{route.methods} {route.path}")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=3000)