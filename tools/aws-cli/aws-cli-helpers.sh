#!/bin/bash

# AWS CLI Helpers
# Sets up AWS CLI aliases and provides interactive AWS service management

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ -f "$TOOLS_ROOT/scripts/common.sh" ]]; then
    source "$TOOLS_ROOT/scripts/common.sh"
else
    echo "Error: Cannot find common.sh" >&2
    exit 1
fi

# Function to show usage
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

AWS CLI Helpers - Interactive AWS service management using AWS CLI aliases

OPTIONS:
    --setup-aliases        Set up AWS CLI aliases for EKS operations
    -r, --region REGION    AWS region to search for clusters (default: current AWS region)
    -h, --help            Show this help message
    -v, --version         Show version information

EXAMPLES:
    $(basename "$0") --setup-aliases         # Set up AWS CLI aliases
    $(basename "$0")                         # Interactive cluster selection
    $(basename "$0") -r us-west-2           # Search clusters in specific region

ALIASES CREATED:
    aws eks-config                          # Interactive cluster configuration
    aws eks-list                           # List EKS clusters with details
    aws eks-describe CLUSTER_NAME          # Describe specific cluster

DEPENDENCIES:
    Required: aws, kubectl, jq
    Recommended: fzf (for better interactive selection)
EOF
}

# Function to setup AWS CLI aliases
setup_aws_aliases() {
    print_info "Setting up AWS CLI aliases for EKS operations..."

    # Create AWS CLI config directory if it doesn't exist
    local aws_config_dir="$HOME/.aws"
    local cli_config_file="$aws_config_dir/cli"

    mkdir -p "$aws_config_dir"

    # Check if cli config file exists, create if not
    if [[ ! -f "$cli_config_file" ]]; then
        cat > "$cli_config_file" << 'EOF'
[aliases]
EOF
        print_info "Created AWS CLI configuration file: $cli_config_file"
    fi

    # Backup existing cli file
    cp "$cli_config_file" "$cli_config_file.backup.$(date +%Y%m%d_%H%M%S)"
    print_info "Backed up existing CLI config to: $cli_config_file.backup.*"

    # Read existing content and remove old EKS aliases if they exist
    local temp_file
    temp_file=$(mktemp)

    # Remove existing tamedia-tools EKS aliases
    grep -v "# tamedia-tools EKS alias" "$cli_config_file" > "$temp_file" || true

    # Add our aliases
    cat >> "$temp_file" << 'EOF'

# tamedia-tools EKS alias - Interactive cluster configuration with fzf selection
eks-config = !f() {
    region=${1:-$(aws configure get region || echo "us-east-1")}
    clusters=$(aws eks list-clusters --region $region --query 'clusters[*]' --output text)
    if [ -z "$clusters" ]; then
        echo "No EKS clusters found in region $region"
        return 1
    fi
    if command -v fzf >/dev/null 2>&1; then
        cluster=$(echo "$clusters" | tr '\t' '\n' | fzf --height=40% --border --prompt="EKS Cluster ($region) > ")
    else
        echo "Available clusters in $region:"
        echo "$clusters" | tr '\t' '\n' | nl -v1 -s') '
        read -p "Select cluster number: " num
        cluster=$(echo "$clusters" | tr '\t' '\n' | sed -n "${num}p")
    fi
    if [ -n "$cluster" ]; then
        echo "Configuring kubectl for cluster: $cluster"
        aws eks update-kubeconfig --region $region --name $cluster --alias $cluster
        echo "Context configured. Use: kubectl config use-context $cluster"
    fi
}; f

# tamedia-tools EKS alias - List clusters with details
eks-list = !f() {
    region=${1:-$(aws configure get region || echo "us-east-1")}
    echo "EKS Clusters in region: $region"
    echo "=================================="
    clusters=$(aws eks list-clusters --region $region --query 'clusters[*]' --output text)
    if [ -z "$clusters" ]; then
        echo "No clusters found"
        return 0
    fi
    for cluster in $clusters; do
        echo -n "🔹 $cluster - "
        status=$(aws eks describe-cluster --region $region --name $cluster --query 'cluster.status' --output text 2>/dev/null || echo "ERROR")
        version=$(aws eks describe-cluster --region $region --name $cluster --query 'cluster.version' --output text 2>/dev/null || echo "?")
        echo "Status: $status, Version: $version"
    done
}; f

# tamedia-tools EKS alias - Describe specific cluster
eks-describe = !f() {
    if [ $# -lt 1 ]; then
        echo "Usage: aws eks-describe CLUSTER_NAME [REGION]"
        return 1
    fi
    cluster=$1
    region=${2:-$(aws configure get region || echo "us-east-1")}
    aws eks describe-cluster --region $region --name $cluster --output table
}; f
EOF

    # Write the updated content back
    mv "$temp_file" "$cli_config_file"

    print_success "AWS CLI aliases configured successfully!"
    print_info "Available commands:"
    print_info "  aws eks-config [region]           # Interactive cluster selection"
    print_info "  aws eks-list [region]             # List clusters with status"
    print_info "  aws eks-describe CLUSTER [region] # Describe specific cluster"
    print_info ""
    print_info "Example usage:"
    print_info "  aws eks-config                    # Select cluster interactively"
    print_info "  aws eks-config us-west-2          # Select from us-west-2 region"
    print_info "  aws eks-list                      # List all clusters"
}

# Function to get AWS region
get_aws_region() {
    local region

    if region=$(aws configure get region 2>/dev/null); then
        echo "$region"
        return 0
    fi

    if region=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null | sed 's/[a-z]$//'); then
        echo "$region"
        return 0
    fi

    echo "us-east-1"
}

