from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from ..utils.connection_manager import ConnectionManager
from ..services.token_auth import get_current_user_ws

router = APIRouter()
manager = ConnectionManager()

@router.websocket("/ws/chat/stream/{agent_id}")
async def chat_stream(websocket: WebSocket, agent_id: str):
    user = await get_current_user_ws(websocket)
    if not user:
        return
    channel = f"chat-{agent_id}"

    await manager.connect(websocket, channel)
    try:
        while True:
            message = await websocket.receive_text()
            await manager.broadcast(channel, f"{user}: {message}")
    except WebSocketDisconnect:
        manager.disconnect(websocket, channel)
