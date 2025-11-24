"""Application configuration."""

import os
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Application
    environment: str = os.getenv("ENVIRONMENT", "development")
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Database
    postgres_host: str = os.getenv("POSTGRES_HOST", "postgres")
    postgres_port: int = int(os.getenv("POSTGRES_PORT", "5432"))
    postgres_user: str = os.getenv("POSTGRES_USER", "feedbrainer")
    postgres_password: str = os.getenv("POSTGRES_PASSWORD", "feedbrainer")
    postgres_db: str = os.getenv("POSTGRES_DB", "feedbrainer_dev")

    @property
    def database_url(self) -> str:
        """Construct PostgreSQL database URL."""
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    # Redis
    redis_url: str = os.getenv("REDIS_URL", "redis://redis:6379/0")

    # CORS
    cors_origins: list = ["*"]

    # Other services
    feedbrainer_url: str = os.getenv("FEEDBRAINER_URL", "http://feedbrainer:3000")
    skybeam_url: str = os.getenv("SKYBEAM_URL", "http://skybeam:4000")
    skywire_url: str = os.getenv("SKYWIRE_URL", "http://skywire:6000")


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()

