#!/bin/bash
set -e

echo "Starting toolfront with uvx..."
echo "Database URL: $DATABASE_URL"

# Install and run toolfront[all] with uvx
exec uvx toolfront[all] "$DATABASE_URL" --transport sse --host 0.0.0.0 --port "${PORT:-10000}"
