{ lib, pkgs, cfg }:

# REST API Server - FastAPI-based REST API with authentication and webhooks
# This generates a Python script for the API server
pkgs.writers.writePython3Bin "chronicle-api" 
  {
    libraries = with pkgs.python3Packages; [ 
      fastapi 
      uvicorn 
      pyjwt 
      aiofiles
      aiohttp
      python-multipart
    ];
  } 
  ''
    import os
    import json
    import logging
    from datetime import datetime, timedelta
    from typing import List, Optional, Dict, Any
    from pathlib import Path
    import asyncio
    import aiofiles
    
    from fastapi import FastAPI, HTTPException, Depends, status, BackgroundTasks, Query
    from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
    from fastapi.middleware.cors import CORSMiddleware
    from fastapi.responses import FileResponse
    from pydantic import BaseModel, Field
    import jwt
    import secrets
    import hashlib
    import uvicorn
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    
    # Configuration from Nix
    API_VERSION = "2.0.0"
    SECRET_KEY = os.getenv("CHRONICLE_API_SECRET", secrets.token_urlsafe(32))
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = ${toString cfg.api.tokenExpireMinutes}
    DATA_DIR = Path("${cfg.outputDir}").expanduser()
    API_KEY_FILE = DATA_DIR / ".api_keys"
    
    # FastAPI app
    app = FastAPI(
        title="NixOS Step Recorder API",
        description="REST API for recording, managing, and exporting system interaction sessions",
        version=API_VERSION,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json"
    )
    
    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=${builtins.toJSON cfg.api.corsOrigins},
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    security = HTTPBearer()
    
    # ============================================================================
    # Models
    # ============================================================================
    
    class Token(BaseModel):
        access_token: str
        token_type: str = "bearer"
        expires_in: int
    
    class ApiKeyCreate(BaseModel):
        name: str = Field(..., description="Friendly name for the API key")
        expires_days: Optional[int] = Field(None, description="Days until expiration")
    
    class ApiKeyResponse(BaseModel):
        key: str
        name: str
        created_at: str
        expires_at: Optional[str]
    
    class SessionMetadata(BaseModel):
        session_id: str
        title: Optional[str] = None
        description: Optional[str] = None
        started_at: str
        ended_at: Optional[str] = None
        step_count: int = 0
        status: str = "active"
    
    class StepData(BaseModel):
        step_number: int
        timestamp: str
        action_type: str
        window_title: Optional[str] = None
        screenshot_path: Optional[str] = None
        comments: List[str] = []
        metadata: Dict[str, Any] = {}
    
    class RecordingCommand(BaseModel):
        action: str = Field(..., description="start, stop, pause, resume")
        title: Optional[str] = None
        description: Optional[str] = None
    
    class ExportRequest(BaseModel):
        session_id: str
        format: str = Field(..., description="html, markdown, json, pdf, zip, all")
    
    class WebhookConfig(BaseModel):
        url: str
        events: List[str] = ["session.started", "session.stopped", "step.captured"]
        secret: Optional[str] = None
        enabled: bool = True
    
    # ============================================================================
    # Authentication
    # ============================================================================
    
    def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
        to_encode = data.copy()
        expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
        to_encode.update({"exp": expire})
        return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    
    def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
        try:
            payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
            return payload
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Token has expired")
        except jwt.JWTError:
            raise HTTPException(status_code=401, detail="Invalid credentials")
    
    async def load_api_keys() -> Dict[str, Dict]:
        if not API_KEY_FILE.exists():
            return {}
        async with aiofiles.open(API_KEY_FILE, 'r') as f:
            content = await f.read()
            return json.loads(content) if content else {}
    
    async def save_api_keys(keys: Dict[str, Dict]):
        API_KEY_FILE.parent.mkdir(parents=True, exist_ok=True)
        async with aiofiles.open(API_KEY_FILE, 'w') as f:
            await f.write(json.dumps(keys, indent=2))
    
    def verify_api_key(credentials: HTTPAuthorizationCredentials = Depends(security)):
        token = credentials.credentials
        try:
            return verify_token(credentials)
        except:
            pass
        keys = asyncio.run(load_api_keys())
        key_hash = hashlib.sha256(token.encode()).hexdigest()
        if key_hash in keys:
            key_data = keys[key_hash]
            if key_data.get("expires_at"):
                expires = datetime.fromisoformat(key_data["expires_at"])
                if datetime.utcnow() > expires:
                    raise HTTPException(status_code=401, detail="API key expired")
            return {"api_key": key_data["name"]}
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    # ============================================================================
    # Webhook System
    # ============================================================================
    
    class WebhookManager:
        def __init__(self):
            self.webhooks: List[WebhookConfig] = []
            self.webhook_file = DATA_DIR / ".webhooks.json"
            asyncio.create_task(self.load_webhooks())
        
        async def load_webhooks(self):
            if self.webhook_file.exists():
                async with aiofiles.open(self.webhook_file, 'r') as f:
                    content = await f.read()
                    data = json.loads(content) if content else []
                    self.webhooks = [WebhookConfig(**w) for w in data]
        
        async def save_webhooks(self):
            self.webhook_file.parent.mkdir(parents=True, exist_ok=True)
            async with aiofiles.open(self.webhook_file, 'w') as f:
                data = [w.dict() for w in self.webhooks]
                await f.write(json.dumps(data, indent=2))
        
        async def trigger(self, event: str, data: Dict[str, Any]):
            import aiohttp
            payload = {"event": event, "timestamp": datetime.utcnow().isoformat(), "data": data}
            for webhook in self.webhooks:
                if not webhook.enabled or event not in webhook.events:
                    continue
                try:
                    if webhook.secret:
                        signature = hashlib.hmac(
                            webhook.secret.encode(),
                            json.dumps(payload).encode(),
                            hashlib.sha256
                        ).hexdigest()
                        payload["signature"] = signature
                    async with aiohttp.ClientSession() as session:
                        async with session.post(webhook.url, json=payload, timeout=aiohttp.ClientTimeout(total=10)) as response:
                            if response.status >= 400:
                                logger.error(f"Webhook failed: {webhook.url}")
                except Exception as e:
                    logger.error(f"Webhook error: {e}")
    
    webhook_manager = WebhookManager()
    
    # ============================================================================
    # Helper Functions
    # ============================================================================
    
    async def get_sessions() -> List[SessionMetadata]:
        sessions = []
        if not DATA_DIR.exists():
            return sessions
        for session_dir in DATA_DIR.iterdir():
            if not session_dir.is_dir():
                continue
            metadata_file = session_dir / "metadata.json"
            if metadata_file.exists():
                async with aiofiles.open(metadata_file, 'r') as f:
                    content = await f.read()
                    sessions.append(SessionMetadata(**json.loads(content)))
        return sorted(sessions, key=lambda s: s.started_at, reverse=True)
    
    async def get_session(session_id: str) -> Optional[SessionMetadata]:
        metadata_file = DATA_DIR / session_id / "metadata.json"
        if not metadata_file.exists():
            return None
        async with aiofiles.open(metadata_file, 'r') as f:
            return SessionMetadata(**json.loads(await f.read()))
    
    async def get_steps(session_id: str) -> List[StepData]:
        steps_file = DATA_DIR / session_id / "steps.json"
        if not steps_file.exists():
            return []
        async with aiofiles.open(steps_file, 'r') as f:
            return [StepData(**step) for step in json.loads(await f.read())]
    
    # ============================================================================
    # API Routes
    # ============================================================================
    
    @app.get("/", tags=["Info"])
    async def root():
        return {"name": "NixOS Step Recorder API", "version": API_VERSION, "docs": "/docs"}
    
    @app.get("/health", tags=["Info"])
    async def health():
        return {"status": "healthy", "version": API_VERSION, "timestamp": datetime.utcnow().isoformat()}
    
    @app.post("/auth/token", response_model=Token, tags=["Authentication"])
    async def login():
        access_token = create_access_token(data={"sub": "user"})
        return Token(access_token=access_token, expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60)
    
    @app.post("/auth/api-keys", response_model=ApiKeyResponse, tags=["Authentication"])
    async def create_api_key(key_create: ApiKeyCreate, auth=Depends(verify_api_key)):
        api_key = secrets.token_urlsafe(32)
        key_hash = hashlib.sha256(api_key.encode()).hexdigest()
        created_at = datetime.utcnow()
        expires_at = created_at + timedelta(days=key_create.expires_days) if key_create.expires_days else None
        keys = await load_api_keys()
        keys[key_hash] = {
            "name": key_create.name,
            "created_at": created_at.isoformat(),
            "expires_at": expires_at.isoformat() if expires_at else None
        }
        await save_api_keys(keys)
        return ApiKeyResponse(
            key=api_key,
            name=key_create.name,
            created_at=created_at.isoformat(),
            expires_at=expires_at.isoformat() if expires_at else None
        )
    
    @app.get("/sessions", response_model=List[SessionMetadata], tags=["Sessions"])
    async def list_sessions(
        status: Optional[str] = None,
        limit: int = Query(100, le=1000),
        auth=Depends(verify_api_key)
    ):
        sessions = await get_sessions()
        if status:
            sessions = [s for s in sessions if s.status == status]
        return sessions[:limit]
    
    @app.get("/sessions/{session_id}", response_model=SessionMetadata, tags=["Sessions"])
    async def get_session_details(session_id: str, auth=Depends(verify_api_key)):
        session = await get_session(session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
        return session
    
    @app.delete("/sessions/{session_id}", tags=["Sessions"])
    async def delete_session(session_id: str, auth=Depends(verify_api_key)):
        session_dir = DATA_DIR / session_id
        if not session_dir.exists():
            raise HTTPException(status_code=404, detail="Session not found")
        import shutil
        shutil.rmtree(session_dir)
        await webhook_manager.trigger("session.deleted", {"session_id": session_id})
        return {"status": "success", "message": f"Session {session_id} deleted"}
    
    @app.get("/sessions/{session_id}/steps", response_model=List[StepData], tags=["Steps"])
    async def list_steps(session_id: str, auth=Depends(verify_api_key)):
        if not await get_session(session_id):
            raise HTTPException(status_code=404, detail="Session not found")
        return await get_steps(session_id)
    
    @app.get("/sessions/{session_id}/steps/{step_number}/screenshot", tags=["Steps"])
    async def get_step_screenshot(session_id: str, step_number: int, auth=Depends(verify_api_key)):
        steps = await get_steps(session_id)
        step = next((s for s in steps if s.step_number == step_number), None)
        if not step or not step.screenshot_path:
            raise HTTPException(status_code=404, detail="Screenshot not found")
        screenshot_path = DATA_DIR / session_id / step.screenshot_path
        if not screenshot_path.exists():
            raise HTTPException(status_code=404, detail="Screenshot file not found")
        return FileResponse(screenshot_path, media_type="image/jpeg")
    
    @app.post("/recording", tags=["Recording"])
    async def control_recording(command: RecordingCommand, auth=Depends(verify_api_key)):
        import subprocess
        cmd = ["${pkgs.writeShellScriptBin "chronicle" ""}"/bin/chronicle"]
        if command.action == "start":
            cmd.append("start")
            if command.title:
                cmd.extend(["--title", command.title])
            if command.description:
                cmd.extend(["--description", command.description])
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                session_id = result.stdout.strip().split()[-1] if result.stdout else "unknown"
                await webhook_manager.trigger("session.started", {"session_id": session_id})
                return {"status": "started", "session_id": session_id}
            raise HTTPException(status_code=500, detail=result.stderr)
        elif command.action in ["stop", "pause", "resume"]:
            cmd.append(command.action)
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                await webhook_manager.trigger(f"session.{command.action}ped", {})
                return {"status": command.action + "ped"}
            raise HTTPException(status_code=500, detail=result.stderr)
        raise HTTPException(status_code=400, detail=f"Unknown action: {command.action}")
    
    @app.post("/export", tags=["Export"])
    async def export_session(export_req: ExportRequest, background_tasks: BackgroundTasks, auth=Depends(verify_api_key)):
        if not await get_session(export_req.session_id):
            raise HTTPException(status_code=404, detail="Session not found")
        def run_export():
            import subprocess
            subprocess.run(["chronicle", "export", export_req.session_id, "--format", export_req.format])
            asyncio.run(webhook_manager.trigger("export.completed", {"session_id": export_req.session_id}))
        background_tasks.add_task(run_export)
        return {"status": "exporting", "session_id": export_req.session_id, "format": export_req.format}
    
    @app.post("/webhooks", tags=["Webhooks"])
    async def create_webhook(webhook: WebhookConfig, auth=Depends(verify_api_key)):
        webhook_manager.webhooks.append(webhook)
        await webhook_manager.save_webhooks()
        return {"status": "created", "webhook": webhook}
    
    @app.get("/webhooks", tags=["Webhooks"])
    async def list_webhooks(auth=Depends(verify_api_key)) -> List[WebhookConfig]:
        return webhook_manager.webhooks
    
    @app.delete("/webhooks/{index}", tags=["Webhooks"])
    async def delete_webhook(index: int, auth=Depends(verify_api_key)):
        if 0 <= index < len(webhook_manager.webhooks):
            deleted = webhook_manager.webhooks.pop(index)
            await webhook_manager.save_webhooks()
            return {"status": "deleted"}
        raise HTTPException(status_code=404, detail="Webhook not found")
    
    @app.get("/stats", tags=["Info"])
    async def statistics(auth=Depends(verify_api_key)):
        sessions = await get_sessions()
        total_steps = sum(len(await get_steps(s.session_id)) for s in sessions)
        return {
            "total_sessions": len(sessions),
            "active_sessions": len([s for s in sessions if s.status == "active"]),
            "total_steps": total_steps
        }
    
    # ============================================================================
    # Main
    # ============================================================================
    
    if __name__ == "__main__":
        host = "${cfg.api.host}"
        port = ${toString cfg.api.port}
        logger.info(f"Starting NixOS Step Recorder API v{API_VERSION}")
        logger.info(f"Server: http://{host}:{port}")
        logger.info(f"Docs: http://{host}:{port}/docs")
        uvicorn.run(app, host=host, port=port, log_level="info")
  ''
