from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from ws_api.services.voice_stt import stream_whisper_transcription
from ws_api.services.voice_tts import stream_tts_audio
from ws_api.services.token_auth import verify_ws_token

router = APIRouter()

@router.websocket("/ws/chat/voice/{agent_id}")
async def voice_chat_ws(websocket: WebSocket, agent_id: str):
    await websocket.accept()
    user = await verify_ws_token(websocket)

    try:
        while True:
            audio_chunk = await websocket.receive_bytes()
            transcript = await stream_whisper_transcription(audio_chunk)
            
            # TODO: Send transcript to agent backend, get response
            agent_reply = f"You said: {transcript}"

            async for audio_response_chunk in stream_tts_audio(agent_reply):
                await websocket.send_bytes(audio_response_chunk)

    except WebSocketDisconnect:
        print("🔌 Disconnected WebSocket: Voice chat")
