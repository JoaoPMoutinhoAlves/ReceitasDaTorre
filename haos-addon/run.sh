#!/usr/bin/with-contenv bashio

bashio::log.info "Starting Recipe Manager..."

# Read add-on options set by the user in HA UI
export CLAUDE_API_KEY="$(bashio::config 'claude_api_key')"
export CLAUDE_MODEL="$(bashio::config 'claude_model')"

# SQLite database stored in /data — persists across restarts and updates
export DATABASE_URL="sqlite:////data/recipes.db"

if [ -z "${CLAUDE_API_KEY}" ]; then
    bashio::log.fatal "claude_api_key is not set. Go to the add-on Configuration tab and enter your Anthropic API key."
    exit 1
fi

bashio::log.info "API will be available on port 8000"

cd /app
exec uvicorn backend.main:app --host 0.0.0.0 --port 8000
