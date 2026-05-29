from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    google_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"
    # nano-banana = Google Gemini 2.5 Flash Image. 이미지 생성/편집 모델.
    gemini_image_model: str = "gemini-2.5-flash-image"
    database_url: str = "sqlite:///./pet_ai.db"
    chroma_dir: str = "./chroma_store"
    embed_model: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    knowledge_dir: str = "./app/data/knowledge"
    uploads_dir: str = "./uploads"
    top_k: int = 6
    recommend_k: int = 5


settings = Settings()
