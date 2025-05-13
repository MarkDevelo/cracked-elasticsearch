#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ENV_FILE="${SCRIPT_DIR}/.env"
CERTS_DIR="${SCRIPT_DIR}/es_host_config/certs/ca" # Check if CA cert exists

# Function to update .env file
update_env_var() {
    local var_name="$1"
    local new_value="$2"
    local env_file_path="$3"

    # Escape special characters in new_value for sed
    local escaped_new_value
    escaped_new_value=$(printf '%s\n' "$new_value" | sed -e 's/[\/&]/\\&/g')

    if grep -q "^${var_name}=" "${env_file_path}"; then
        # Variable exists, update it
        sed -i -E "s/^${var_name}=.*/${var_name}=${escaped_new_value}/" "${env_file_path}"
    else
        # Variable doesn't exist, append it
        echo "${var_name}=${escaped_new_value}" >> "${env_file_path}"
    fi
    echo "Updated ${var_name} in ${env_file_path}"
}

# Load .env to get ES_VERSION and ELASTIC_PASSWORD
if [ ! -f "${ENV_FILE}" ]; then
    echo "ERROR: .env file not found. Please run ./setup-cracked-elk.sh first."
    exit 1
fi
# shellcheck source=.env
source "${ENV_FILE}"
if [ -z "${ES_VERSION}" ] || [ -z "${ELASTIC_PASSWORD}" ]; then
    echo "ERROR: ES_VERSION or ELASTIC_PASSWORD not set in .env file. Please check your .env file."
    exit 1
fi

echo "--- Starting ELK Stack (Version: ${ES_VERSION}) ---"

# Step 1: Generate TLS Certificates if not already present
echo "[1/5] Checking for existing TLS certificates..."
if [ ! -f "${CERTS_DIR}/ca.crt" ]; then
    echo "Certificates not found. Generating new TLS certificates..."
    if ! docker-compose --profile setup up tls-setup; then
        echo "ERROR: Failed to generate TLS certificates."
        exit 1
    fi
    echo "TLS certificates generated successfully."
else
    echo "Existing TLS certificates found. Skipping generation."
fi

# Step 2: Start Elasticsearch
echo "[2/5] Starting Elasticsearch service..."
if ! docker-compose up -d elasticsearch; then
    echo "ERROR: Failed to start Elasticsearch."
    exit 1
fi

echo "Waiting for Elasticsearch to be healthy (this may take a minute or two)..."
MAX_RETRIES=30
RETRY_COUNT=0
HEALTHY=false
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker-compose ps elasticsearch | grep -q "healthy"; then
        HEALTHY=true
        break
    fi
    if ! docker-compose ps elasticsearch | grep -q "running\|starting"; then
        echo "ERROR: Elasticsearch container is not running. Check logs: docker-compose logs elasticsearch"
        exit 1;
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Elasticsearch not healthy yet (attempt ${RETRY_COUNT}/${MAX_RETRIES}). Waiting 10 seconds..."
    sleep 10
done

if [ "$HEALTHY" != "true" ]; then
    echo "ERROR: Elasticsearch did not become healthy after ${MAX_RETRIES} attempts."
    echo "Check Elasticsearch logs: docker-compose logs elasticsearch"
    exit 1
fi
echo "Elasticsearch is healthy."

# Step 3: Reset kibana_system password and update .env
echo "[3/5] Resetting password for 'kibana_system' user in Elasticsearch..."
NEW_KIBANA_PASSWORD=$(docker exec -i elasticsearch_cr /usr/share/elasticsearch/bin/elasticsearch-reset-password \
    -u kibana_system \
    --url "https://localhost:9200" \
    -E xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/ca/ca.crt \
    -E xpack.security.http.ssl.verification_mode=certificate \
    -E elasticsearch.username=elastic \
    -E elasticsearch.password="${ELASTIC_PASSWORD}" \
    -s -b 2>/dev/null || true) # Capture output, allow non-zero exit if already set or other benign issues

if [[ -n "$NEW_KIBANA_PASSWORD" && "$NEW_KIBANA_PASSWORD" != *"ERROR"* && "$NEW_KIBANA_PASSWORD" != *"Failed"* ]]; then
    echo "Successfully reset/retrieved password for kibana_system."
    update_env_var "KIBANA_SYSTEM_PASSWORD" "${NEW_KIBANA_PASSWORD}" "${ENV_FILE}"
else
    echo "Warning: Could not automatically reset/retrieve kibana_system password."
    echo "This might be okay if it was already set and KIBANA_SYSTEM_PASSWORD in .env is correct."
    echo "If Kibana fails to connect, you may need to manually reset it and update .env:"
    echo "  docker exec -it elasticsearch_cr /usr/share/elasticsearch/bin/elasticsearch-reset-password -u kibana_system --url \"https://localhost:9200\""
    # Attempt to re-source .env in case KIBANA_SYSTEM_PASSWORD was already manually set and valid
    # shellcheck source=.env
    source "${ENV_FILE}"
    if [[ "${KIBANA_SYSTEM_PASSWORD}" == "this_will_be_auto_updated" ]] || [ -z "${KIBANA_SYSTEM_PASSWORD}" ]; then
        echo "ERROR: KIBANA_SYSTEM_PASSWORD is not properly set in .env and auto-reset failed."
        echo "Please manually reset the kibana_system password and update KIBANA_SYSTEM_PASSWORD in .env."
        exit 1
    fi
fi
# Re-source .env one last time to ensure docker-compose gets the updated KIBANA_SYSTEM_PASSWORD
# shellcheck source=.env
source "${ENV_FILE}"

# Step 4: Start Kibana
echo "[4/5] Starting Kibana service..."
# We need to pass the KIBANA_SYSTEM_PASSWORD to the Kibana container's environment
# This is done via docker-compose reading the .env file
if ! KIBANA_SYSTEM_PASSWORD="${KIBANA_SYSTEM_PASSWORD}" docker-compose up -d kibana; then # Explicitly pass for this `up`
    echo "ERROR: Failed to start Kibana."
    exit 1
fi

# Step 5: Final message
echo "[5/5] ELK Stack startup initiated."
echo "--------------------------------------------------------------------"
echo "Elasticsearch should be available at: https://localhost:9200"
echo "  (User: elastic, Password: ${ELASTIC_PASSWORD})"
echo "Kibana should be available at: https://localhost:5601"
echo "  (Login with elastic user and password)"
echo ""
echo "To view logs: docker-compose logs -f <service_name>"
echo "To stop: docker-compose down"
echo "To uninstall: ./uninstall.sh"
echo "To clean uninstall: ./uninstall.sh --clean # Clears project files that were created by the setup"
echo "--------------------------------------------------------------------"