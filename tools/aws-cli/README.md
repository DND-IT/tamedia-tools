# AWS CLI Integration Tools

Collection of scripts that enhance the AWS CLI experience with interactive selections and common workflow automation.

## 🚀 Quick Start

### Setup AWS CLI Aliases

First, set up the AWS CLI aliases to get the most streamlined experience:

```bash
./aws-eks-config.sh --setup-aliases
```

This creates convenient AWS CLI aliases that you can use anywhere:

- `aws eks-config [region]` - Interactive EKS cluster configuration with fzf
- `aws eks-list [region]` - List EKS clusters with status and version info
- `aws eks-describe CLUSTER_NAME [region]` - Describe specific cluster details

### Usage Examples

```bash
# Interactive cluster selection with fzf (recommended)
aws eks-config

# Select cluster from specific region
aws eks-config us-west-2

# List all clusters with details
aws eks-list

# Get detailed info about a specific cluster
aws eks-describe my-production-cluster
```

## 🛠️ Available Tools

### `aws-eks-config.sh`

Interactive EKS cluster configuration tool that:

- Lists available EKS clusters in your specified or default region
- Provides fzf-powered selection (falls back to numbered menu)
- Automatically configures kubectl with the selected cluster
- Sets up kubectl context with cluster name as alias
- Uses AWS CLI aliases for seamless integration

**Features:**
- 🎯 **Smart region detection** - Uses AWS CLI default or EC2 metadata
- 🔍 **Interactive selection** - fzf interface when available
- 🔧 **Kubectl integration** - Automatic context configuration
- ⚡ **AWS CLI aliases** - Direct integration with `aws` command
- 🛡️ **Error handling** - Comprehensive error checking and user feedback

**Options:**
```bash
./aws-eks-config.sh [OPTIONS]

OPTIONS:
    --setup-aliases        Set up AWS CLI aliases for EKS operations
    -r, --region REGION    AWS region to search for clusters
    -h, --help            Show help message
    -v, --version         Show version information
```

## 📋 Prerequisites

### Required Dependencies
- **aws** - AWS CLI v1 or v2 with proper credentials configured
- **kubectl** - Kubernetes command-line tool
- **jq** - JSON processor (used by some functions)

### Recommended Dependencies
- **fzf** - Fuzzy finder for better interactive selection experience

Install recommended dependencies:
```bash
# macOS
brew install fzf

# Ubuntu/Debian
sudo apt install fzf

# CentOS/RHEL
sudo yum install fzf
```

## ⚙️ AWS CLI Alias Configuration

The tool automatically configures AWS CLI aliases in `~/.aws/cli`. The aliases use shell functions for complex logic while maintaining the convenience of the `aws` command interface.

### Generated Aliases

**eks-config**: Interactive cluster selection and kubectl configuration
```bash
aws eks-config [region]
```

**eks-list**: List clusters with status information
```bash
aws eks-list [region]
```

**eks-describe**: Detailed cluster information
```bash
aws eks-describe CLUSTER_NAME [region]
```

### Alias Features
- Automatic region detection from AWS CLI config
- fzf integration when available
- Fallback to numbered selection menus
- Comprehensive error handling
- Status and version information display

## 🔧 Installation

### Option 1: Use existing tamedia-tools installation
If you have tamedia-tools installed, the scripts are already available:
```bash
/usr/local/bin/tamedia-aws-eks-config --setup-aliases
```

### Option 2: Direct usage from repository
```bash
# Make executable
chmod +x tools/aws-cli/aws-eks-config.sh

# Setup aliases
./tools/aws-cli/aws-eks-config.sh --setup-aliases

# Use directly
./tools/aws-cli/aws-eks-config.sh
```

## 💡 Usage Patterns

### Daily Workflow
```bash
# Morning standup - check cluster status across regions
aws eks-list us-east-1
aws eks-list eu-west-1

# Switch to development cluster
aws eks-config us-east-1
# Select dev-cluster from the menu
kubectl config use-context dev-cluster

# Later switch to production
aws eks-config
# Select prod-cluster
kubectl config use-context prod-cluster
```

### Troubleshooting Workflow
```bash
# Get detailed cluster information
aws eks-describe problematic-cluster us-west-2

# Configure kubectl for investigation
aws eks-config us-west-2
# Select the problematic cluster

# Now use kubectl with proper context
kubectl get nodes
kubectl get pods --all-namespaces
```

## 🏗️ Technical Details

### AWS CLI Alias Implementation
The aliases are implemented as shell functions using the AWS CLI's `!f() { ... }; f` pattern. This allows:

- Complex multi-step operations within a single alias
- Parameter handling and defaults
- Integration with external tools like fzf
- Comprehensive error handling
- Interactive prompts and selections

### Context Management
The tool uses `aws eks update-kubeconfig` with the `--alias` flag to create meaningful context names that match the EKS cluster names, making it easy to switch between clusters.

### Region Handling
Region detection follows this priority:
1. Command-line argument (`-r` or `--region`)
2. AWS CLI default region (`aws configure get region`)
3. EC2 instance metadata (if running on EC2)
4. Fallback to `us-east-1`

## 🤝 Contributing

This tool follows the tamedia-tools project patterns:
- Uses `scripts/common.sh` for shared functionality
- Follows consistent error handling and output formatting
- Includes comprehensive help and usage information
- Maintains compatibility with existing tooling

## 🔍 Troubleshooting

### Common Issues

**"No clusters found"**
- Verify AWS credentials: `aws sts get-caller-identity`
- Check region: `aws configure get region`
- Verify EKS permissions: `aws eks list-clusters`

**"kubectl configuration failed"**
- Ensure kubectl is installed and in PATH
- Verify EKS cluster accessibility
- Check AWS IAM permissions for EKS

**"fzf not found" warning**
- Install fzf for better selection experience
- Tool falls back to numbered menus automatically

### Debug Mode
```bash
# Enable AWS CLI debug output
export AWS_CLI_TRACE=1
./aws-eks-config.sh

# Or use AWS CLI directly to test
aws eks list-clusters --region us-east-1
```

---

**Need help?** Open an issue or contact the DAI team on Slack.