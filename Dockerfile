FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install toolfront directly with pip
RUN pip install 'toolfront[all]'

# Create startup script
COPY <<'EOF' /app/start.sh
#!/bin/bash
set -e

echo "=== Debug Information ==="
echo "Python version: $(python --version)"
echo "DATABASE_URL: $DATABASE_URL"
echo "PORT: $PORT"
echo "=========================="

if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL environment variable is not set"
    exit 1
fi

echo "Starting toolfront..."
exec python -m toolfront "$DATABASE_URL" --transport sse --host 0.0.0.0 --port "${PORT:-10000}"
EOF

RUN chmod +x /app/start.sh

EXPOSE 10000

CMD ["/app/start.sh"]
