# 🐳 Docker Deploy Action

> [!WARNING]
> **DEPRECATED – This repository is no longer maintained.**  
> Please use the new, improved Go-based version instead:  
> [docker-deploy-action-go](https://github.com/alcharra/docker-deploy-action-go)

[![Deploy Test](https://github.com/alcharra/docker-deploy-action/actions/workflows/deploy-test.yml/badge.svg)](https://github.com/alcharra/docker-deploy-action/actions/workflows/deploy-test.yml)
[![GitHub tag](https://img.shields.io/github/tag/alcharra/docker-deploy-action.svg)](https://github.com/alcharra/docker-deploy-action-go/releases)
[![ShellCheck](https://github.com/alcharra/docker-deploy-action/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/alcharra/docker-deploy-action/actions/workflows/shellcheck.yml)

A **production-ready** GitHub Action for deploying **Docker Compose** or **Docker Swarm** services over SSH.  

This action securely **uploads deployment files**, ensures the **target server is ready** and **automates network creation** if needed. It deploys services with **health checks, rollback support and optional cleanup** to keep your infrastructure stable.

## What This Action Brings You

This GitHub Action makes your Docker deployments smooth, secure and reliable — whether you’re using Docker Compose or Swarm. Here's what you get out of the box:

- **Flexible Deployments:** Deploy Docker Compose or Swarm stacks seamlessly over SSH to any Linux server.
- **Smart Setup:** Automatically creates the target project directory with the correct permissions and ownership.
- **Full Configuration Support:** Upload multiple configuration and environment files (`.env`, secrets, YAML, etc.) effortlessly.
- **Private Registry Access:** Supports secure login to private registries such as Docker Hub and GHCR.
- **Network Intelligence:** Ensures required Docker networks exist or creates them automatically with your chosen driver.
- **Health-First Deployments:** Built-in health checks confirm services are running and stable after deployment.
- **Auto-Rollback on Failures:**  
  - **Swarm:** Uses Docker's native `--rollback` feature.  
  - **Compose:** Restores the last known working deployment file.
- **Optional Cleanup:** Reclaim disk space with Docker prune — configurable by type.
- **Transparent Logs:** Provides structured logs for every step — from file transfers to health checks.
- **Built-In Security:** SSH keys are securely handled and removed after deployment to keep your infrastructure safe.
- **Fast Automation:** No need for manual SSH commands — simply push to GitHub and deploy!

## Inputs

| Input Parameter             | Description                                                                             | Required | Default Value        |
| --------------------------- | --------------------------------------------------------------------------------------- | :------: | -------------------- |
| `ssh_host`                  | The hostname or IP address of the remote server you’re deploying to                     |    ✅    |                      |
| `ssh_port`                  | The port used to connect via SSH                                                        |    ❌    | `22`                 |
| `ssh_user`                  | The SSH username used to connect to the server                                          |    ✅    |                      |
| `ssh_key`                   | Your private SSH key for authenticating with the server                                 |    ✅    |                      |
| `ssh_key_passphrase`        | The passphrase used to unlock the SSH key                                               |    ❌    |                      |
| `ssh_known_hosts`           | The contents of your `known_hosts` file, used to verify the server’s identity           |    ❌    |                      |
| `fingerprint`               | The server’s SSH fingerprint in SHA256 format (alternative to `known_hosts`)            |    ❌    |                      |
| `timeout`                   | SSH connection timeout in seconds (e.g. `10`, `30`, `60`)                               |    ❌    | `10`                 |
| `project_path`              | The full path on the server where files will be uploaded and deployed                   |    ✅    |                      |
| `deploy_file`               | The name of your main deployment file (e.g. `docker-compose.yml` or `docker-stack.yml`) |    ✅    | `docker-compose.yml` |
| `extra_files`               | A list of extra files or folders to upload. Use a multi-line format — one path per line |    ❌    |                      |
| `mode`                      | Deployment method: either `compose` or `stack`                                          |    ❌    | `compose`            |
| `stack_name`                | Name of the Docker stack (required if using `stack` mode)                               |    ❌    |                      |
| `compose_pull`              | Pull the latest images before starting services (`true` or `false`)                     |    ❌    | `true`               |
| `compose_build`             | Build images before starting services (`true` or `false`)                               |    ❌    | `false`              |
| `compose_no_deps`           | Skip starting linked services (`true` or `false`)                                       |    ❌    | `false`              |
| `compose_target_services`   | A list of specific services to restart. Use a multi-line format — one service per line  |    ❌    |                      |
| `docker_network`            | The name of the Docker network to use or create if missing                              |    ❌    |                      |
| `docker_network_driver`     | The network driver to use (`bridge`, `overlay`, etc.)                                   |    ❌    | `bridge`             |
| `docker_network_attachable` | Allow standalone containers to attach to the network (`true` or `false`)                |    ❌    | `false`              |
| `docker_prune`              | Type of Docker clean-up to run after deployment (e.g. `system`, `volumes`, `none`)      |    ❌    | `none`               |
| `registry_host`             | The container registry hostname (e.g. `ghcr.io`) if login is required                   |    ❌    |                      |
| `registry_user`             | Username for the registry                                                               |    ❌    |                      |
| `registry_pass`             | Password or token for the registry                                                      |    ❌    |                      |
| `enable_rollback`           | Automatically roll back if deployment fails (`true` or `false`)                         |    ❌    | `false`              |
| `env_vars`                  | Environment variables to include in a `.env` file uploaded to the server                |    ❌    |                      |

## SSH Host Key Verification

To securely verify the identity of your SSH server, you can use **either** of the following:

- A `known_hosts` entry (compatible with OpenSSH)
- A SHA256 `fingerprint` of the server's host key

You only need to provide **one** — not both.

> [!IMPORTANT]  
> If neither `ssh_known_hosts` nor `fingerprint` is set, the script will automatically fetch the server’s key using `ssh-keyscan`.  
> While this avoids prompts during automation, it does **not** confirm the key's authenticity and leaves your connection vulnerable to man-in-the-middle attacks.  
> This approach is **not safe for production**. Always provide one of the verification options and store it securely using a GitHub secret or environment variable.

For most setups:
- Use `known_hosts` if you're already managing SSH access or require OpenSSH compatibility.
- Use `fingerprint` for a quick, one-line setup — ideal for connecting to a single known server.

## Supported Prune Types

You can choose what to clean up on the server after deployment by setting the `docker_prune` option. The following types are supported:

- `none` – No pruning (default)
- `system` – Remove unused images, containers, volumes and networks
- `volumes` – Remove unused volumes
- `networks` – Remove unused networks
- `images` – Remove unused images
- `containers` – Remove stopped containers

## Network Management

This action ensures the required Docker network exists before deploying. If it is missing, it will be created automatically using the specified driver.

### How it works

- If the network already exists, its driver is verified.
- If the network does not exist, it is created using the provided driver.
- If `docker_network_attachable` is set to `true`, the network is created with the `--attachable` flag.
- In `stack` mode with the `overlay` driver:
  - Swarm mode must be active on the target server.
  - A warning is displayed if Swarm is not active.
- If the existing network uses a different driver than specified, a warning is displayed.

### Network scenarios

A network will be created if:

- The specified network does not exist.
- A custom network is defined via `docker_network`.
- The provided driver is valid and supported.

Warnings will be displayed if:

- The existing network's driver does not match the one specified.
- Swarm mode is inactive but `overlay` is requested in `stack` mode.

### Example usage

```yaml
docker_network: my_network
docker_network_driver: overlay
docker_network_attachable: true
```

## Rollback Behaviour

This action supports automatic rollback if a deployment fails to start correctly.

### How it works

- In `stack` mode:

  - Docker Swarm’s built-in rollback is used.
  - The command `docker service update --rollback <service-name>` is run to revert services in the stack to the last working state.

- In `compose` mode:
  - A backup of the current deployment file is created before deployment.
  - If services fail to start, the backup is restored and Compose is re-deployed.
  - If rollback is successful, the backup file is removed to avoid stale data.

### Rollback triggers

Rollback will occur if:

- Services fail health checks.
- Containers immediately exit after starting.
- Docker returns an error during service startup.

Rollback will not occur if:

- The deployment succeeds but the application has internal errors.
- A service is manually stopped by the user.
- Rollback is disabled via `enable_rollback: false`.

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
      - name: 📦 Checkout repository
        uses: actions/checkout@v4

      # Example 1: Deploy using Docker Stack
      - name: 🚀 Deploy using Docker Stack
        uses: alcharra/docker-deploy-action@v2
        with:
          # SSH Connection
          ssh_host: ${{ secrets.SSH_HOST }} # Remote server IP or hostname
          ssh_user: ${{ secrets.SSH_USER }} # SSH username
          ssh_key: ${{ secrets.SSH_KEY }} # Private SSH key
          ssh_key_passphrase: ${{ secrets.SSH_KEY_PASSPHRASE }} # (Optional) SSH key passphrase
          ssh_known_hosts: ${{ secrets.SSH_KNOWN_HOSTS }} # (Optional) known_hosts entry

          # Deployment Settings
          project_path: /opt/myapp # Remote directory for upload and deploy
          deploy_file: docker-stack.yml # Stack file to deploy
          mode: stack # Deployment mode: 'stack'
          stack_name: myapp # Stack name on the target host

          # Additional Files
          extra_files: traefik.yml # Upload additional files (e.g. configs)

          # Docker Network Settings
          docker_network: myapp_network # Network name to use or create
          docker_network_driver: overlay # Network driver (e.g. bridge, overlay)

          # Post-Deployment Cleanup
          docker_prune: system # Prune unused Docker resources

          # Registry Authentication
          registry_host: ghcr.io
          registry_user: ${{ github.actor }}
          registry_pass: ${{ secrets.GITHUB_TOKEN }}

      # Example 2: Deploy using Docker Compose
      - name: 🚀 Deploy using Docker Compose
        uses: alcharra/docker-deploy-action@v2
        with:
          # SSH Connection
          ssh_host: ${{ secrets.SSH_HOST }}
          ssh_user: ${{ secrets.SSH_USER }}
          ssh_key: ${{ secrets.SSH_KEY }}
          fingerprint: ${{ secrets.SSH_FINGERPRINT }} # (Optional) SHA256 host fingerprint

          # Deployment Settings
          project_path: /opt/myapp
          deploy_file: docker-compose.yml
          mode: compose

          # Environment Variables 
          env_vars: |
            DB_HOST=localhost
            DB_USER=myuser
            DB_PASS=${{ secrets.DB_PASS }}

          # Additional Files
          extra_files: database.env,nginx.conf                  # Upload environment and config files

          # Compose Behaviour
          compose_pull: true # Pull latest images before up
          compose_build: true # Build images before starting services
          compose_no_deps: true # Don’t start linked services
          compose_target_services: web,db # Restart only selected services (optional)

          # Rollback Support
          enable_rollback: true # Automatically rollback on failure

          # Docker Network
          docker_network: myapp_network
          docker_network_driver: bridge

          # Post-Deployment Cleanup
          docker_prune: volumes
```

## Requirements on the Server

- Docker must be installed
- Docker Compose (if using `compose` mode)
- Docker Swarm must be initialised (if using `stack` mode)
- SSH access must be configured for the provided user and key

## Important Notes

- This action is designed for Linux servers (Debian, Ubuntu, Alpine, CentOS)
- The SSH user must have permissions to write files and run Docker commands
- If the `project_path` does not exist, it will be created with permissions `750` and owned by the provided SSH user
- If using Swarm mode, the target machine must be a Swarm manager

## References

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Docker Prune Documentation](https://docs.docker.com/config/pruning/)
- [Docker Network Documentation](https://docs.docker.com/network/)

## Tips for Maintainers

- Test the full process locally before using in GitHub Actions
- Always use GitHub Secrets for sensitive values like SSH keys
- Make sure firewall rules allow SSH access from GitHub runners

## Contributing

Contributions are welcome. If you would like to improve this action, please feel free to open a pull request or raise an issue. I appreciate your input.

## Feature Requests

Have an idea or need something this action doesn't support yet?  
Please [start a discussion](https://github.com/alcharra/docker-deploy-action/discussions/new?category=ideas) under the **Ideas** category.

This helps keep feature requests organised and visible to others who may want the same thing.

## License

This project is licensed under the [MIT License](LICENSE).