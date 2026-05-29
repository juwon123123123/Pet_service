from functools import lru_cache
import chromadb
from chromadb.config import Settings as ChromaSettings
from chromadb.utils import embedding_functions

from app.config import settings

COLLECTION = "pet_knowledge"


@lru_cache(maxsize=1)
def get_client():
    return chromadb.PersistentClient(
        path=settings.chroma_dir,
        settings=ChromaSettings(anonymized_telemetry=False),
    )


@lru_cache(maxsize=1)
def get_embedder():
    return embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name=settings.embed_model
    )


def get_collection():
    return get_client().get_or_create_collection(
        name=COLLECTION,
        embedding_function=get_embedder(),
        metadata={"hnsw:space": "cosine"},
    )


def reset_collection():
    client = get_client()
    try:
        client.delete_collection(COLLECTION)
    except Exception:
        pass
    return get_collection()
