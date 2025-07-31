# cyreneai/backend/api-bot/api/dependencies.py
# This module defines the JWT authentication dependency for protected endpoints.

import os
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from typing import Annotated

# --- JWT Configuration ---
# NOTE: This should use the same secret key as your api-auth service.
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-super-secret-key-that-should-be-in-env")
ALGORITHM = "HS256"

# The OAuth2PasswordBearer class will handle token extraction from the header.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="http://localhost:8001/login")

def get_current_user(token: Annotated[str, Depends(oauth2_scheme)]):
    """
    Dependency that validates a JWT token and returns the username.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # Decode the token using the secret key
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    # You could optionally fetch user details from a database here if needed
    return username
