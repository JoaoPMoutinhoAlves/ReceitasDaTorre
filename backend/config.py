from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://recipes:recipes@db:5432/recipes"
    claude_api_key: str
    claude_model: str = "claude-opus-4-6"

    class Config:
        env_file = ".env"


settings = Settings()
