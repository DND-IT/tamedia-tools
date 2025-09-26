#!/bin/bash

# Common functions and variables for tamedia-tools
TAMEDIA_TOOLS_VERSION="1.1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required dependencies
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing[*]}"
        print_info "Please install missing dependencies and try again."
        return 1
    fi
    
    return 0
}

# Check recommended dependencies
check_recommended_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_warning "Missing recommended dependencies: ${missing[*]}"
        print_info "Install them for a better experience: brew install ${missing[*]}"
    fi
}

# Verify AWS authentication
verify_aws_auth() {
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "Not authenticated with AWS. Please run 'aws configure' or set AWS credentials."
        return 1
    fi
    return 0
}

# Verify kubectl context
verify_kubectl_context() {
    if ! kubectl config current-context >/dev/null 2>&1; then
        print_error "No kubectl context set. Please configure kubectl to connect to your cluster."
        return 1
    fi
    return 0
}

# Get script directory
get_script_dir() {
    echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
}

# Version output
print_version() {
    echo "tamedia-tools version $TAMEDIA_TOOLS_VERSION"
}