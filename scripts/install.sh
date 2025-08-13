#!/bin/bash

set -e

# Installation script for tamedia-tools
REPO_URL="https://github.com/dnd-it/tamedia-tools"
INSTALL_DIR="/usr/local/bin"
COMPLETION_DIR_BASH="/usr/local/etc/bash_completion.d"
COMPLETION_DIR_ZSH="/usr/local/share/zsh/site-functions"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ] && [ -z "$ALLOW_ROOT" ]; then
    print_error "Please don't run this script as root"
    exit 1
fi

# Get latest release version
get_latest_version() {
    curl -s "https://api.github.com/repos/dnd-it/tamedia-tools/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Download and extract release
download_release() {
    local version=$1
    local temp_dir=$(mktemp -d)
    
    print_info "Downloading tamedia-tools ${version}..."
    
    local download_url="${REPO_URL}/archive/${version}.tar.gz"
    
    if ! curl -L -o "${temp_dir}/tamedia-tools.tar.gz" "${download_url}"; then
        print_error "Failed to download release"
        rm -rf "${temp_dir}"
        return 1
    fi
    
    print_info "Extracting..."
    tar -xzf "${temp_dir}/tamedia-tools.tar.gz" -C "${temp_dir}"
    
    echo "${temp_dir}/tamedia-tools-${version#v}"
}

# Install a specific tool
install_tool() {
    local tool=$1
    local source_dir=$2
    
    case $tool in
        tunnel)
            print_info "Installing tamedia-tunnel..."
            sudo install -m 755 "${source_dir}/tools/tunnel/tunnel.sh" "${INSTALL_DIR}/tamedia-tunnel"
            
            # Install completions if directories exist
            if [ -d "${COMPLETION_DIR_BASH}" ] && [ -f "${source_dir}/completion/tamedia-tunnel.bash" ]; then
                sudo install -m 644 "${source_dir}/completion/tamedia-tunnel.bash" "${COMPLETION_DIR_BASH}/"
            fi
            if [ -d "${COMPLETION_DIR_ZSH}" ] && [ -f "${source_dir}/completion/_tamedia-tunnel" ]; then
                sudo install -m 644 "${source_dir}/completion/_tamedia-tunnel" "${COMPLETION_DIR_ZSH}/"
            fi
            ;;
        common)
            print_info "Installing common utilities..."
            sudo install -m 755 "${source_dir}/scripts/common.sh" "${INSTALL_DIR}/tamedia-common"
            ;;
        *)
            print_error "Unknown tool: $tool"
            return 1
            ;;
    esac
}

# Main installation
main() {
    print_info "Tamedia Tools Installer"
    print_info "======================"
    
    # Check for required commands
    for cmd in curl tar sudo; do
        if ! command -v $cmd >/dev/null 2>&1; then
            print_error "$cmd is required but not installed"
            exit 1
        fi
    done
    
    # Get version to install
    local version
    if [ -n "$1" ] && [[ "$1" =~ ^v[0-9] ]]; then
        version=$1
        shift
    else
        version=$(get_latest_version)
        if [ -z "$version" ]; then
            print_error "Could not determine latest version"
            exit 1
        fi
    fi
    
    print_info "Installing version: ${version}"
    
    # Download release
    local source_dir
    source_dir=$(download_release "$version")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Determine which tools to install
    local tools_to_install=()
    if [ $# -eq 0 ]; then
        # Install all tools by default
        tools_to_install=(common tunnel)
    else
        # Install specified tools
        tools_to_install=(common "$@")
    fi
    
    # Install tools
    for tool in "${tools_to_install[@]}"; do
        install_tool "$tool" "$source_dir"
    done
    
    # Clean up
    rm -rf "${source_dir%/*}"
    
    print_success ""
    print_success "Installation complete!"
    print_info ""
    print_info "Installed tools:"
    for tool in "${tools_to_install[@]}"; do
        if [ "$tool" != "common" ]; then
            echo "  - tamedia-${tool}"
        fi
    done
    print_info ""
    print_info "Run any tool with --help for usage information"
    
    # Check for optional dependencies
    print_info ""
    print_info "Checking optional dependencies:"
    for cmd in aws kubectl jq fzf; do
        if command -v $cmd >/dev/null 2>&1; then
            print_success "  ✓ $cmd"
        else
            print_error "  ✗ $cmd (recommended)"
        fi
    done
}

# Run main with all arguments
main "$@"