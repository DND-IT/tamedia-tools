#!/bin/bash

set -e

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/common.sh"

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "tools" ]; then
    print_error "Please run this script from the tamedia-tools root directory"
    exit 1
fi

# Get version from common.sh
VERSION="v${TAMEDIA_TOOLS_VERSION}"

print_info "Building tamedia-tools release ${VERSION}"

# Create temporary directory for the release
TEMP_DIR=$(mktemp -d)
RELEASE_DIR="${TEMP_DIR}/tamedia-tools-${VERSION}"

print_info "Creating release directory: ${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}"

# Copy files to release directory
print_info "Copying files..."
cp -r tools scripts Formula completion docs README.md LICENSE "${RELEASE_DIR}/"

# Create tarball
TARBALL="tamedia-tools-${VERSION}.tar.gz"
print_info "Creating tarball: ${TARBALL}"
cd "${TEMP_DIR}"
tar -czf "${TARBALL}" "tamedia-tools-${VERSION}"

# Calculate SHA256
SHA256=$(shasum -a 256 "${TARBALL}" | awk '{print $1}')
print_success "SHA256: ${SHA256}"

# Move tarball to the original directory
mv "${TARBALL}" "${SCRIPT_DIR}/../"

# Clean up
rm -rf "${TEMP_DIR}"

print_success "Release ${VERSION} built successfully!"
print_info "Tarball created: ${TARBALL}"
print_info ""
print_info "To create a GitHub release:"
print_info "1. Create and push a git tag:"
print_info "   git tag ${VERSION}"
print_info "   git push origin ${VERSION}"
print_info ""
print_info "2. Create a GitHub release and upload ${TARBALL}"
print_info ""
print_info "3. Update the Homebrew formulas with:"
print_info "   url \"https://github.com/dnd-it/tamedia-tools/archive/${VERSION}.tar.gz\""
print_info "   sha256 \"${SHA256}\""
print_info ""
print_info "4. Create a Homebrew tap repository (homebrew-tamedia-tools) and add the formulas"