import logging
import json
import uuid
from dotenv import load_dotenv
from contextlib import asynccontextmanager
from typing import Dict, Any, List, Optional, Annotated

from fastapi import FastAPI, HTTPException, Request, status, Depends
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ValidationError

# --- Import the new PostgresManager instead of SQLiteManager
from ..db.postgres_manager import PostgresManager
# Corrected the import from 'AgentTools' to 'AgentTool'
from ..models.agent_config import AgentConfig, AgentSecrets, Settings, AgentTool
from ..core.agent_manager import AgentManager
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage, ToolMessage
from fastapi.middleware.cors import CORSMiddleware
import os
# --- Import the new authentication dependency ---
from ..api.dependencies import get_current_user

# --- Correctly import only the MultiServerMCPClient
from langchain_mcp_adapters.client import MultiServerMCPClient


# --------- Load environment variables ---------
load_dotenv()

# --------- Logging Setup ---------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --------- Pydantic Models ---------
class ReceiveDiscordMessageRequest(BaseModel):
    """Pydantic model for Discord message webhook payload."""
    content: str
    channel_id: str
    author_id: str
    author_name: str
    message_id: str
    timestamp: str
    guild_id: Optional[str] = None
    bot_id: str

class CreateAgentRequest(BaseModel):
    """Pydantic model for the agent creation request body."""
    name: str = "NewBot"
    modelProvider: str = "groq"
    settings: Dict[str, Any]
    system: str = ""
    bio: List[str] = []
    lore: List[str] = []
    knowledge: List[str] = []
    messageExamples: Optional[List[Dict[str, str]]] = None
    style: Optional[str] = None
    tools: List[AgentTool] = []

# --------- Determine Local or Cluster Mode ---------
LOCAL_MODE = True
logger.info(f"Running in LOCAL_MODE: {LOCAL_MODE}")

logger.info(f"[DEBUG] JWT_SECRET_KEY:{os.getenv('JWT_SECRET_KEY')}")

# Load PostgreSQL DSN from environment variables
POSTGRES_DSN = os.getenv("POSTGRES_DSN", "postgresql://cyrene:taufeeq@127.0.0.1:5433/cyrene_auth")
if not POSTGRES_DSN:
    logger.error("POSTGRES_DSN environment variable not set. Application cannot connect to database.")
    raise ValueError("POSTGRES_DSN environment variable not set.")

# --- NEW: Initialize the MultiServerMCPClient instance ---
mcp_client_instance = MultiServerMCPClient()

