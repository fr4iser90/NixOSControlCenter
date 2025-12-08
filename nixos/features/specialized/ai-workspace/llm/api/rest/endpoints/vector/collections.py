# llm/api/rest/endpoints/collections.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from pymilvus import connections, Collection, FieldSchema, CollectionSchema, DataType, utility

router = APIRouter(prefix="/collections", tags=["collections"])

class CollectionCreate(BaseModel):
    name: str
    dimension: int = 4096  # Default für Llama2
    description: Optional[str] = None

@router.get("/")
async def list_collections():
    """Liste alle Collections"""
    try:
        connections.connect("default", host="localhost", port="19530")
        collections = utility.list_collections()
        return {"collections": collections}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/")
async def create_collection(request: CollectionCreate):
    """Neue Collection erstellen"""
    try:
        connections.connect("default", host="localhost", port="19530")
        
        if utility.has_collection(request.name):
            raise HTTPException(status_code=400, detail=f"Collection {request.name} exists")
        
        # Define fields
        fields = [
            FieldSchema(name="text", dtype=DataType.VARCHAR, max_length=65535),
            FieldSchema(name="vector", dtype=DataType.FLOAT_VECTOR, dim=request.dimension)
        ]
        
        schema = CollectionSchema(
            fields=fields,
            description=request.description or f"Vector collection for {request.name}"
        )
        
        # Create collection
        collection = Collection(name=request.name, schema=schema)
        
        # Create index
        index_params = {
            "metric_type": "L2",
            "index_type": "IVF_FLAT",
            "params": {"nlist": 1024}
        }
        collection.create_index(field_name="vector", index_params=index_params)
        
        return {
            "status": "success",
            "name": request.name,
            "dimension": request.dimension
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{name}")
async def delete_collection(name: str):
    """Collection löschen"""
    try:
        connections.connect("default", host="localhost", port="19530")
        
        if not utility.has_collection(name):
            raise HTTPException(status_code=404, detail=f"Collection {name} not found")
            
        utility.drop_collection(name)
        return {"status": "success", "message": f"Collection {name} deleted"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@router.get("/{name}/stats")
async def collection_stats(name: str):
    """Get collection statistics"""
    try:
        connections.connect("default", host="localhost", port="19530")
        
        if not utility.has_collection(name):
            raise HTTPException(status_code=404, detail=f"Collection {name} not found")
            
        collection = Collection(name)
        stats = collection.get_stats()
        return {
            "name": name,
            "row_count": stats["row_count"],
            "index_type": collection.index().params,
            "size": stats.get("data_size", 0)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{name}/compact")
async def compact_collection(name: str):
    """Compact/optimize a collection"""
    try:
        connections.connect("default", host="localhost", port="19530")
        
        if not utility.has_collection(name):
            raise HTTPException(status_code=404, detail=f"Collection {name} not found")
            
        collection = Collection(name)
        collection.compact()
        return {"status": "success", "message": f"Collection {name} compacted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))