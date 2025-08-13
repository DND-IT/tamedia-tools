# tamedia-tunnel

AWS service tunneling tool for Kubernetes that creates secure connections to DocumentDB, RDS, and ElastiCache instances through Kubernetes pods.

## Features

- Interactive service and instance selection
- Automatic AWS Secrets Manager integration with fzf support
- Smart port management (finds available ports)
- Automatic cleanup on exit
- Support for DocumentDB, RDS (PostgreSQL/MySQL), and ElastiCache (Redis/Valkey)

## Usage

```bash
tamedia-tunnel
```

The tool will guide you through:
1. Service type selection
2. Instance selection from available instances
3. Secret selection (with fuzzy search if fzf is installed)
4. Automatic tunnel creation and port forwarding

## Requirements

- AWS CLI configured with appropriate permissions
- kubectl configured for your Kubernetes cluster
- jq for JSON processing
- fzf (optional, for better secret searching)

## Examples

After running `tamedia-tunnel` and selecting your service/instance, you'll get ready-to-use connection commands:

```bash
# DocumentDB
mongosh "mongodb://localhost:27017/mydb?retryWrites=false" --username admin --password "$(aws secretsmanager get-secret-value --secret-id 'my-secret' --query SecretString --output text | jq -r '.password')"

# PostgreSQL
psql "postgresql://username:$(aws secretsmanager get-secret-value --secret-id 'my-secret' --query SecretString --output text | jq -r '.password')@localhost:5432/mydb"

# Redis
redis-cli -h localhost -p 6379
```