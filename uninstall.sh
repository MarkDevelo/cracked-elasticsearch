#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# List of items to remove in --clean mode.
# Use relative paths from where the script is run.
CLEAN_TARGETS=(
    "crack-builder/output"
    "es_host_data"
    "es_host_config"
    "crack"
)

# --- Helper Functions ---
log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# --- Argument Parsing ---
CLEAN_MODE=false
if [[ "$1" == "--clean" ]]; then
    CLEAN_MODE=true
    log_info "--clean flag detected. Additional files and directories will be removed."
elif [[ -n "$1" ]]; then # If any argument is given and it's not --clean
    log_error "Invalid argument: $1"
    echo "Usage: $0 [--clean]"
    echo "  --clean   Additionally removes specific project files and directories."
    exit 1
fi

# --- Docker Compose Cleanup (Normal Operation) ---
log_info "Stopping and removing Docker Compose services, networks, and volumes..."

# Attempt to run with --profile setup first, ignore if it fails (e.g., profile doesn't exist)
log_info "Attempting 'docker-compose --profile setup down -v'..."
if docker-compose --profile setup down -v; then
    log_info "'docker-compose --profile setup down -v' completed successfully."
else
    log_warn "'docker-compose --profile setup down -v' failed or no 'setup' profile found. This might be expected. Continuing..."
fi

# Always run the standard down -v
log_info "Attempting 'docker-compose down -v'..."
if docker-compose down -v; then
    log_info "'docker-compose down -v' completed successfully."
else
    log_warn "'docker-compose down -v' failed. Please check Docker Compose output. Continuing..."
fi

log_info "Docker cleanup phase complete."
echo "" # Add a newline for readability

# --- Additional Cleanup (if --clean is specified) ---
if [ "$CLEAN_MODE" == "true" ]; then
    log_warn "--- Executing --clean Operation ---"
    echo "The following items will be PERMANENTLY DELETED using sudo:"
    for target in "${CLEAN_TARGETS[@]}"; do
        echo "  - $target"
    done
    echo ""

    # Confirmation prompt
    read -r -p "Are you absolutely sure you want to proceed with these deletions? (Type 'yes' to confirm): " confirmation

    if [[ "$confirmation" == "yes" ]]; then
        log_info "User confirmed. Proceeding with deletions..."
        for target in "${CLEAN_TARGETS[@]}"; do
            if [ -e "$target" ]; then
                log_info "Removing '$target'..."
                sudo rm -rf "$target"
                log_info "'$target' removed."
            else
                log_info "'$target' does not exist, skipping."
            fi
        done
        log_info "--clean operation completed."
    else
        log_info "--clean operation aborted by user."
    fi
fi

echo ""
log_info "Uninstallation process finished."