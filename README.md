# 🐳 Docker Deploy Action

[![Deploy Test](https://github.com/alcharra/docker-deploy-action/actions/workflows/deploy-test.yml/badge.svg)](https://github.com/alcharra/docker-deploy-action/actions/workflows/deploy-test.yml)
[![GitHub tag](https://img.shields.io/github/tag/alcharra/docker-deploy-action.svg)](https://github.com/alcharra/docker-deploy-action-go/releases)
[![ShellCheck](https://github.com/alcharra/docker-deploy-action/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/alcharra/docker-deploy-action/actions/workflows/shellcheck.yml)

A **production-ready** GitHub Action for deploying **Docker Compose** or **Docker Swarm** services over SSH.  

This action securely **uploads deployment files**, ensures the **target server is ready** and **automates network creation** if needed. It deploys services with **health checks, rollback support and optional cleanup** to keep your infrastructure stable.

> [!NOTE]  
> A faster, lightweight alternative built with Go is now available!  
> Check out [docker-deploy-action-go](https://github.com/alcharra/docker-deploy-action-go) – same features, better performance 🚀  
> 🛠️ **This action will continue to be actively maintained and updated.**

## What This Action Brings You

This GitHub Action makes your Docker deployments smooth, secure and reliable — whether you’re using Docker Compose or Swarm. Here's what you get out of the box:

- **📂 Flexible Deployments:** Deploy Docker Compose or Swarm stacks seamlessly over SSH to any Linux server.
- **🛠️ Smart Setup:** Automatically creates the target project directory with the correct permissions and ownership.
- **📦 Full Config Support:** Upload multiple config and environment files (`.env`, secrets, YAML, etc.) effortlessly.
- **🔑 Private Registry Access:** Supports secure login to private registries like Docker Hub and GHCR.
- **🌐 Network Intelligence:** Ensures required Docker networks exist or creates them automatically with your chosen driver.
- **🩺 Health-First Deployments:** Built-in health checks confirm services are running and stable after deployment.
- **♻️ Auto-Rollback on Failures:**  
  - **Swarm:** Uses Docker's native `--rollback` feature.  
  - **Compose:** Restores the last known working deployment file.
- **🧹 Optional Cleanup:** Reclaim disk space with Docker prune—configurable by type.
- **📜 Transparent Logs:** Get structured logs for every step — from file transfers to health checks.
- **🛡️ Built-In Security:** SSH keys are securely handled and wiped after deployment to keep your infrastructure safe.
- **🚀 Fast Automation:** No need for manual SSH commands — just push to GitHub and deploy!

## Inputs

| Input Parameter             | Description                                                                                          | Required | Default Value        |
| --------------------------- | ---------------------------------------------------------------------------------------------------- | :------: | -------------------- |
| `ssh_host`                  | Hostname or IP address of the target server                                                          |    ✅    |                      |
| `ssh_port`                  | Port used for the SSH connection                                                                     |    ❌    | `22`                 |
| `ssh_user`                  | Username used for the SSH connection                                                                 |    ✅    |                      |
| `ssh_key`                   | Private SSH key for authentication                                                                   |    ✅    |                      |
| `ssh_key_passphrase`        | Passphrase for the encrypted SSH private key                                                         |    ❌    |                      |
| `ssh_known_hosts`           | Contents of the SSH `known_hosts` file used to verify the server's identity                          |    ❌    |                      |
| `fingerprint`               | SSH host fingerprint for verifying the server's identity (SHA256 format)                             |    ❌    |                      |
| `timeout`                   | SSH connection timeout in seconds (e.g. `10`, `30`, `60`)                                            |    ❌    | `10`                |
| `project_path`              | Path on the server where files will be uploaded                                                      |    ✅    |                      |
| `deploy_file`               | Path to the file used for defining the deployment (e.g. Docker Compose)                              |    ✅    | `docker-compose.yml` |
| `extra_files`               | Additional files to upload (e.g. `.env`, config files)                                               |    ❌    |                      |
| `mode`                      | Deployment mode (`compose` or `stack`)                                                               |    ❌    | `compose`            |
| `stack_name`                | Stack name used during Swarm deployment (required if mode is `stack`)                                |    ❌    |                      |
| `compose_pull`              | Whether to pull the latest images before bringing up services with Docker Compose (`true` / `false`) |    ❌    | `true`               |
| `docker_network`            | Name of the Docker network to be used or created if missing                                          |    ❌    |                      |
| `docker_network_driver`     | Driver for the network (`bridge`, `overlay`, `macvlan`, etc.)                                        |    ❌    | `bridge`             |
| `docker_network_attachable` | Whether standalone containers can attach to the network (`true` / `false`)                           |    ❌    | `false`              |
| `docker_prune`              | Type of Docker resource prune to run after deployment                                                |    ❌    | `none`               |
| `registry_host`             | Host address for the registry or remote service requiring authentication                             |    ❌    |                      |
| `registry_user`             | Username for authenticating with the registry or remote service                                      |    ❌    |                      |
| `registry_pass`             | Password or token for authenticating with the registry or remote service                             |    ❌    |                      |
| `enable_rollback`           | Whether to enable automatic rollback if deployment fails (`true` / `false`)                          |    ❌    | `false`              |

## SSH Host Key Verification

This tool supports two secure options for verifying the SSH server's identity during deployment:

- Providing a `known_hosts` entry (OpenSSH-compatible format)
- Supplying the server's SSH key `fingerprint` (a single-line public key)

You only need to provide one of these — not both.

> [!WARNING]  
> If neither `ssh_known_hosts` nor `fingerprint` is specified, the tool will fall back to scanning the server key using `ssh-keyscan`.  
> While this avoids prompts during automation, it does not confirm the authenticity of the host key.  
> This approach is not secure and should not be used in production environments.

> [!IMPORTANT]  
> For a secure deployment, always provide either a `known_hosts` entry or a `fingerprint`.  
> This helps ensure that the connection is made to the correct server and prevents impersonation.

> [!TIP]  
> Use `ssh_known_hosts` for full compatibility with OpenSSH and to support multiple key types.  
> Use `fingerprint` for a simpler, one-line setup if connecting to a single known host.  
> In either case, store the value securely using a GitHub environment variable or secret.

## Supported Prune Types

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
      - name: Checkout code
        uses: actions/checkout@v4

      # Example 1: Deploy using Docker Stack
      - name: Deploy using Docker Stack
        uses: alcharra/docker-deploy-action-go@v1
        with:
          # Required SSH configuration
          ssh_host: ${{ secrets.SSH_HOST }}              # Hostname or IP address of the target server
          ssh_user: ${{ secrets.SSH_USER }}              # SSH username
          ssh_key: ${{ secrets.SSH_KEY }}                # Private SSH key for authentication
          project_path: /opt/myapp                       # Remote path where project files will be uploaded

          # Deployment configuration
          deploy_file: docker-stack.yml                  # Path to the Docker Stack file
          mode: stack                                    # Deployment mode
          stack_name: myapp                              # Name of the Docker stack to deploy

          # Optional SSH security settings
          ssh_key_passphrase: ${{ secrets.SSH_KEY_PASSPHRASE }}   # Passphrase for the SSH key, if encrypted
          ssh_known_hosts: ${{ secrets.SSH_KNOWN_HOSTS }}         # SSH known_hosts contents to verify server identity
          fingerprint: ${{ secrets.SSH_FINGERPRINT }}             # SSH host fingerprint for additional verification

          # Additional files to include in the deployment
          extra_files: traefik.yml                  # Comma-separated list of extra files to upload

          # Docker network configuration
          docker_network: myapp_network                  # Name of the Docker network to use
          docker_network_driver: overlay                 # Driver for the Docker network

          # Cleanup after deployment
          docker_prune: system                           # Type of Docker prune to perform

          # Registry authentication (for pulling private images)
          registry_host: ghcr.io
          registry_user: ${{ github.actor }}
          registry_pass: ${{ secrets.GITHUB_TOKEN }}

      # Example 2: Deploy using Docker Compose
      - name: Deploy using Docker Compose
        uses: alcharra/docker-deploy-action-go@v1
        with:
          # Required SSH configuration
          ssh_host: ${{ secrets.SSH_HOST }}              # Hostname or IP address of the target server
          ssh_user: ${{ secrets.SSH_USER }}              # SSH username
          ssh_key: ${{ secrets.SSH_KEY }}                # Private SSH key for authentication
          project_path: /opt/myapp                       # Remote path where project files will be uploaded

          # Deployment configuration
          deploy_file: docker-compose.yml                # Path to the Docker Compose file
          mode: compose                                  # Deployment mode

          # Optional SSH security settings
          ssh_key_passphrase: ${{ secrets.SSH_KEY_PASSPHRASE }}   # Passphrase for the SSH key, if encrypted
          ssh_known_hosts: ${{ secrets.SSH_KNOWN_HOSTS }}         # SSH known_hosts contents to verify server identity
          fingerprint: ${{ secrets.SSH_FINGERPRINT }}             # SSH host fingerprint for additional verification

          # Additional files to include in the deployment
          extra_files: .env,database.env,nginx.conf      # Comma-separated list of extra files to upload

          # Deployment behaviour
          compose_pull: true                             # Pull the latest images before starting services
          enable_rollback: true                          # Enable rollback if deployment fails

          # Docker network configuration
          docker_network: myapp_network                  # Name of the Docker network to use
          docker_network_driver: bridge                  # Driver for the Docker network

          # Cleanup after deployment
          docker_prune: system                           # Type of Docker prune to perform

          # Registry authentication (for pulling private images)
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