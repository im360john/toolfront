FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

# Set working directory
WORKDIR /app

# Set environment variables
ENV PORT=10000

# Copy a simple startup script
COPY <<'EOF' /app/start.sh
#!/bin/bash
exec uvx toolfront[all] "$DATABASE_URL" --transport sse --host 0.0.0.0 --port "$PORT"
EOF

RUN chmod +x /app/start.sh

EXPOSE 10000

CMD ["/app/start.sh"]