# Function to list EKS clusters
list_eks_clusters() {
    local region="$1"

    print_info "Fetching EKS clusters in region: $region"

    local clusters
    if ! clusters=$(aws eks list-clusters --region "$region" --query 'clusters[*]' --output text 2>/dev/null); then
        print_error "Failed to list EKS clusters in region $region"
        return 1
    fi

    if [[ -z "$clusters" ]]; then
        print_warning "No EKS clusters found in region $region"
        return 1
    fi

    echo "$clusters" | tr '\t' '\n'
}

# Function to select cluster interactively
select_cluster() {
    local clusters="$1"
    local selected_cluster

    if command_exists fzf; then
        print_info "Select an EKS cluster:"
        selected_cluster=$(echo "$clusters" | fzf --height=40% --border --prompt="EKS Cluster > ")
    else
        print_info "Available EKS clusters:"
        echo "$clusters" | nl -v1 -s') '

        local cluster_count
        cluster_count=$(echo "$clusters" | wc -l)

        echo
        read -p "Select cluster number (1-$cluster_count): " selection

        if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "$cluster_count" ]]; then
            print_error "Invalid selection"
            return 1
        fi

        selected_cluster=$(echo "$clusters" | sed -n "${selection}p")
    fi

    if [[ -z "$selected_cluster" ]]; then
        print_error "No cluster selected"
        return 1
    fi

    echo "$selected_cluster"
}

# Function to configure kubectl for EKS cluster
configure_kubectl() {
    local cluster_name="$1"
    local region="$2"

    print_info "Configuring kubectl for cluster: $cluster_name"
    print_info "Region: $region"

    if aws eks update-kubeconfig --region "$region" --name "$cluster_name" --alias "$cluster_name"; then
        print_success "Successfully configured kubectl context: $cluster_name"
        print_info "You can now use: kubectl --context=$cluster_name <command>"
        print_info "Or switch to this context: kubectl config use-context $cluster_name"

        local current_context
        current_context=$(kubectl config current-context 2>/dev/null || echo "none")
        print_info "Current context: $current_context"

        return 0
    else
        print_error "Failed to configure kubectl for cluster: $cluster_name"
        return 1
    fi
}

# Main function
main() {
    local region=""
    local setup_aliases=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --setup-aliases)
                setup_aliases=true
                shift
                ;;
            -r|--region)
                region="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                print_version
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Setup aliases if requested
    if [[ "$setup_aliases" == true ]]; then
        if ! check_dependencies "aws"; then
            exit 1
        fi
        setup_aws_aliases
        exit 0
    fi

    # Check dependencies for normal operation
    if ! check_dependencies "aws" "kubectl"; then
        exit 1
    fi

    check_recommended_dependencies "fzf"

    # Verify AWS authentication
    if ! verify_aws_auth; then
        exit 1
    fi

    # Get region if not specified
    if [[ -z "$region" ]]; then
        region=$(get_aws_region)
        print_info "Using AWS region: $region"
    fi

    # List EKS clusters
    local clusters
    if ! clusters=$(list_eks_clusters "$region"); then
        exit 1
    fi

    # Select cluster
    local selected_cluster
    if ! selected_cluster=$(select_cluster "$clusters"); then
        exit 1
    fi

    print_success "Selected cluster: $selected_cluster"

    # Configure kubectl
    if ! configure_kubectl "$selected_cluster" "$region"; then
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi