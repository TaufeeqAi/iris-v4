# cyreneai/backend/api-auth/main.py

import os
from datetime import datetime, timedelta
from typing import Optional

from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from jose import JWTError, jwt
from pydantic import BaseModel
from dotenv import load_dotenv

# --- Load environment variables from a .env file ---
load_dotenv()

# --- JWT Configuration ---
# Generate a secure key and store it in an environment variable.
# For example: openssl rand -hex 32
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-super-secret-key-that-should-be-in-env")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """
    Creates a new JWT access token.
    """
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# --- In-Memory "User Database" (for this example only) ---
# In a real-world application, this would be a real database (e.g., PostgreSQL, MongoDB)
# and passwords would be securely hashed.
USERS_DB = {
    "testuser": {
        "username": "testuser",
        "password": "testpassword"  # IMPORTANT: Use hashed passwords in production!
    },
    "cyrene": {
        "username": "cyrene",
        "password": "password"
    }
}

# --- FastAPI App Initialization ---
app = FastAPI(title="Cyrene AI Authentication Service")

# --- CORS Middleware ---
# This is essential for the Flutter app running on a different port.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust this to a specific domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Pydantic Models ---
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserInDB(BaseModel):
    username: str
    password: str

# --- Endpoints ---
@app.post("/login", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    """
    Authenticates a user and returns a JWT access token.
    """
    user = USERS_DB.get(form_data.username)
    if not user or user["password"] != form_data.password:
        raise HTTPException(
            status_code=401,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Create the JWT token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user["username"]}, expires_delta=access_token_expires
    )

    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/validate_token")
async def validate_token(token: str):
    """
    Validates a JWT token.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return {"username": username, "message": "Token is valid"}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")


# uvicorn main:app --reload --host 0.0.0.0 --port 8001
