import json
import logging
from typing import List, Dict, Any, Optional

import asyncpg
from pydantic import ValidationError

from ..models.agent_config import AgentConfig, AgentTool, Settings, AgentSecrets, Tool

logger = logging.getLogger(__name__)


class PostgresManager:
    """
    Manages all database interactions with PostgreSQL.
    """

    def __init__(self, dsn: str):
        self.dsn = dsn
        self.pool: Optional[asyncpg.Pool] = None

    async def connect(self):
        """Initializes the connection pool and ensures tables exist and are properly structured."""
        try:
            self.pool = await asyncpg.create_pool(
                self.dsn,
                min_size=1,
                max_size=10,
                timeout=60,
                command_timeout=60
            )
            logger.info("PostgreSQL connection pool created successfully.")
            await self._ensure_tables_exist()
            await self._ensure_schema_is_up_to_date()
        except Exception as e:
            logger.error(f"Failed to connect to PostgreSQL: {e}", exc_info=True)
            raise

    async def close(self):
        """Closes the connection pool."""
        if self.pool:
            await self.pool.close()
            self.pool = None

    async def _ensure_tables_exist(self):
        """Creates the necessary tables if they do not exist."""
        async with self.pool.acquire() as conn:
            # Table for Agents (Corrected style column to JSONB, system to be optional)
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS agents (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    user_id TEXT,
                    name TEXT NOT NULL,
                    model_provider TEXT NOT NULL,
                    settings JSONB NOT NULL,
                    system TEXT,
                    bio JSONB,
                    lore JSONB,
                    knowledge JSONB,
                    message_examples JSONB,
                    style JSONB
                );
            """)
            logger.info("Ensured 'agents' table exists in PostgreSQL.")

            # Table for Tools
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS tools (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    name TEXT UNIQUE NOT NULL,
                    description TEXT,
                    config JSONB
                );
            """)
            logger.info("Ensured 'tools' table exists in PostgreSQL.")

            # Association table for agents and tools (many-to-many relationship)
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS agent_tool_association (
                    agent_id UUID REFERENCES agents(id) ON DELETE CASCADE,
                    tool_id UUID REFERENCES tools(id) ON DELETE CASCADE,
                    PRIMARY KEY (agent_id, tool_id)
                );
            """)
            logger.info("Ensured 'agent_tool_association' table exists in PostgreSQL.")
    
    async def _ensure_schema_is_up_to_date(self):
        """Checks for and adds the 'is_enabled' column and updates 'style' if needed."""
        async with self.pool.acquire() as conn:
            # Check and add 'is_enabled' column
            column_check = await conn.fetchval("""
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'agent_tool_association' AND column_name = 'is_enabled'
            """)
            if not column_check:
                logger.warning("Column 'is_enabled' not found. Adding it to 'agent_tool_association' table.")
                await conn.execute("""
                    ALTER TABLE agent_tool_association
                    ADD COLUMN is_enabled BOOLEAN NOT NULL DEFAULT TRUE;
                """)
                logger.info("Added 'is_enabled' column to 'agent_tool_association' table.")

            # Check and update 'style' column to JSONB if it's not already
            style_type_check = await conn.fetchval("""
                SELECT data_type FROM information_schema.columns
                WHERE table_name = 'agents' AND column_name = 'style'
            """)
            if style_type_check and style_type_check.lower() == 'text':
                logger.warning("Column 'style' is of type TEXT. Altering to JSONB.")
                await conn.execute("""
                    ALTER TABLE agents
                    ALTER COLUMN style TYPE JSONB USING style::jsonb;
                """)
                logger.info("Altered 'style' column to JSONB.")
    
    async def get_all_agent_configs(self) -> List[AgentConfig]:
        """Fetches all agent configurations, including associated tools."""
        async with self.pool.acquire() as conn:
            records = await conn.fetch("""
                SELECT
                    a.id,
                    a.user_id,
                    a.name,
                    a.model_provider,
                    a.settings,
                    a.system,
                    a.bio,
                    a.lore,
                    a.knowledge,
                    a.message_examples,
                    a.style,
                    jsonb_agg(
                        jsonb_build_object(
                            'tool_id', t.id,
                            'is_enabled', ata.is_enabled,
                            'tool_details', jsonb_build_object(
                                'id', t.id,
                                'name', t.name,
                                'description', t.description,
                                'config', t.config
                            )
                        )
                    ) FILTER (WHERE t.id IS NOT NULL) AS tools
                FROM agents a
                LEFT JOIN agent_tool_association ata ON a.id = ata.agent_id
                LEFT JOIN tools t ON ata.tool_id = t.id
                GROUP BY a.id
            """)
            
            configs = []
            for record in records:
                try:
                    # Explicitly parse JSON strings from the database for Pydantic validation
                    agent_config_data = {
                        "id": str(record["id"]),
                        "user_id": record["user_id"],
                        "name": record["name"],
                        "modelProvider": record["model_provider"],
                        "settings": json.loads(record["settings"]),
                        "system": record["system"],
                        "bio": json.loads(record["bio"]) if record["bio"] else None,
                        "lore": json.loads(record["lore"]) if record["lore"] else None,
                        "knowledge": json.loads(record["knowledge"]) if record["knowledge"] else None,
                        "messageExamples": json.loads(record["message_examples"]) if record["message_examples"] else None,
                        "style": json.loads(record["style"]) if record["style"] else None,
                        "tools": json.loads(record["tools"]) if record["tools"] else []
                    }
                    configs.append(AgentConfig(**agent_config_data))
                except (ValidationError, json.JSONDecodeError) as e:
                    logger.error(f"Validation or JSON decode error for agent {record['id']}: {e}", exc_info=True)
                except Exception as e:
                    logger.error(f"Unexpected error processing agent {record['id']}: {e}", exc_info=True)

            return configs

    async def get_agent_config(self, agent_id: str) -> Optional[AgentConfig]:
        """Fetches a single agent configuration by ID."""
        async with self.pool.acquire() as conn:
            record = await conn.fetchrow("""
                SELECT
                    a.id,
                    a.user_id,
                    a.name,
                    a.model_provider,
                    a.settings,
                    a.system,
                    a.bio,
                    a.lore,
                    a.knowledge,
                    a.message_examples,
                    a.style,
                    jsonb_agg(
                        jsonb_build_object(
                            'tool_id', t.id,
                            'is_enabled', ata.is_enabled,
                            'tool_details', jsonb_build_object(
                                'id', t.id,
                                'name', t.name,
                                'description', t.description,
                                'config', t.config
                            )
                        )
                    ) FILTER (WHERE t.id IS NOT NULL) AS tools
                FROM agents a
                LEFT JOIN agent_tool_association ata ON a.id = ata.agent_id
                LEFT JOIN tools t ON ata.tool_id = t.id
                WHERE a.id = $1
                GROUP BY a.id
            """, agent_id)
            
            if not record:
                return None
            
            try:
                # Explicitly parse JSON strings from the database for Pydantic validation
                agent_config_data = {
                    "id": str(record["id"]),
                    "user_id": record["user_id"],
                    "name": record["name"],
                    "modelProvider": record["model_provider"],
                    "settings": json.loads(record["settings"]),
                    "system": record["system"],
                    "bio": json.loads(record["bio"]) if record["bio"] else None,
                    "lore": json.loads(record["lore"]) if record["lore"] else None,
                    "knowledge": json.loads(record["knowledge"]) if record["knowledge"] else None,
                    "messageExamples": json.loads(record["message_examples"]) if record["message_examples"] else None,
                    "style": json.loads(record["style"]) if record["style"] else None,
                    "tools": json.loads(record["tools"]) if record["tools"] else []
                }
                return AgentConfig(**agent_config_data)
            except (ValidationError, json.JSONDecodeError) as e:
                logger.error(f"Validation or JSON decode error for agent {record['id']}: {e}", exc_info=True)
            except Exception as e:
                logger.error(f"Unexpected error processing agent {record['id']}: {e}", exc_info=True)
            return None

    async def save_agent_config(self, config: AgentConfig) -> str:
        """Saves a new agent configuration to the database and returns its ID."""
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                tool_ids = {}
                if config.tools:
                    for agent_tool in config.tools:
                        tool = agent_tool.tool_details
                        if not tool or not tool.name:
                            continue
                        
                        # Use a single upsert query to get the tool ID
                        tool_id = await conn.fetchval("""
                            INSERT INTO tools (name, description, config)
                            VALUES ($1, $2, $3::jsonb)
                            ON CONFLICT (name) DO UPDATE SET
                                description = EXCLUDED.description,
                                config = EXCLUDED.config
                            RETURNING id;
                        """, tool.name, tool.description, json.dumps(tool.config) if tool.config else None)
                        
                        tool_ids[tool.name] = tool_id

                # Step 2: Insert or update agent config
                agent_id = await conn.fetchval("""
                    INSERT INTO agents (id, user_id, name, model_provider, settings, system, bio, lore, knowledge, message_examples, style)
                    VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7::jsonb, $8::jsonb, $9::jsonb, $10::jsonb, $11::jsonb)
                    ON CONFLICT (id) DO UPDATE SET
                        user_id = EXCLUDED.user_id,
                        name = EXCLUDED.name,
                        model_provider = EXCLUDED.model_provider,
                        settings = EXCLUDED.settings,
                        system = EXCLUDED.system,
                        bio = EXCLUDED.bio,
                        lore = EXCLUDED.lore,
                        knowledge = EXCLUDED.knowledge,
                        message_examples = EXCLUDED.message_examples,
                        style = EXCLUDED.style
                    RETURNING id;
                """,
                config.id,
                config.user_id,
                config.name,
                config.modelProvider,
                json.dumps(config.settings.model_dump(exclude_none=True)),
                config.system,
                json.dumps(config.bio) if config.bio else None,
                json.dumps(config.lore) if config.lore else None,
                json.dumps(config.knowledge) if config.knowledge else None,
                json.dumps(config.messageExamples) if config.messageExamples else None,
                json.dumps(config.style) if config.style else None)

                # Step 3: Update agent-tool association table
                # First, delete all old associations for this agent
                await conn.execute("DELETE FROM agent_tool_association WHERE agent_id = $1", agent_id)

                # Then, insert the new associations
                if config.tools:
                    for agent_tool in config.tools:
                        tool_name = agent_tool.tool_details.name if agent_tool.tool_details else None
                        if tool_name and tool_name in tool_ids:
                            tool_id = tool_ids.get(tool_name)
                            await conn.execute("""
                                INSERT INTO agent_tool_association (agent_id, tool_id, is_enabled)
                                VALUES ($1, $2, $3);
                            """, agent_id, tool_id, agent_tool.is_enabled)
                
                return str(agent_id)
    
    async def delete_agent_config(self, agent_id: str):
        """Deletes an agent and its associations."""
        async with self.pool.acquire() as conn:
            await conn.execute("DELETE FROM agents WHERE id = $1", agent_id)
            logger.info(f"Agent {agent_id} and its tool associations deleted.")
