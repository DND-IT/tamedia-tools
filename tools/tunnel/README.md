# tamedia-tunnel

AWS service tunneling tool for Kubernetes that creates secure connections to DocumentDB, RDS, and ElastiCache instances through Kubernetes pods.

## Features

- Interactive service and instance selection with fzf fuzzy search
- Automatic AWS Secrets Manager integration with fzf support
- Smart port management (finds available ports)
- Automatic cleanup on exit with fzf-powered prompts
- Support for DocumentDB, RDS (PostgreSQL/MySQL), ElastiCache (Redis/Valkey)
- Custom service tunneling (specify your own host/port)
- Graceful fallback to manual selection when fzf is not installed

## Usage

```bash
tamedia-tunnel
```

The tool will guide you through:
1. Service type selection (AWS services or custom)
2. Instance/endpoint selection
3. Secret selection (with fuzzy search if fzf is installed)
4. Automatic tunnel creation and port forwarding

## Requirements

- AWS CLI configured with appropriate permissions
- kubectl configured for your Kubernetes cluster
- jq for JSON processing
- fzf (highly recommended for interactive selections)

### Installing fzf

For the best experience, install fzf:

```bash
# macOS
brew install fzf

# Linux
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
```

## Examples

After running `tamedia-tunnel` and selecting your service/instance, you'll get ready-to-use connection commands:

```bash
# DocumentDB
mongosh "mongodb://localhost:27017/mydb?retryWrites=false" --username admin --password "$(aws secretsmanager get-secret-value --secret-id 'my-secret' --query SecretString --output text | jq -r '.password')"

# PostgreSQL
psql "postgresql://username:$(aws secretsmanager get-secret-value --secret-id 'my-secret' --query SecretString --output text | jq -r '.password')@localhost:5432/mydb"

# Redis
redis-cli -h localhost -p 6379

# Custom service example
# Connect to localhost:8080 (which tunnels to your-service.example.com:8080)
curl http://localhost:8080/api/health
```