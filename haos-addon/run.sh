#!/bin/sh

echo "INFO: Starting Recipe Manager..."

# HA stores add-on options in /data/options.json
CLAUDE_API_KEY="$(cat /data/options.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('claude_api_key',''))")"
CLAUDE_MODEL="$(cat /data/options.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('claude_model','claude-sonnet-4-6'))")"

export CLAUDE_API_KEY
export CLAUDE_MODEL
export DATABASE_URL="sqlite:////data/recipes.db"

if [ -z "$CLAUDE_API_KEY" ]; then
    echo "FATAL: claude_api_key is not set. Go to the add-on Configuration tab and enter your Anthropic API key."
    exit 1
fi

echo "INFO: API will be available on port 8000"

cd /app
exec uvicorn backend.main:app --host 0.0.0.0 --port 8000
