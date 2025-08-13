# Tamedia Tools

<!-- BADGES START -->
![Tests](https://github.com/DND-IT/tamedia-tools/workflows/Test/badge.svg)
![Release](https://github.com/DND-IT/tamedia-tools/workflows/Release/badge.svg)
![Version](https://img.shields.io/github/v/release/DND-IT/tamedia-tools)
![License](https://img.shields.io/github/license/DND-IT/tamedia-tools)
<!-- BADGES END -->


AWS service tunneling tool for Kubernetes, designed for Tamedia's infrastructure workflows. This tool simplifies secure connections to AWS managed services through Kubernetes pods.

## 🚀 Quick Start

### Homebrew Installation (Recommended)

```bash
# Add the tap
brew tap dnd-it/tamedia-tools

# Install complete suite
brew install tamedia-tools

# Or install individual tool
brew install tamedia-tunnel
```

### Direct Installation

```bash
# Install all tools
curl -sSL https://raw.githubusercontent.com/dnd-it/tamedia-tools/main/scripts/install.sh | bash

# Install specific tool
curl -sSL https://raw.githubusercontent.com/dnd-it/tamedia-tools/main/scripts/install.sh | bash -s tunnel
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

- [Installation Guide](docs/installation.md)
- [Tunnel Tool Guide](tools/tunnel/README.md)
- [Contributing](docs/contributing.md)

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