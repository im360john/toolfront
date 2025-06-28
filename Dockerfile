FROM python:3.11-slim

# Install system dependencies including ps and other utilities
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    socat \
    procps \
    netcat-openbsd \
    curl \
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

# Function to check if port is open
check_port() {
    local port=$1
    local host=${2:-127.0.0.1}
    timeout 1 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null
}

# Start toolfront in background and capture output
echo "Starting toolfront on localhost:8000..."
uvx --python python3.11 'toolfront[all]' "$DATABASE_URL" --transport sse > /tmp/toolfront.log 2>&1 &
TOOLFRONT_PID=$!

echo "Toolfront PID: $TOOLFRONT_PID"

# Wait for toolfront to start with better checking
echo "Waiting for toolfront to start..."
for i in {1..30}; do
    if check_port 8000; then
        echo "Toolfront is responding on port 8000!"
        break
    fi
    
    # Check if process is still running
    if ! kill -0 $TOOLFRONT_PID 2>/dev/null; then
        echo "ERROR: toolfront process died"
        echo "Toolfront logs:"
        cat /tmp/toolfront.log
        exit 1
    fi
    
    echo "Attempt $i/30: waiting for toolfront..."
    sleep 2
done

# Final check
if ! check_port 8000; then
    echo "ERROR: toolfront is not responding after 60 seconds"
    echo "Process status:"
    ps aux | grep -E "(toolfront|python)" || echo "No toolfront processes found"
    echo "Toolfront logs:"
    cat /tmp/toolfront.log
    echo "Netstat output:"
    netstat -tlnp 2>/dev/null | grep :8000 || echo "No process listening on port 8000"
    exit 1
fi

echo "✓ Toolfront is running and responding"
echo "Starting reverse proxy on 0.0.0.0:${PORT:-8000}..."
echo "Proxying 0.0.0.0:${PORT:-8000} -> 127.0.0.1:8000"

# Test the proxy target first
echo "Testing proxy target..."
curl -s -I http://127.0.0.1:8000/ || echo "Warning: Could not get HTTP response from toolfront"

# Start the reverse proxy
exec socat TCP-LISTEN:${PORT:-8000},fork,bind=0.0.0.0,reuseaddr TCP:127.0.0.1:8000
EOF

RUN chmod +x /app/start.sh

EXPOSE 8000

CMD ["/app/start.sh"]
