# 🐳 Docker Deploy Action  

A **production-ready** GitHub Action for deploying **Docker Compose** or **Docker Swarm** services over SSH.  

This action securely **uploads deployment files**, ensures the **target server is ready** and **automates network creation** if needed. It deploys services with **health checks, rollback support and optional cleanup** to keep your infrastructure stable.  

## 🚀 Key Features of Docker Deploy Action  

- **📂 Flexible & Seamless Deployment** – Deploy **Docker Compose** or **Docker Swarm** configurations **over SSH**, with support for different environments.  
- **🛠️ Automatic Project Setup** – Creates the **target project directory** if it doesn't exist, ensuring **correct ownership & permissions**.  
- **📦 Secure Environment Support** – Upload any **configuration or environment files** needed for your deployment.  
- **🔑 Private Registry Authentication** – Supports **secure login** to private container registries (Docker Hub, GitHub Container Registry, etc.).  
- **🌐 Intelligent Network Management** – Automatically **creates Docker networks** when required, with configurable **drivers**.  
- **🩺 Built-in Service Health Checks** – Ensures services **start correctly** and remain **healthy after deployment**.  
- **♻️ Automatic Rollback for Failed Deployments** –  
  - **Swarm Mode**: Rolls back to the **previously working state** using `docker service update --rollback`.  
  - **Compose Mode**: Restores the **last successful deployment file** if services fail to start.  
- **🧹 Automatic Cleanup & Pruning** – Optionally run **Docker prune** to free up unused resources.  
- **📜 Detailed Logs for Debugging** – Provides **clear, structured logs** for **every step**, including **file transfers, network management and verification**.  
- **🛡️ Secure by Design** – Automatically **removes sensitive SSH keys** after deployment to **enhance security**.  

---

### ⚡ **Why Use This Action?**  
🚀 **Fast & Easy:** Automate Docker deployments without manual SSH access.  
📂 **Multi-File Support:** Upload multiple **configuration files** (e.g., `.env`, secrets, custom YAML).  
🔄 **Resilient Deployments:** Automatic rollback if services fail to start.  
🩺 **Health Checks Built-In:** Ensures services are **actually running** after deployment.  
🔐 **Secure by Design:** Encrypted SSH keys, registry authentication and automatic cleanup.  
🛠️ **Full Control:** Custom networks, registry logins and detailed logs.  

## Inputs

|  Input Parameter            |  Description                                                               | Required     | Default Value        |
| -------------------------   | -------------------------------------------------------------------------- | :----------: | -------------------- |
| `ssh_host`                  |  Hostname or IP of the target server                                       | ✅          |                      |
| `ssh_port`                  |  SSH port                                                                  | ❌          | `22`                 |
| `ssh_user`                  |  SSH username                                                              | ✅          |                      |
| `ssh_key`                   |  SSH private key                                                           | ✅          |                      |
| `project_path`              |  Path on the server where files will be uploaded                           | ✅          |                      |
| `deploy_file`               |  Path to the Docker Compose or Stack file used for deployment              | ✅          | `docker-compose.yml` |
| `extra_files`               |  Additional files to upload (e.g., `.env`, config files)                   | ❌          |                      |
| `mode`                      |  Deployment mode (`compose` or `stack`)                                    | ❌          | `compose`            |
| `stack_name`                |  Swarm stack name (only used if `mode` is `stack`)                         | ❌          |                      |
| `docker_network`            |  Docker network name to ensure exists                                      | ❌          |                      |
| `docker_network_driver`     |  Network driver (`bridge`, `overlay`, `macvlan`, etc.)                     | ❌          | `bridge`             |
| `docker_network_attachable` |  Allow standalone containers to attach to the Swarm network (`true/false`) | ❌          | `false`              |
| `docker_prune`              |  Type of Docker prune to run after deployment                              | ❌          |                      |
| `registry_host`             |  Registry Authentication Host                                              | ❌          |                      |
| `registry_user`             |  Registry Authentication User                                              | ❌          |                      |
| `registry_pass`             |  Registry Authentication Pass                                              | ❌          |                      |
| `enable_rollback`           |  Enable automatic rollback if deployment fails (`true/false`)              | ❌          | `false`              |

## 🌐 **Network Management in This Action**

This action **ensures the required network exists** before deployment and automatically creates it if missing.  

### **How It Works:**
- If **the specified network exists**, it **verifies the driver** and continues deployment.  
- If **the network is missing**, it is **created automatically** using the specified driver.  
- If **Swarm Mode (`stack`)** is used with the `overlay` driver:
  - The action **checks if Swarm mode is active**.
  - If Swarm **is not active**, a **warning** is displayed since `overlay` requires Swarm for multi-node communication.
- If the **network should be attachable** (`docker_network_attachable: true`):
  - The `--attachable` flag is **added automatically**, allowing standalone containers to connect to the network.
- If an **existing network has a different driver**, a **warning is displayed**.

### **Network Scenarios:**
✅ **A Network Will Be Created If:**
- The specified network **does not exist**.
- The deployment uses **a custom network** (`docker_network` is set).
- The driver is **valid and supported**.

⚠️ **Warnings Will Be Shown If:**
- The **existing network driver differs** from the specified `docker_network_driver`.
- **Swarm mode is inactive**, but an **overlay network** is requested.

### **Example Usage:**
```yaml
docker_network: my_network
docker_network_driver: overlay
docker_network_attachable: true
```

- If `my_network` **does not exist**, it will be **created automatically**.  
- If **Swarm mode is inactive**, a **warning** is displayed, but deployment continues.  
- The network is created with `--attachable`, allowing non-Swarm containers to connect.  

For more details on Docker networking, see the [Docker Documentation](https://docs.docker.com/network/).

## 🔄 Rollback Behavior

Rollback automatically **reverts deployments** if the new deployment **fails to start properly**.

### **How It Works:**
- If **Swarm Mode (`stack`)** is used:
  - **Docker Swarm’s built-in rollback** is triggered using:  
    ```sh
    docker service update --rollback <service-name>
    ```
  - This reverts **all services in the stack** to their last working state.

- If **Compose Mode (`compose`)** is used:
  - A **backup of the previous deployment file** is created before deployment.
  - If services fail to start, the backup is **restored automatically** and Compose is re-deployed.
  - If rollback is successful, the backup is **removed** to avoid stale files.

### **Rollback Scenarios:**
✅ **Rollback Triggers If:**
- Services fail **health checks**.
- A container **immediately exits** after starting.
- Docker reports an **error during service startup**.

❌ **Rollback Will NOT Trigger If:**
- The deployment succeeds, even if the application has **internal errors**.
- A manually stopped service is detected.
- The user **disables rollback** (`enable_rollback: false`).

## Supported Prune Types

- `none`: No pruning (default)
- `system`: Remove unused images, containers, volumes and networks
- `volumes`: Remove unused volumes
- `networks`: Remove unused networks
- `images`: Remove unused images
- `containers`: Remove stopped containers

## Example Workflow

```yaml
name: Deploy

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Example 1: Deploy to Docker Swarm
      - name: Deploy to Docker Swarm
        uses: alcharra/docker-deploy-action@v2
        with:
          ssh_host: ${{ secrets.SSH_HOST }}
          ssh_user: ${{ secrets.SSH_USER }}
          ssh_key: ${{ secrets.SSH_KEY }}
          project_path: /opt/myapp
          deploy_file: docker-stack.yml
          extra_files: .env,traefik.yml
          mode: stack
          stack_name: myapp
          docker_network: myapp_network
          docker_network_driver: overlay
          docker_prune: system
          registry_host: ghcr.io
          registry_user: ${{ github.actor }}
          registry_pass: ${{ secrets.GITHUB_TOKEN }}

      # Example 2: Deploy using Docker Compose
      - name: Deploy using Docker Compose
        uses: alcharra/docker-deploy-action@v2
        with:
          ssh_host: ${{ secrets.SSH_HOST }}
          ssh_user: ${{ secrets.SSH_USER }}
          ssh_key: ${{ secrets.SSH_KEY }}
          project_path: /opt/myapp
          deploy_file: docker-compose.yml
          extra_files: .env,database.env,nginx.conf  
          mode: compose
          docker_network: myapp_network
          docker_network_driver: bridge
          docker_prune: system
          registry_host: docker.io
          registry_user: ${{ secrets.DOCKER_USERNAME }}
          registry_pass: ${{ secrets.DOCKER_PASSWORD }}
```

## Requirements on the Server

- Docker must be installed
- Docker Compose (if using `compose` mode)
- Docker Swarm must be initialised (if using `stack` mode)
- SSH access must be configured for the provided user and key

## Important Notes

- This action is designed for Linux servers (Debian, Ubuntu, etc.)
- The SSH user must have permissions to write files and run Docker commands
- If the `project_path` does not exist, it will be created with permissions `750` and owned by the provided SSH user
- If using Swarm mode, the target machine must be a Swarm manager

## References

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Docker Prune Documentation](https://docs.docker.com/config/pruning/)

## Tips for Maintainers

- Test the full process locally before using in GitHub Actions
- Always use GitHub Secrets for sensitive values like SSH keys
- Make sure firewall rules allow SSH access from GitHub runners

## Contributing

Contributions are welcome. If you would like to improve this action, please feel free to open a pull request or raise an issue. We appreciate your input.

## License

This project is licensed under the [MIT License](LICENSE).