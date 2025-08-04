# api/routes/chat.py
import logging
from typing import Dict
from fastapi import APIRouter, HTTPException, status, Depends
from langchain_core.messages import HumanMessage, AIMessage

from ..dependencies import get_current_user, get_db_manager, get_agent_manager
from ..utils.agent_helpers import get_and_initialize_agent

logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("/{agent_id}/chat")
async def chat_with_agent(
    agent_id: str,
    message: Dict[str, str],
    current_user: str = Depends(get_current_user),
    db_manager=Depends(get_db_manager),
    agent_manager=Depends(get_agent_manager)
):
    """Chat with a specific agent."""
    logger.info(f"User '{current_user}' is chatting with agent '{agent_id}'.")
    
    user_message = message.get("message")
    if not user_message:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Message content is required."
        )
    
    # Check if the agent exists
    agent_config = await db_manager.get_agent_config(agent_id)
    if not agent_config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail=f"Agent with ID '{agent_id}' not found."
        )
    
    # Get or initialize the agent
    agent_info = await get_and_initialize_agent(db_manager, agent_manager, agent_id)
    agent_executor = agent_info["executor"]
    
    logger.info(f"Invoking agent '{agent_id}' with message: {user_message}")
    
    try:
        initial_state = {"messages": [HumanMessage(content=user_message)]}
        agent_output = await agent_executor.ainvoke(initial_state)
        
        final_message_content = agent_output.get("messages", [AIMessage(content="I couldn't process that.")])[-1].content
        return {"response": final_message_content}
    except Exception as e:
        logger.error(f"Error during agent invocation: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, 
            detail=f"An error occurred while processing your request: {e}"
        )