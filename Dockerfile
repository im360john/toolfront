FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    socat \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

WORKDIR /app

# Create startup script
COPY <<'EOF' /app/start.sh
#!/bin/bash
set -e

echo "=== Starting Toolfront with Reverse Proxy ==="
echo "DATABASE_URL: $DATABASE_URL"
echo "PORT: $PORT"
echo "=============================================="

if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL environment variable is not set"
    exit 1
fi

# Start toolfront in background
echo "Starting toolfront on localhost:8000..."
uvx --python python3.11 'toolfront[all]' "$DATABASE_URL" --transport sse &
TOOLFRONT_PID=$!

# Wait for toolfront to start
echo "Waiting for toolfront to start..."
sleep 10

# Check if toolfront is running
if ! kill -0 $TOOLFRONT_PID 2>/dev/null; then
    echo "ERROR: toolfront failed to start"
    exit 1
fi

# Test if toolfront is listening
echo "Testing toolfront connection..."
timeout 5s bash -c 'while ! nc -z 127.0.0.1 8000; do sleep 1; done' || {
    echo "WARNING: Could not connect to toolfront on localhost:8000"
    echo "Toolfront logs:"
    jobs -p | xargs -r ps -f
}

echo "Starting reverse proxy on 0.0.0.0:${PORT:-8000}..."
echo "Proxying 0.0.0.0:${PORT:-8000} -> 127.0.0.1:8000"

# Start the reverse proxy
exec socat TCP-LISTEN:${PORT:-8000},fork,bind=0.0.0.0,reuseaddr TCP:127.0.0.1:8000
EOF

RUN chmod +x /app/start.sh

# Install netcat for testing
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

EXPOSE 8000

CMD ["/app/start.sh"]
