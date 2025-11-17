#!/bin/bash

# 🧠 Background AI Agent Build Script

set -e

echo "🧠 Background AI Agent - Automated Build"
echo "========================================"
echo ""

APP_NAME="BackgroundAIAgent"
APP_BUNDLE="${APP_NAME}.app"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

step() {
    echo -e "${BLUE}▶${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check prerequisites
step "Checking prerequisites..."

if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed. Please install Xcode or Swift toolchain."
    exit 1
fi

success "Swift found: $(swift --version | head -n1)"

# Clean previous builds
step "Cleaning previous builds..."
rm -rf .build
rm -rf "$APP_BUNDLE"
success "Clean complete"

# Build the project
step "Building project (Release)..."
swift build -c release
success "Build complete"

# Create app bundle
step "Creating .app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp Info.plist "${APP_BUNDLE}/Contents/"

success "App bundle created"

# Code signing (optional)
step "Signing application..."
if codesign --deep --force --verify --verbose --sign "-" "$APP_BUNDLE" 2>/dev/null; then
    success "App signed successfully"
else
    warning "Code signing skipped (optional for development)"
fi

# Summary
echo ""
echo "========================================"
echo "🎉 Build Complete!"
echo ""
echo "📦 App Bundle: ${APP_BUNDLE}"
echo ""
echo "To run:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "To install to Applications:"
echo "  sudo cp -R ${APP_BUNDLE} /Applications/"
echo ""
echo "========================================"
