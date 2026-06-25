"""
ACTA Backend — Core Configuration
===================================
Pydantic Settings class loading environment variables from
the root .env file. All secrets are resolved at startup via
secure os.getenv / Pydantic BaseSettings mechanisms.

Target Branch : feature/backend-decay
Commit        : feat(backend): add core config and gemini integration module
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


# Resolve the project root directory (two levels up from this file).
_PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.

    Environment variables can be supplied via:
    - A `.env` file at the project root
    - System environment variables
    - Docker/container environment injection
    """

    model_config = SettingsConfigDict(
        env_file=str(_PROJECT_ROOT / ".env"),
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    # --- Project ---
    PROJECT_NAME: str = "ACTA"
    DEBUG: bool = False
    LOG_LEVEL: str = "info"

    # --- Supabase / PostgreSQL ---
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_DATABASE_URL: str = ""

    # --- Google Gemini AI ---
    GEMINI_API_KEY: str = ""

    # --- Google Earth Engine & Maps ---
    GEE_SERVICE_ACCOUNT_FILE: str = ""
    GOOGLE_MAPS_API_KEY: str = ""

    # --- CORS ---
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    @property
    def cors_origins_list(self) -> list[str]:
        """Parse comma-separated CORS origins into a list."""
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def is_gemini_configured(self) -> bool:
        """Check if Gemini API key is available."""
        return bool(self.GEMINI_API_KEY)

    @property
    def is_database_configured(self) -> bool:
        """Check if database URL is available."""
        return bool(self.SUPABASE_DATABASE_URL)


@lru_cache()
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()


# Module-level convenience reference.
settings = get_settings()
