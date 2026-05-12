#!/bin/bash

# Build script that auto-increments version and builds APK
# Usage: ./build_apk.sh [release|debug]

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

PUBSPEC_FILE="pubspec.yaml"

# Function to increment version
increment_version() {
    local version_line=$(grep "^version:" "$PUBSPEC_FILE")
    local current_version=$(echo "$version_line" | sed 's/version: //' | sed 's/+.*//')
    
    # Split version into parts
    IFS='.' read -ra VERSION_PARTS <<< "$current_version"
    local major=${VERSION_PARTS[0]}
    local minor=${VERSION_PARTS[1]}
    local patch=${VERSION_PARTS[2]}
    
    # Increment patch version
    patch=$((patch + 1))
    
    # Get build number (the part after +)
    local build_number=$(echo "$version_line" | sed 's/.*+//')
    build_number=$((build_number + 1))
    
    # Create new version string
    local new_version="${major}.${minor}.${patch}+${build_number}"
    
    echo "$new_version"
}

# Function to update version in pubspec.yaml
update_version() {
    local new_version=$1
    local build_type=$2
    
    # Update the version line in pubspec.yaml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version: .*/version: $new_version/" "$PUBSPEC_FILE"
    else
        # Linux
        sed -i "s/^version: .*/version: $new_version/" "$PUBSPEC_FILE"
    fi
    
    echo -e "${GREEN}✓ Version updated to $new_version${NC}"
}

# Main execution
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Flutter APK Build Script${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Determine build type (release or debug, default to release)
BUILD_TYPE=${1:-release}

if [ "$BUILD_TYPE" != "release" ] && [ "$BUILD_TYPE" != "debug" ]; then
    echo -e "${YELLOW}Warning: Invalid build type '$BUILD_TYPE'. Using 'release' instead.${NC}"
    BUILD_TYPE="release"
fi

# Get current version
CURRENT_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //')
echo -e "${BLUE}Current version:${NC} $CURRENT_VERSION"

# Increment version
NEW_VERSION=$(increment_version)
echo -e "${BLUE}New version:${NC} $NEW_VERSION"
echo ""

# Update version in pubspec.yaml
update_version "$NEW_VERSION" "$BUILD_TYPE"

# Clean previous builds
echo -e "${BLUE}Cleaning previous builds...${NC}"
flutter clean
echo ""

# Get dependencies
echo -e "${BLUE}Getting dependencies...${NC}"
flutter pub get
echo ""

# Build APK
echo -e "${BLUE}Building APK ($BUILD_TYPE mode)...${NC}"
if [ "$BUILD_TYPE" == "release" ]; then
    flutter build apk --release
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓ Build completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "APK location: ${BLUE}build/app/outputs/flutter-apk/app-release.apk${NC}"
    echo -e "Version: ${BLUE}$NEW_VERSION${NC}"
else
    flutter build apk --debug
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓ Build completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "APK location: ${BLUE}build/app/outputs/flutter-apk/app-debug.apk${NC}"
    echo -e "Version: ${BLUE}$NEW_VERSION${NC}"
fi

