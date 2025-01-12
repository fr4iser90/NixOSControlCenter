from pymilvus import connections, FieldSchema, CollectionSchema, DataType, Collection, utility

def init_collections():
    # Verbindung zu Milvus
    connections.connect(host='localhost', port='19530')
    
    # Schema für Code-Embeddings
    code_fields = [
        FieldSchema(name="id", dtype=DataType.INT64, is_primary=True, auto_id=True),
        FieldSchema(name="embedding_id", dtype=DataType.VARCHAR, max_length=100),
        FieldSchema(name="code_vector", dtype=DataType.FLOAT_VECTOR, dim=1536)
    ]
    
    code_schema = CollectionSchema(
        fields=code_fields,
        description="Code embeddings for semantic search"
    )
    
    # Collection erstellen wenn sie nicht existiert
    if not utility.has_collection("code_embeddings"):  # Geändert zu utility.has_collection
        Collection(name="code_embeddings", schema=code_schema)
        print("✓ Collection 'code_embeddings' created!")
    else:
        print("✓ Collection 'code_embeddings' exists!")

if __name__ == "__main__":
    init_collections()