# mcp-servers/telegram-mcp/Dockerfile
FROM base-mcp:latest

WORKDIR /app

# Copy MCP-specific requirements.txt and install them
COPY mcp-servers/telegram-mcp/requirements.txt /app/mcp-servers/telegram-mcp/requirements.txt
RUN pip install --no-cache-dir -r mcp-servers/telegram-mcp/requirements.txt

# Copy the MCP server file
COPY mcp-servers/telegram-mcp/server.py /app/mcp-servers/telegram-mcp/server.py

# Set environment variables for Kubernetes deployment
ENV LOCAL_MODE="false"
ENV FASTMCP_BASE_URL="http://fastmcp-core-svc:9000"

# Standard MCP port in Kubernetes
EXPOSE 9000

CMD ["uvicorn", "mcp-servers.telegram-mcp.server:app", "--host", "0.0.0.0", "--port", "9000"]
