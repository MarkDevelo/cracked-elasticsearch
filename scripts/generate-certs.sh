#!/bin/bash
set -e

# Arguments:
# $1: Path to instances.yml inside the container
# $2: Path to the output directory for certificates inside the container

INSTANCES_YML_PATH="$1"
CERTS_OUTPUT_DIR="$2"
ES_VERSION_FOR_CERTUTIL="8.18.0" # Or pass as an arg if needed, but usually bundled with the image

echo "--- Generating TLS Certificates ---"
echo "Using instances file: ${INSTANCES_YML_PATH}"
echo "Outputting certificates to: ${CERTS_OUTPUT_DIR}"

# Ensure output directory exists
mkdir -p "${CERTS_OUTPUT_DIR}"

# Generate CA
echo "Generating CA..."
elasticsearch-certutil ca --silent --pem --out "${CERTS_OUTPUT_DIR}/ca-bundle.zip"
unzip -q -o "${CERTS_OUTPUT_DIR}/ca-bundle.zip" -d "${CERTS_OUTPUT_DIR}"
# Result: ${CERTS_OUTPUT_DIR}/ca/ca.crt and ${CERTS_OUTPUT_DIR}/ca/ca.key

# Generate certificates for each instance defined in instances.yml
# We need to parse the instances.yml to get the names, DNS, and IPs.
# A more robust yml parser would be 'yq', but for simplicity, we'll use grep/awk if it's simple enough.
# For a robust solution, consider installing 'yq' in the Dockerfile for the tls-setup service.

# Simple parsing (assumes simple structure, no complex YAML features)
# This is a bit fragile. Using 'yq' would be much better.
# Example using yq (if installed):
# yq e '.instances[] | select(.name != "ca") | .name' "${INSTANCES_YML_PATH}" | while read -r instance_name; do
#     echo "Generating certificate for ${instance_name}..."
#     # Extract DNS and IP for this instance (more complex with yq)
#     elasticsearch-certutil cert --silent --pem \
#         --ca-cert "${CERTS_OUTPUT_DIR}/ca/ca.crt" \
#         --ca-key "${CERTS_OUTPUT_DIR}/ca/ca.key" \
#         --name "${instance_name}" \
#         --dns "$(yq e ".instances[] | select(.name == \"${instance_name}\") | .dns | .[]" "${INSTANCES_YML_PATH}" | paste -sd, -)" \
#         --ip "$(yq e ".instances[] | select(.name == \"${instance_name}\") | .ip | .[]" "${INSTANCES_YML_PATH}" | paste -sd, -)" \
#         --out "${CERTS_OUTPUT_DIR}/${instance_name}-bundle.zip"
#
#     unzip -q -o "${CERTS_OUTPUT_DIR}/${instance_name}-bundle.zip" -d "${CERTS_OUTPUT_DIR}"
# done

# --- Alternative without yq (more manual, less flexible from instances.yml for now) ---
# We'll manually list them here based on instances.yml for this example.
# This means if you add a new service to instances.yml, you need to update this script.

declare -A INSTANCE_DNS
declare -A INSTANCE_IP

# Populate from instances.yml (manual mapping for this script)
INSTANCE_DNS["elasticsearch"]="elasticsearch,localhost"
INSTANCE_IP["elasticsearch"]="127.0.0.1"

INSTANCE_DNS["kibana"]="kibana,localhost"
INSTANCE_IP["kibana"]="127.0.0.1"

for instance_name in "${!INSTANCE_DNS[@]}"; do
    echo "Generating certificate for ${instance_name}..."
    
    dns_list="${INSTANCE_DNS[$instance_name]}"
    ip_list="${INSTANCE_IP[$instance_name]}"

    cmd_args="--silent --pem"
    cmd_args+=" --ca-cert \"${CERTS_OUTPUT_DIR}/ca/ca.crt\""
    cmd_args+=" --ca-key \"${CERTS_OUTPUT_DIR}/ca/ca.key\""
    cmd_args+=" --name \"${instance_name}\""
    
    if [ -n "$dns_list" ]; then
        cmd_args+=" --dns \"$dns_list\""
    fi
    if [ -n "$ip_list" ]; then
        cmd_args+=" --ip \"$ip_list\""
    fi
    
    cmd_args+=" --out \"${CERTS_OUTPUT_DIR}/${instance_name}-bundle.zip\""

    # Using eval to correctly handle spaces in quoted arguments for --dns and --ip
    eval "elasticsearch-certutil cert $cmd_args"

    unzip -q -o "${CERTS_OUTPUT_DIR}/${instance_name}-bundle.zip" -d "${CERTS_OUTPUT_DIR}"
    # Result: ${CERTS_OUTPUT_DIR}/${instance_name}/${instance_name}.crt and .key
done

echo "--- TLS Certificate generation complete ---"
echo "Certificates are in ${CERTS_OUTPUT_DIR}"
ls -R "${CERTS_OUTPUT_DIR}"