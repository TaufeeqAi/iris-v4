import os
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from typing import Annotated
import logging
from dotenv import load_dotenv
import base64
import logging

# --------- Load environment variables ---------
load_dotenv()

# --- JWT Configuration ---

SECRET_KEY = base64.b64decode(os.getenv("JWT_SECRET_KEY"))
ALGORITHM = "HS256"

# --------- Logging Setup ---------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# The OAuth2PasswordBearer class will handle token extraction from the header.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="http://localhost:8001/login")

def get_current_user(token: Annotated[str, Depends(oauth2_scheme)]):
    """
    Dependency that validates a JWT token and returns the username.
    """
    logger.info(f"🛡️ Received Token: {token}")
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # Decode the token using the secret key
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        logger.info(f"📦 Decoded JWT Payload (bot-api): {payload}")
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError as e:
        logger.error(f"❌ JWTError in bot-api: {str(e)}")
        raise credentials_exception
    
    # You could optionally fetch user details from a database here if needed
    return username
