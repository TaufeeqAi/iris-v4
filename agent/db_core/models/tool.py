# from sqlalchemy import Column, String, JSON, Boolean, Table, ForeignKey
# from sqlalchemy.orm import relationship
# from ..core import Base

# # Association table for the many-to-many relationship
# agent_tool_association = Table(
#     'agent_tool_association',
#     Base.metadata,
#     Column('agent_id', String, ForeignKey('agents.id'), primary_key=True),
#     Column('tool_id', String, ForeignKey('tools.id'), primary_key=True),
#     Column('is_enabled', Boolean, default=False),
# )

# class Tool(Base):
#     """SQLAlchemy model for a Tool."""
#     __tablename__ = "tools"
#     id = Column(String, primary_key=True, index=True)
#     name = Column(String, unique=True, nullable=False)
#     description = Column(String)
#     config = Column(JSON)
    
#     agents = relationship("Agent", secondary=agent_tool_association, back_populates="tools")
