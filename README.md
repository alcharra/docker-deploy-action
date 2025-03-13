# 🐳 Docker Deploy Action

This GitHub Action deploys Docker Compose or Docker Swarm services over SSH. It uploads files to a remote server, checks they are present, creates a Docker network if required, deploys the services and optionally runs a Docker prune after deployment.

## Features

- Upload Docker Compose or Stack files to a remote server over SSH
- Automatically creates the target project folder if it does not exist (with correct ownership and permissions)
- Supports uploading additional files like `.env`, `traefik.yml` or custom configs
- Supports authenticated Docker registry login (for private images)
- Creates Docker networks if required, with configurable driver
- Deploys services using either Docker Compose or Docker Swarm (with support for `--with-registry-auth` in Swarm mode)
- Verifies services are healthy after deployment
- Optionally runs a Docker prune to free up unused resources
- Provides clear logs for all steps (including file transfers, Docker network management and service verification)
- Automatically cleans up temporary SSH key files

## Inputs

|  Input Parameter          |  Description                                                  | Required     | Default Value        |
| ------------------------- | ------------------------------------------------------------- | :----------: | -------------------- |
| `ssh_host`                |  Hostname or IP of the target server                          | ✅          |                      |
| `ssh_port`                |  SSH port                                                     | ❌          | `22`                 |
| `ssh_user`                |  SSH username                                                 | ✅          |                      |
| `ssh_key`                 |  SSH private key                                              | ✅          |                      |
| `project_path`            |  Path on the server where files will be uploaded              | ✅          |                      |
| `deploy_file`             |  Path to the Docker Compose or Stack file used for deployment | ✅          | `docker-compose.yml` |
| `extra_files`             |  Additional files to upload (like `.env` or `traefik.yml`)    | ❌          |                      |
| `mode`                    |  Deployment mode (`compose` or `stack`)                       | ❌          | `compose`            |
| `stack_name`              |  Swarm stack name (only used if `mode` is `stack`)            | ❌          |                      |
| `docker_network`          |  Docker network name to ensure exists                         | ❌          |                      |
| `docker_network_driver`   |  Network driver (`bridge`, `overlay`, `macvlan`, etc.)        | ❌          |                      |
| `docker_prune`            |  Type of Docker prune to run after deployment                 | ❌          |                      |
| `registry_host`           |  Registry Authentication Host                                 | ❌          |                      |
| `registry_user`           |  Registry Authentication User                                 | ❌          |                      |
| `registry_pass`           |  Registry Authentication Pass                                 | ❌          |                      |

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
        uses: alcharra/docker-deploy-action@v1
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
        uses: alcharra/docker-deploy-action@v1
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

## How It Works

1. A temporary SSH key file is created for connecting to the target server
2. The action checks if `project_path` exists on the remote server, creating it if necessary with proper ownership and permissions
3. All specified files (`compose`, `stack` and `extra_files`) are uploaded to the remote project directory
4. After upload, the action verifies that all files exist on the remote server
5. If registry credentials are provided, the action logs into the container registry to support pulling private images
6. The action ensures the specified Docker network exists, creating it if required
7. The action deploys the services using either `docker-compose` or `docker stack deploy`, depending on the configured mode
8. After deployment, the action verifies that all services are running correctly
9. Optionally, the action runs a Docker prune (type can be configured)
10. Finally, the temporary SSH key file is removed to ensure no sensitive files remain on disk

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