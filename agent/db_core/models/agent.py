# from sqlalchemy import Column, Integer, String, DateTime, JSON, ForeignKey
# from sqlalchemy.orm import relationship
# from sqlalchemy.sql import func
# import uuid
# from ..core import Base
# from .tool import Tool, agent_tool_association

# class Agent(Base):
#     """SQLAlchemy model for an Agent."""
#     __tablename__ = "agents"
#     id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
#     user_id = Column(Integer, ForeignKey('users.id'))
#     name = Column(String, nullable=False)
#     model_provider = Column(String, nullable=False)
    
#     settings = Column(JSON, nullable=False)
#     system = Column(String)
#     bio = Column(JSON)
#     lore = Column(JSON)
#     knowledge = Column(JSON)
#     message_examples = Column(JSON)
#     style = Column(JSON)

#     created_at = Column(DateTime(timezone=True), server_default=func.now())
#     updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
#     tools = relationship(
#         "Tool",
#         secondary=agent_tool_association,
#         back_populates="agents"
#     )
