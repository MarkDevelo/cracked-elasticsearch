# Instructions to run cracked version of elastic
This guide provides step-by-step instructions to set up and run Elasticsearch and Kibana and upgrade license to a Platinum license, and configure a Fleet Server.

## Prerequisites

*   WSL2 with windows/linux.
*   Docker and Docker Compose installed.
*   `sudo` privileges.
*   `git` installed (to clone the repository).
*   `curl` installed (for downloading the Elastic Agent).

## 1. Installation and Initial Setup

1.  **Clone the Repository (if you haven't already) Ignore this step if you already have the project zip:**
    ```bash
    git clone https://github.com/kagenay/cracked-elasticsearch.git
    cd cracked-elastic
    ```

2. **Rename .env.example to .env:**
    ```bash
    mv .env.example .env
    ```

3. **Edit the .env file to setup the elastic version you want and other stuff:**
    ```bash
    # .env - ELK Stack Configuration
    # Please edit ELASTIC_PASSWORD before the first full run.
    ES_VERSION=8.18.0
    ELASTIC_PASSWORD=elastic_pass

    # KIBANA_SYSTEM_PASSWORD will be automatically set by the start-elk.sh script
    # after resetting the kibana_system user's password in Elasticsearch.
    # You can manually set it here if you reset it some other way and want docker-compose to use it.
    KIBANA_SYSTEM_PASSWORD=F21MZEMc=90Su6L5QU+u
    ```
4. **Run the setup and installation scripts:**
    ```bash
    sudo ./setup-cracked-elk.sh
    sudo ./start-elk.sh
    ```
5. **Now if everything went well without any errors, it should be up and runnning :)**
6. **If you wanna uninstall/stop the docker containers use sudo `sudo ./uninstall.sh` or add `--clean` if you want to remove the folders and files created by the installation.

## 2. Upgrade License to Platinum

1.  In Kibana, navigate to **Stack Management** -> **License Management**.
2.  Click on **Update license**.
3.  Drag and drop the `platinum_license.json` file (located in the root directory) into the upload area, or browse to select it.
4.  Click **Upload**. Your license should now be upgraded to Platinum.

## 3. Setting Up a Fleet Server

Fleet Server acts as a control plane for managing Elastic Agents.

1.  **Navigate to Fleet in Kibana:**
    Go to **Management** -> **Fleet**.

2.  **Add a Fleet Server:**
    *   Click **"Add Fleet Server"**.
    *   Configure the Fleet Server details. For a quick start or local setup:
        *   **Name:** `fleet-server` (or any name you prefer)
        *   **Host URL:** `https://127.0.0.1:8220`
            *   *Note: This URL is what other Elastic Agents will use to connect to this Fleet Server. If agents are outside the host machine or in different Docker networks, adjust `127.0.0.1` to an accessible IP/hostname of the machine where the Fleet Server agent will run.*

3.  **Generate Fleet Server Policy & Enrollment Token:**
    *   Click **"Generate Fleet Server policy"** (or similar, the button text may vary slightly by version).
    *   Kibana will then display a set of commands to enroll an Elastic Agent as a Fleet Server. This typically includes steps to download, extract, and install the agent.

4.  **Execute the Kibana-Provided Commands:**
    **It is crucial to use the exact commands and tokens provided by *your* Kibana UI.** The steps and values below are an *example* of what Kibana might show for version `8.18.0`.

    a.  **Prepare a directory for the Fleet Server agent (on the machine where you'll run it):**

        mkdir -p fleet-server # Or any directory name you prefer
        cd fleet-server

    b.  **Follow the commands shown in Kibana. They will look similar to this:**

        i.  **Download the Elastic Agent (Kibana will provide the correct URL for your version):**
            # Example for 8.18.0, Kibana will show the appropriate version
            curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.18.0-linux-x86_64.tar.gz

        ii. **Extract the agent:**
            # Example for 8.18.0
            tar xzvf elastic-agent-8.18.0-linux-x86_64.tar.gz

        iii.    **Navigate into the agent directory:**
            # Example for 8.18.0
            cd elastic-agent-8.18.0-linux-x86_64

        iv. **Run the Elastic Agent install command (Kibana will provide this full command with your specific tokens and fingerprints):**
            # !! IMPORTANT: Use the exact command from YOUR KIBANA UI !!
            # The token and fingerprint below are EXAMPLES ONLY and will NOT work.
            sudo ./elastic-agent install \
              --fleet-server-es=https://172.18.0.2:9200 \
              --fleet-server-service-token=AAEAAWVsYXN0aWMvZmxlZXQtc2VydmVyL3Rva2VuLTE3NDY2OTA1NDc5NTI6c3MyTHJMNlBUOHlHeTltWW56UXN5dw \
              --fleet-server-policy=fleet-server-policy \ # Or the policy ID from Kibana
              --fleet-server-es-ca-trusted-fingerprint=1d711f1f8ca34c91bbe256ef2a7dca1c2b77379a18007778a5305456a75c9abb \
              --fleet-server-port=8220 \
              --insecure # Often needed for self-signed certs in dev setups

            *   `--fleet-server-es`: Should point to your Elasticsearch Docker container (e.g., `https://<docker-elasticsearch-ip>:9200`). `172.18.0.2` is an example internal Docker IP; yours might differ. You can find it using `docker inspect elastic0`.
            *   `--fleet-server-service-token`: **Must be copied from Kibana.**
            *   `--fleet-server-es-ca-trusted-fingerprint`: **Must be copied from Kibana.**
            *   `--insecure`: May be required if using the default self-signed certificates from the `cracked-elastic` setup. Kibana might include this flag in its generated command if it detects a self-signed certificate environment.

5.  **Confirm Connection in Kibana:**
    Once the Elastic Agent (acting as Fleet Server) is installed and running successfully, head back to the Fleet UI in Kibana. You should see the Fleet Server attempting to connect or already connected. Click **"Confirm connection"** or **"Continue enrolling Elastic Agent"** if prompted.

## 4. Managing Elastic Agents (Troubleshooting)

### Force Removing an Elastic Agent (if installed as a service)

If you need to completely remove an Elastic Agent that was installed as a system service (e.g., the Fleet Server agent):

1.  **Stop the agent service:**
    ```bash
    sudo systemctl stop elastic-agent.service
    ```
2.  **(Optional) Force kill if stop doesn't work:**
    ```bash
    sudo systemctl kill --signal=SIGKILL elastic-agent.service
    ```
3.  **Disable the service from starting on boot:**
    ```bash
    sudo systemctl disable elastic-agent.service
    ```
4.  **Remove the systemd service file:**
    ```bash
    sudo rm /etc/systemd/system/elastic-agent.service
    ```
5.  **Reload systemd manager configuration:**
    ```bash
    sudo systemctl daemon-reload
    ```
6.  **Reset the failed state of the service (if any):**
    ```bash
    sudo systemctl reset-failed
    ```
7.  **Remove the agent installation directory (default is `/opt/Elastic/Agent/`):**
    ```bash
    sudo rm -rf /opt/Elastic/Agent/
    ```