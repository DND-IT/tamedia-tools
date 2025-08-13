# Tamedia Tools

AWS service tunneling tool for Kubernetes, designed for Tamedia's infrastructure workflows. This tool simplifies secure connections to AWS managed services through Kubernetes pods.

## 🚀 Quick Start

### Installation

#### Homebrew (Recommended)
```bash
# Add the tap
brew tap dnd-it/tamedia-tools

# Install the tools
brew install tamedia-tools
# Or install just the tunnel tool
brew install tamedia-tunnel
```

#### Direct Installation
```bash
curl -sSL https://raw.githubusercontent.com/dnd-it/tamedia-tools/main/scripts/install.sh | bash
```

#### Manual Installation
```bash
# Download the latest release
wget https://github.com/dnd-it/tamedia-tools/archive/v1.0.0.tar.gz
tar -xzf v1.0.0.tar.gz
cd tamedia-tools-1.0.0

# Install to /usr/local/bin
sudo install -m 755 tools/tunnel/tunnel.sh /usr/local/bin/tamedia-tunnel
sudo install -m 755 scripts/common.sh /usr/local/bin/tamedia-common
```

## 🛠️ Features

### `tamedia-tunnel`
Secure tunneling to AWS services through Kubernetes:
- **DocumentDB** (MongoDB)
- **RDS** (PostgreSQL, MySQL)
- **ElastiCache** (Redis, Valkey)
- Automatic secret integration
- Smart port management

```bash
tamedia-tunnel
# Interactive service and instance selection
# Automatic credentials from AWS Secrets Manager
```


## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl configured for your Kubernetes cluster
- jq for JSON processing

## 🏗️ Key Features

- **Consistent AWS identity detection** - Automatically detects your AWS session
- **Kubernetes-safe naming conventions** - Generates valid pod names from AWS identities
- **Secure credential handling** - Integrates with AWS Secrets Manager
- **Interactive selection menus** - Easy service and instance selection with fzf support
- **Automatic cleanup mechanisms** - Prompts to clean up resources on exit

## 📖 Documentation

- [Tunnel Tool Guide](tools/tunnel/README.md)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏢 About Tamedia

These tools are developed and maintained by the DAI team at Tamedia for internal infrastructure workflows.

---

**Need help?** Open an issue or contact the @dai team on Slack.