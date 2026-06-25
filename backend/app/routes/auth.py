from __future__ import annotations

import logging
import httpx
import asyncpg
from fastapi import APIRouter, HTTPException, status, Header
from pydantic import BaseModel
from app.core.config import settings

logger = logging.getLogger("acta.routes.auth")
router = APIRouter()

SUPABASE_AUTH_URL = f"{settings.SUPABASE_URL}/auth/v1"

_pool: asyncpg.Pool | None = None

async def _get_db_pool() -> asyncpg.Pool:
    global _pool
    if _pool is None:
        db_url = settings.SUPABASE_DATABASE_URL.replace(
            "postgresql+asyncpg://", "postgresql://"
        )
        _pool = await asyncpg.create_pool(
            dsn=db_url,
            min_size=1,
            max_size=5,
        )
    return _pool

class RegisterInput(BaseModel):
    email: str
    password: str
    first_name: str
    last_name: str

class LoginInput(BaseModel):
    email: str
    password: str

class ProfileResponse(BaseModel):
    id: str
    email: str
    first_name: str
    last_name: str

class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: ProfileResponse

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(input_data: RegisterInput):
    """
    Register a new user in Supabase Auth and save profile data.
    Uses the service role key to auto-confirm the email address.
    """
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    }
    
    # We use the Admin API to create the user with email auto-confirmation enabled.
    payload = {
        "email": input_data.email,
        "password": input_data.password,
        "email_confirm": True,
        "user_metadata": {
            "first_name": input_data.first_name,
            "last_name": input_data.last_name,
        }
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                f"{SUPABASE_AUTH_URL}/admin/users",
                headers=headers,
                json=payload,
                timeout=10.0,
            )
        except Exception as e:
            logger.error("Failed to connect to Supabase Auth API: %s", e)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Authentication service unavailable.",
            )
            
    if response.status_code not in (200, 201):
        try:
            error_data = response.json()
            detail = error_data.get("msg") or error_data.get("error_description") or "Failed to register user."
        except Exception:
            detail = response.text or "Registration failed."
        raise HTTPException(status_code=response.status_code, detail=detail)
        
    user_data = response.json()
    user_id = user_data.get("id")
    
    # Optional fallback insert to database in case trigger was not created/run.
    # We execute it inside a try-except to ensure we don't crash if the trigger already ran it successfully.
    try:
        pool = await _get_db_pool()
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO public.profiles (id, first_name, last_name)
                VALUES ($1, $2, $3)
                ON CONFLICT (id) DO NOTHING
                """,
                user_id,
                input_data.first_name,
                input_data.last_name,
            )
    except Exception as e:
        logger.warning("DB insertion warning/error (trigger may have already run): %s", e)

    return {
        "message": "User registered successfully.",
        "user": {
            "id": user_id,
            "email": input_data.email,
            "first_name": input_data.first_name,
            "last_name": input_data.last_name,
        }
    }

@router.post("/login", response_model=LoginResponse)
async def login(input_data: LoginInput):
    """
    Log in a user via Supabase Auth and return user metadata & access token.
    """
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Content-Type": "application/json",
    }
    
    payload = {
        "email": input_data.email,
        "password": input_data.password,
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                f"{SUPABASE_AUTH_URL}/token?grant_type=password",
                headers=headers,
                json=payload,
                timeout=10.0,
            )
        except Exception as e:
            logger.error("Failed to connect to Supabase Auth API: %s", e)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Authentication service unavailable.",
            )
            
    if response.status_code != 200:
        try:
            error_data = response.json()
            detail = error_data.get("error_description") or error_data.get("msg") or "Invalid email or password."
        except Exception:
            detail = "Invalid email or password."
        raise HTTPException(status_code=response.status_code, detail=detail)
        
    token_data = response.json()
    user_info = token_data.get("user", {})
    user_id = user_info.get("id")
    email = user_info.get("email")
    
    # Get user profile metadata (first_name, last_name)
    user_metadata = user_info.get("user_metadata", {})
    first_name = user_metadata.get("first_name", "")
    last_name = user_metadata.get("last_name", "")
    
    # If not in user_metadata, try querying public.profiles
    if not first_name or not last_name:
        try:
            pool = await _get_db_pool()
            async with pool.acquire() as conn:
                row = await conn.fetchrow(
                    "SELECT first_name, last_name FROM public.profiles WHERE id = $1",
                    user_id,
                )
                if row:
                    first_name = row["first_name"]
                    last_name = row["last_name"]
        except Exception as e:
            logger.error("Failed to fetch user profile from DB: %s", e)
            
    return {
        "access_token": token_data.get("access_token"),
        "refresh_token": token_data.get("refresh_token"),
        "user": {
            "id": user_id,
            "email": email,
            "first_name": first_name,
            "last_name": last_name,
        }
    }

@router.get("/me", response_model=ProfileResponse)
async def get_me(authorization: str | None = Header(None)):
    """
    Get current logged in user details using their Bearer JWT token.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization token missing or invalid.",
        )
        
    token = authorization.split(" ")[1]
    
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {token}",
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(
                f"{SUPABASE_AUTH_URL}/user",
                headers=headers,
                timeout=5.0,
            )
        except Exception as e:
            logger.error("Failed to connect to Supabase Auth API: %s", e)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Authentication service unavailable.",
            )
            
    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired or invalid token.",
        )
        
    user_info = response.json()
    user_id = user_info.get("id")
    email = user_info.get("email")
    
    # Query database to get the user's first/last name
    first_name = ""
    last_name = ""
    try:
        pool = await _get_db_pool()
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT first_name, last_name FROM public.profiles WHERE id = $1",
                user_id,
            )
            if row:
                first_name = row["first_name"]
                last_name = row["last_name"]
    except Exception as e:
        logger.error("Failed to query user profile: %s", e)
        
    # Fallback to user_metadata if query returned nothing
    if not first_name or not last_name:
        user_metadata = user_info.get("user_metadata", {})
        first_name = user_metadata.get("first_name", "")
        last_name = user_metadata.get("last_name", "")
        
    return {
        "id": user_id,
        "email": email,
        "first_name": first_name,
        "last_name": last_name,
    }
