#!/bin/bash

# Lucidity Watch App Build Script
# Usage: ./build_watch_app.sh [build|install|clean]

set -e

# Configuration
SCHEME_NAME="Lucidity Watch App"
CONFIGURATION="Release"
PROJECT_DIR="."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to find connected Apple Watch
find_watch() {
    echo "🔍 Looking for connected Apple Watch..."
    WATCH_NAME=$(xcrun xctrace list devices | grep "Apple Watch" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')
    if [ -z "$WATCH_NAME" ]; then
        echo_error "No Apple Watch found. Make sure your watch is connected and unlocked."
        exit 1
    fi
    echo_success "Found Apple Watch: $WATCH_NAME"
}

# Function to build project
build_project() {
    echo "🔨 Building Lucidity Watch App..."
    
    xcodebuild -scheme "$SCHEME_NAME" \
               -destination "generic/platform=watchOS" \
               -configuration "$CONFIGURATION" \
               clean build
    
    if [ $? -eq 0 ]; then
        echo_success "Build completed successfully!"
    else
        echo_error "Build failed!"
        exit 1
    fi
}

# Function to install on device
install_on_device() {
    find_watch
    echo "📱 Installing on Apple Watch..."
    
    xcodebuild -scheme "$SCHEME_NAME" \
               -destination "platform=watchOS,name=$WATCH_NAME" \
               -configuration "$CONFIGURATION" \
               install
    
    if [ $? -eq 0 ]; then
        echo_success "App installed successfully on Apple Watch!"
        echo_success "Check your watch for the Lucidity app."
    else
        echo_error "Installation failed!"
        exit 1
    fi
}

# Function to clean build folder
clean_project() {
    echo "🧹 Cleaning build artifacts..."
    
    xcodebuild -scheme "$SCHEME_NAME" \
               -configuration "$CONFIGURATION" \
               clean
    
    if [ $? -eq 0 ]; then
        echo_success "Clean completed successfully!"
    else
        echo_error "Clean failed!"
        exit 1
    fi
}

# Main script logic
case "${1:-install}" in
    "build")
        build_project
        ;;
    "install")
        build_project
        install_on_device
        ;;
    "clean")
        clean_project
        ;;
    *)
        echo "Usage: $0 [build|install|clean]"
        echo "  build   - Build the project only"
        echo "  install - Build and install on connected Apple Watch (default)"
        echo "  clean   - Clean build artifacts"
        exit 1
        ;;
esac

echo_success "Script completed! 🎉"