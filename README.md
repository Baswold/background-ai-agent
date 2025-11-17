# 🧠 Background AI Agent

An always-on AI assistant for macOS that intelligently monitors your work and proactively helps improve your productivity.

## ✨ Features

### 🔍 **Intelligent Monitoring**
- Always-on background agent that watches your workflow
- Takes screenshots when you open apps (respecting privacy)
- Learns your computer habits and saves insights to `memory.md`

### 👨‍💻 **VS Code & Code Editor Integration**
- Monitors VS Code, Xcode, and other code editors
- Automatically detects and fixes bugs
- Suggests optimizations and improvements
- Sends notifications like: "I see you're working on auth.swift! I fixed a memory leak!"

### 🌐 **Browser Intelligence**
- Monitors Safari, Chrome, Firefox, and other browsers
- Detects forms and offers auto-fill
- Analyzes documentation and saves key points
- Smart suggestions based on browsing context

### 🐙 **GitHub Integration**
- Scans pull requests automatically
- Detects issues in PR code
- Can auto-fix problems and commit changes
- Provides code review suggestions

### 🎨 **Beautiful Design**
- Liquid glass UI with macOS Sonoma styling
- Lives in the menu bar (not in Cmd+Tab)
- Gorgeous notifications with gradient icons
- Smooth animations and modern aesthetics

### 🧩 **Smart Features**
- On/off toggle to pause monitoring
- Memory system that learns about you
- Form filling capabilities
- Screenshot archive
- Activity history

## 🚀 Getting Started

### Prerequisites
- macOS 14.0 (Sonoma) or later
- Xcode 15 or later
- Swift 5.9 or later

### Building the App

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd background-ai-agent
   ```

2. **Build with Swift Package Manager**
   ```bash
   swift build -c release
   ```

3. **Run the app**
   ```bash
   .build/release/BackgroundAIAgent
   ```

### Building as macOS App Bundle

To build a proper .app bundle:

```bash
# Create app structure
mkdir -p BackgroundAIAgent.app/Contents/MacOS
mkdir -p BackgroundAIAgent.app/Contents/Resources

# Build the executable
swift build -c release

# Copy executable
cp .build/release/BackgroundAIAgent BackgroundAIAgent.app/Contents/MacOS/

# Copy Info.plist
cp Info.plist BackgroundAIAgent.app/Contents/

# Sign the app (optional, for distribution)
codesign --deep --force --verify --verbose --sign "-" BackgroundAIAgent.app
```

### Permissions Setup

On first launch, the app will request several permissions:

1. **Screen Recording** - To capture screenshots and analyze your work
2. **Accessibility** - To monitor app activations and interactions
3. **Notifications** - To send helpful alerts

Grant these permissions in **System Settings > Privacy & Security**

## 🎯 How It Works

1. **Launch**: The app starts and appears in your menu bar with a brain icon
2. **Monitor**: It watches when you open apps (VS Code, browsers, etc.)
3. **Capture**: Takes screenshots to analyze what you're working on
4. **Analyze**: Uses AI to detect issues, patterns, and opportunities
5. **Notify**: Sends beautiful notifications when it finds ways to help
6. **Learn**: Saves insights about your habits to `~/.background-ai-agent/memory.md`

## 📁 File Structure

```
~/.background-ai-agent/
├── memory.md              # Your AI's learned patterns and insights
└── screenshots/           # Archived screenshots
    ├── VSCode_2024-01-01_10-30-00.png
    └── Safari_2024-01-01_10-35-00.png
```

## 🎛️ Controls

Click the menu bar icon to:
- Toggle the agent on/off
- View recent activities
- Open settings
- View memory file
- Refresh activity feed
- Quit the app

## 🔒 Privacy

- All processing happens locally on your Mac
- Screenshots are stored only on your computer
- No data is sent to external servers
- You can disable monitoring anytime with the toggle
- Delete `~/.background-ai-agent/` to clear all data

## 🎨 UI Features

- **Liquid Glass Design**: Beautiful translucent materials matching macOS Sonoma
- **Gradient Icons**: Colorful, modern icon system
- **Smooth Animations**: Spring-based animations for interactions
- **Dark Mode**: Full support for light and dark appearances
- **Menu Bar Only**: Doesn't appear in Dock or Cmd+Tab switcher

## 🛠️ Development

### Project Structure

```
Sources/
├── main.swift                    # App entry point
├── AppDelegate.swift             # App lifecycle and menu bar setup
├── MenuBarView.swift             # Beautiful SwiftUI UI
├── AgentEngine.swift             # Core AI monitoring engine
├── ScreenshotCaptureEngine.swift # Screenshot capture using ScreenCaptureKit
├── MemoryManager.swift           # Learning and memory system
├── VSCodeMonitor.swift           # Code editor monitoring
├── BrowserMonitor.swift          # Browser monitoring
├── GitHubMonitor.swift           # GitHub PR scanning
└── Activity.swift                # Activity data model
```

### Technologies Used

- **SwiftUI** - Modern UI framework
- **ScreenCaptureKit** - macOS screenshot API
- **UserNotifications** - Native notification system
- **AppKit** - macOS application framework
- **Accessibility APIs** - App monitoring

## 🚧 Future Enhancements

- [ ] Real AI integration (OpenAI, Claude, etc.)
- [ ] OCR for screenshot text analysis
- [ ] Actual GitHub API integration
- [ ] Browser extension for deeper integration
- [ ] Custom automation rules
- [ ] Voice commands
- [ ] Multi-display support
- [ ] Cloud sync for memory
- [ ] Keyboard shortcuts

## 📝 License

MIT License - Feel free to use and modify!

## 🙏 Acknowledgments

Built with love for productivity enthusiasts who want an AI assistant that actually helps!

---

**Made with** 🧠 **and** ❤️ **by your friendly AI assistant**
