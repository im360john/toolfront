FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

WORKDIR /app

# Create startup script  
COPY <<'EOF' /app/start.sh
#!/bin/bash
set -e

if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL environment variable is not set"
    exit 1
fi

echo "Checking all toolfront options..."
uvx --python python3.11 'toolfront[all]' --help

echo "Trying with various host options..."
# Try different potential host options
for host_flag in "--host" "--bind" "--listen" "--server-host" "--sse-host"; do
    echo "Trying: $host_flag 0.0.0.0"
    timeout 10s uvx --python python3.11 'toolfront[all]' "$DATABASE_URL" --transport sse $host_flag 0.0.0.0 || echo "Failed with $host_flag"
done

echo "Starting with default settings..."
exec uvx --python python3.11 'toolfront[all]' "$DATABASE_URL" --transport sse
EOF

RUN chmod +x /app/start.sh

EXPOSE 8000

CMD ["/app/start.sh"]
