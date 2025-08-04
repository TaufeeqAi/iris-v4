from fastapi import WebSocket, HTTPException, status
from jose import JWTError, jwt
import os
import base64

SECRET_KEY = base64.b64decode(os.getenv("JWT_SECRET_KEY"))
ALGORITHM = "HS256"

async def get_current_user_ws(websocket: WebSocket):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub")  # username
    except JWTError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
