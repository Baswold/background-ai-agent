.PHONY: build run clean app install help

APP_NAME = BackgroundAIAgent
APP_BUNDLE = $(APP_NAME).app
INSTALL_PATH = /Applications

help:
	@echo "🧠 Background AI Agent - Build Commands"
	@echo ""
	@echo "  make build    - Build the executable"
	@echo "  make run      - Build and run the app"
	@echo "  make app      - Create macOS .app bundle"
	@echo "  make install  - Install to /Applications"
	@echo "  make clean    - Clean build artifacts"
	@echo ""

build:
	@echo "🔨 Building Background AI Agent..."
	swift build -c release
	@echo "✅ Build complete!"

run: build
	@echo "🚀 Launching Background AI Agent..."
	.build/release/$(APP_NAME)

app: build
	@echo "📦 Creating .app bundle..."
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp .build/release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	@cp Info.plist $(APP_BUNDLE)/Contents/
	@echo "✅ App bundle created: $(APP_BUNDLE)"
	@echo "🔐 Signing app..."
	@codesign --deep --force --verify --verbose --sign "-" $(APP_BUNDLE) 2>/dev/null || echo "⚠️  Signing skipped (optional)"
	@echo "✅ App ready!"

install: app
	@echo "📲 Installing to $(INSTALL_PATH)..."
	@sudo rm -rf $(INSTALL_PATH)/$(APP_BUNDLE)
	@sudo cp -R $(APP_BUNDLE) $(INSTALL_PATH)/
	@echo "✅ Installed to $(INSTALL_PATH)/$(APP_BUNDLE)"
	@echo "🎉 You can now run it from Applications!"

clean:
	@echo "🧹 Cleaning..."
	@rm -rf .build
	@rm -rf $(APP_BUNDLE)
	@echo "✅ Clean complete!"

# Development helpers
debug:
	swift build

test:
	swift test

format:
	@echo "✨ Formatting code..."
	@find Sources -name "*.swift" -print0 | xargs -0 swift-format -i

.DEFAULT_GOAL := help