# --------- FastAPI Lifespan Context Manager ---------
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan context manager for initializing and cleaning up resources.
    Initializes the PostgreSQL database connection pool and agents.
    """
    logger.info("Agent app startup: Initializing global resources...")

    # Initialize and store database and agent manager instances in app state
    db_manager_instance = PostgresManager(POSTGRES_DSN)
    await db_manager_instance.connect()
    app.state.db_manager = db_manager_instance
    logger.info("PostgreSQL connection pool initialized and stored in app state.")
    
    # --- FIX START ---
    # The AgentManager.__init__ now only takes one argument: the db_manager instance.
    agent_manager_instance = AgentManager(db_manager_instance)
    app.state.agent_manager = agent_manager_instance
    # --- FIX END ---

    # --- UPDATED: Remove the call to initialize and log statement on mcp_client_instance ---
    # The client is ready to use upon instantiation and the .tools attribute is not
    # available on the base instance.
    try:
        app.state.mcp_client = mcp_client_instance
    except Exception as e:
        logger.error(f"Failed to initialize MCP client: {e}", exc_info=True)
        app.state.mcp_client = None

    try:
        # Pass user_id=None for the default agent during startup
        await app.state.agent_manager.initialize_all_agents_from_db(LOCAL_MODE)
        logger.info("All agents initialized from the database on startup.")
    except Exception as e:
        logger.error(f"Failed to initialize agents on startup: {e}", exc_info=True)

    logger.info("Agent app startup complete. Agent is ready.")
    yield

    logger.info("Agent app shutdown.")
    await app.state.agent_manager.shutdown_all_agents()
    await app.state.db_manager.close() # Close the pool
    # --- UPDATED: Remove the call to mcp_client_instance.close() ---
    # This object does not have a close method and does not need to be shut down.
    logger.info("PostgreSQL connection pool closed.")

app = FastAPI(lifespan=lifespan, debug=True)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Define the user dependency type for easy use ---
CurrentUser = Annotated[str, Depends(get_current_user)]


# --------- Helper Functions ---------
async def _get_and_initialize_agent(db_manager: PostgresManager, agent_manager: AgentManager, agent_id: str):
    """
    Helper function to get an agent from the cache or initialize it from the database.
    """
    agent_info = agent_manager.get_initialized_agent(agent_id)
    if agent_info:
        return agent_info

    agent_config = await db_manager.get_agent_config(agent_id)
    if not agent_config:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Agent with ID '{agent_id}' not found.")

    try:
        executor, mcp_client, discord_bot_id, telegram_bot_id = \
            await agent_manager.create_dynamic_agent_instance(agent_config, LOCAL_MODE)
        
        agent_manager.add_initialized_agent(
            agent_config.id,
            agent_config.name,
            executor,
            mcp_client,
            discord_bot_id=discord_bot_id,
            telegram_bot_id=telegram_bot_id
        )
        logger.info(f"Agent '{agent_config.name}' (ID: {agent_config.id}) re-initialized and added to cache.")
        return agent_manager.get_initialized_agent(agent_id)
    except Exception as e:
        logger.error(f"Failed to re-initialize agent '{agent_id}': {e}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
                            detail=f"Failed to initialize agent '{agent_id}': {e}")

def _get_agent_by_bot_id(agent_manager: AgentManager, incoming_bot_id: str, platform: str):
    """
    Helper function to find an agent based on its platform-specific bot ID.
    """
    for agent_id, agent_info in agent_manager.get_all_initialized_agents().items():
        if agent_info["name"] == "DefaultBot":
            continue
        
        cached_bot_id = agent_info.get(f"{platform}_bot_id")
        # Ensure string comparison as IDs might be stored as different types
        if agent_info["mcp_client"].tools.get(f"send_message_{platform}") and str(cached_bot_id) == str(incoming_bot_id):
            logger.info(f"Selected agent '{agent_info['name']}' (ID: {agent_id}) for {platform} webhook.")
            return agent_info
    
    logger.warning(f"No suitable agent found with {platform} API keys matching bot ID '{incoming_bot_id}'.")
    return None

# --------- FastAPI Endpoints ---------

@app.get("/")
async def read_root():
    return {"message": "Welcome to the Multi-Agent Bot API!"}

@app.post("/agents/create", response_model=AgentConfig, status_code=status.HTTP_201_CREATED)
async def create_agent(agent_request: CreateAgentRequest, current_user: CurrentUser):
    logger.info(f"User '{current_user}' is creating a new agent.")
    try:
        secrets_from_json = agent_request.settings.get("secrets", {})
        voice_settings = agent_request.settings.get("voice", {})

        agent_secrets_instance = AgentSecrets(**secrets_from_json)
        logger.debug(f"[main.py] Parsed AgentSecrets: {agent_secrets_instance.model_dump_json(exclude_none=True)}")

        settings_instance = Settings(
            model=agent_request.settings.get("model", "llama3-8b-8192"),
            temperature=agent_request.settings.get("temperature", 0.7),
            maxTokens=agent_request.settings.get("maxTokens", 8192),
            secrets=agent_secrets_instance,
            voice=voice_settings if voice_settings else None
        )

        agent_config = AgentConfig(
            id=str(uuid.uuid4()),
            user_id=current_user,  # <--- FIX: Set the user ID from the dependency
            name=agent_request.name,
            modelProvider=agent_request.modelProvider,
            settings=settings_instance,
            system=agent_request.system,
            bio=agent_request.bio,
            lore=agent_request.lore,
            knowledge=agent_request.knowledge,
            messageExamples=agent_request.messageExamples,
            style=agent_request.style,
            tools=agent_request.tools
        )

        db_manager = app.state.db_manager
        agent_manager = app.state.agent_manager

        agent_id = await db_manager.save_agent_config(agent_config)
        agent_config.id = agent_id

        executor, mcp_client, discord_bot_id, telegram_bot_id = \
            await agent_manager.create_dynamic_agent_instance(agent_config, LOCAL_MODE)
        
        agent_manager.add_initialized_agent(
            agent_config.id,
            agent_config.name,
            executor,
            mcp_client,
            discord_bot_id=discord_bot_id,
            telegram_bot_id=telegram_bot_id
        )
        logger.info(f"Agent '{agent_config.name}' (ID: {agent_config.id}) created and initialized by user '{current_user}'.")
        
        return agent_config
    except ValidationError as e:
        logger.error(f"Validation Error creating agent: {e.errors()}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid agent configuration: {e.errors()}")
    except Exception as e:
        logger.error(f"Error creating agent: {e}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to create agent: {e}")

@app.get("/agents/list", response_model=List[AgentConfig])
async def list_agents(current_user: CurrentUser):
    logger.info(f"User '{current_user}' is listing all agents.")
    try:
        configs = await app.state.db_manager.get_all_agent_configs()
        return configs
    except Exception as e:
        logger.error(f"Error listing agents: {e}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to list agents: {e}")

@app.delete("/agents/{agent_id}", status_code=status.HTTP_200_OK)
async def delete_agent(agent_id: str, current_user: CurrentUser):
    logger.info(f"User '{current_user}' is deleting agent '{agent_id}'.")
    db_manager = app.state.db_manager
    agent_manager = app.state.agent_manager
    
    agent_config_from_db = await db_manager.get_agent_config(agent_id)
    if not agent_config_from_db:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Agent with ID {agent_id} not found.")

    # Check if the user is authorized to delete this agent
    if agent_config_from_db.user_id != current_user:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not authorized to delete this agent.")

    try:
        await agent_manager.shutdown_specific_agent(agent_id)
        await db_manager.delete_agent_config(agent_id)

        return {"message": f"Agent '{agent_id}' deleted successfully by user '{current_user}'."}
    except Exception as e:
        logger.error(f"Failed to delete agent '{agent_id}': {e}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to delete agent: {e}")

@app.post("/agents/{agent_id}/chat")
async def chat_with_agent(agent_id: str, message: Dict[str, str], current_user: CurrentUser):
    logger.info(f"User '{current_user}' is chatting with agent '{agent_id}'.")
    user_message = message.get("message")
    if not user_message:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Message content is required.")
    
    # Check if the agent exists and if the user has permissions
    agent_config = await app.state.db_manager.get_agent_config(agent_id)
    if not agent_config:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Agent with ID '{agent_id}' not found.")
    
    # Note: For now, we allow any logged-in user to chat with any agent.
    # In a more advanced implementation, you might check if `agent_config.user_id == current_user`.
    
    agent_info = await _get_and_initialize_agent(app.state.db_manager, app.state.agent_manager, agent_id)
    agent_executor = agent_info["executor"]
    
    logger.info(f"Invoking agent '{agent_id}' with message: {user_message}")
    try:
        initial_state = {"messages": [HumanMessage(content=user_message)]}
        agent_output = await agent_executor.ainvoke(initial_state)
        
        final_message_content = agent_output.get("messages", [AIMessage(content="I couldn't process that.")])[-1].content
        return {"response": final_message_content}
    except Exception as e:
        logger.error(f"Error during agent invocation: {e}", exc_info=True)
        # Use HTTPException for consistency in API error responses
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
                            detail=f"An error occurred while processing your request: {e}")

# --------- Telegram Webhook ----------
@app.post("/telegram/webhook")
async def tg_webhook(request: Request):
    try:
        data = await request.json()
        logger.info(f"Received Telegram webhook data: {json.dumps(data, indent=2)}")

        message = data.get("message")
        if not message:
            # Handle forwarded payloads from external services
            chat_id = data.get("chat_id")
            user_message = data.get("content")
            incoming_bot_id = data.get("bot_id")
        else:
            # Handle direct Telegram webhook payloads
            chat_id = message.get("chat", {}).get("id")
            user_message = message.get("text")
            # Telegram bot ID is not in the message payload itself, it's typically in the URL or derived from a token
            # We assume the external service provides it, as in the forwarded payload.
            incoming_bot_id = data.get("bot_id") # Assuming this is injected by the webhook proxy.

        if not all([chat_id, user_message, incoming_bot_id]):
            logger.warning(f"Missing essential Telegram message data. Skipping. Details: chat_id={chat_id}, user_message={user_message}, bot_id={incoming_bot_id}")
            return JSONResponse(status_code=200, content={"status": "ignored", "detail": "Missing essential data."})

        selected_agent_info = _get_agent_by_bot_id(app.state.agent_manager, incoming_bot_id, "telegram")

        if not selected_agent_info:
            return JSONResponse(status_code=200, content={"status": "ignored", "detail": f"No agent for bot ID {incoming_bot_id}."})
        
        agent_executor = selected_agent_info["executor"]
        agent_mcp_client = selected_agent_info["mcp_client"]

        logger.info(f"Invoking agent '{selected_agent_info['name']}' with Telegram message...")
        initial_state = {"messages": [HumanMessage(content=user_message)]}
        agent_output = await agent_executor.ainvoke(initial_state)

        final_message_content = "I'm sorry, I couldn't process that."
        if "messages" in agent_output and agent_output["messages"]:
            last_message = agent_output["messages"][-1]
            if isinstance(last_message, AIMessage):
                final_message_content = last_message.content
            else:
                final_message_content = str(last_message)

        telegram_tool = agent_mcp_client.tools.get("send_message_telegram")
        if telegram_tool:
            logger.info(f"Using agent '{selected_agent_info['name']}'s Telegram tool to send reply.")
            await telegram_tool.ainvoke({"chat_id": str(chat_id), "message": final_message_content})
            logger.info(f"Telegram reply sent successfully.")
        else:
            logger.error(f"Selected agent '{selected_agent_info['name']}' unexpectedly lacks 'send_message_telegram' tool.")

        return JSONResponse(status_code=200, content={"status": "ok"})

    except Exception as e:
        logger.error(f"Error processing Telegram webhook: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/discord/receive_message")
async def receive_discord_message(payload: ReceiveDiscordMessageRequest):
    try:
        channel_id = payload.channel_id
        author_name = payload.author_name
        message_content = payload.content
        incoming_bot_id = payload.bot_id

        logger.info(f"Received Discord message from {author_name} via bot {incoming_bot_id} in channel {channel_id}: {message_content}")

        selected_agent_info = _get_agent_by_bot_id(app.state.agent_manager, incoming_bot_id, "discord")

        if not selected_agent_info:
            return JSONResponse(status_code=200, content={"status": "ignored", "detail": f"No agent for bot ID {incoming_bot_id}."})

        agent_executor = selected_agent_info["executor"]
        agent_mcp_client = selected_agent_info["mcp_client"]

        logger.info(f"Invoking agent '{selected_agent_info['name']}' with Discord message...")
        initial_state = {"messages": [HumanMessage(content=message_content)]}
        agent_output = await agent_executor.ainvoke(initial_state)

        final_message_content = "I'm sorry, I couldn't process that."
        if "messages" in agent_output and agent_output["messages"]:
            last_message = agent_output["messages"][-1]
            if isinstance(last_message, AIMessage):
                final_message_content = last_message.content
            else:
                final_message_content = str(last_message)

        discord_tool = agent_mcp_client.tools.get("send_message")
        if discord_tool:
            logger.info(f"Using agent '{selected_agent_info['name']}'s Discord tool to send reply.")
            await discord_tool.ainvoke({"channel_id": str(channel_id), "message": final_message_content})
            logger.info(f"Discord reply sent successfully.")
        else:
            logger.error(f"Selected agent '{selected_agent_info['name']}' unexpectedly lacks 'send_message' tool.")

        return JSONResponse(status_code=200, content={"status": "ok"})

    except ValidationError as e:
        logger.warning(f"Discord message validation failed: {e.errors()}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid Discord message payload: {e.errors()}")
    except Exception as e:
        logger.error(f"Error processing received Discord message: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
