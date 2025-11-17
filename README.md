# 🧠 Background AI Agent - ENHANCED EDITION

> **The Ultimate Always-On AI Assistant for macOS** - Now with REAL AI, not simulations!

An incredibly powerful, always-on AI assistant that monitors your workflow, proactively helps improve your productivity, and integrates seamlessly with your development environment. Powered by Claude AI, with dozens of advanced features.

---

## 🚀 **NEW in Enhanced Edition**

### ✨ **REAL AI Integration**
- ✅ **Claude API Integration** - Actual AI-powered code analysis (no more fake demos!)
- ✅ **Vision API** - Real screenshot analysis with multimodal AI
- ✅ **Intelligent Suggestions** - Context-aware recommendations based on actual analysis

### 🔥 **Powerful New Features**
- 📁 **Real-Time File Watching** - FSEvents-based monitoring of code changes
- 🐙 **GitHub API Integration** - Actual PR scanning, reviews, and auto-commenting
- 👁️ **OCR Text Extraction** - Vision framework for extracting text from screenshots
- 📋 **Clipboard Intelligence** - Smart clipboard monitoring with pattern detection
- 📊 **Productivity Tracking** - Deep work detection and time analytics
- ⏰ **Smart Reminders** - Context-aware reminders based on your activity
- 💻 **Terminal Monitoring** - Shell command analysis and suggestions
- 🌐 **Network Monitoring** - Connection status and VPN detection
- 📚 **Code Snippet Manager** - Auto-save useful code patterns
- 📝 **Auto Documentation** - AI-generated docs and README files
- ⌨️ **Global Keyboard Shortcuts** - System-wide hotkeys for instant access
- 🤖 **Form Automation** - Real Accessibility API-based form filling

---

## 📋 **Complete Feature List**

### 🎯 **Core Intelligence**

#### **AI-Powered Code Analysis**
- Real-time file system watching (FSEvents)
- Detects bugs, security vulnerabilities, performance issues
- Automatic code quality improvements
- Generates fixes and saves them to backup directory
- Supports: Swift, JavaScript, TypeScript, Python, Go, Rust, Java, C++, and more

#### **Screenshot Intelligence**
- Captures screenshots when apps open
- OCR text extraction using Vision framework
- Detects code in screenshots and analyzes it
- Identifies forms and offers auto-fill
- AI vision analysis for context understanding

#### **GitHub Integration**
- Real GitHub API calls (not simulated!)
- Automatic PR discovery across your repositories
- AI-powered code review with detailed analysis
- Auto-comments on PRs with findings
- Detects security concerns and performance issues
- Tracks PR status and notifies you of changes

### 🛠️ **Advanced Tools**

#### **Clipboard Monitor**
- Tracks clipboard history (last 100 items)
- Detects URLs, code, JSON, errors, API keys
- Warns about pasted secrets/tokens
- AI analysis of copied code
- Suggests solutions for copied error messages
- OCR on copied images

#### **Productivity Tracker**
- Tracks time spent in each app
- Categorizes activity (productive/communication/browsing)
- Detects deep work periods (30+ min focused sessions)
- Pomodoro timer integration
- Daily statistics and reports
- Focus session tracking

#### **Smart Reminders**
- Calendar integration (EventKit)
- Context-aware reminders based on your activity
- Meeting prep notifications
- Code commit reminders after fixes
- PR follow-up reminders
- Break suggestions during deep work

#### **Terminal Monitor**
- Monitors .bash_history, .zsh_history, .fish_history
- Detects dangerous commands (rm -rf, chmod 777, etc.)
- Warns about force pushes
- Suggests command improvements via AI
- Tracks most-used commands
- Git operation analysis

#### **Code Snippet Manager**
- Auto-saves useful code patterns
- AI determines if code is worth saving
- Full-text search across snippets
- Organized by language and tags
- Export to Markdown
- Persistent JSON storage

#### **Network Monitor**
- Real-time connection status
- WiFi/Cellular/Ethernet detection
- VPN detection
- Connection quality monitoring
- Metered connection warnings
- Connection change notifications

#### **Auto Documentation Generator**
- Generates function/class documentation
- Creates comprehensive README files
- Adds inline code comments
- API documentation generation
- Analyzes project structure
- Professional formatting

#### **Form Automation**
- Uses Accessibility APIs (real, not simulated!)
- Detects forms in active windows
- AI-powered field detection
- Smart default values
- Context-aware form filling
- Privacy-safe operation

### ⌨️ **Keyboard Shortcuts**

- **Cmd+Shift+A** - Toggle agent on/off
- **Cmd+Shift+S** - Manual screenshot capture
- **Cmd+Shift+M** - Open memory file
- **Cmd+Shift+D** - Open dashboard

### 🎨 **Beautiful UI**

- **Liquid Glass Design** - macOS Sonoma-style translucent materials
- **Gradient Icons** - Color-coded activity types
- **Menu Bar Only** - Lives in menu bar, not Dock/Cmd+Tab
- **Activity Feed** - Real-time stream of AI actions
- **Settings Panel** - Configure all features
- **Dark Mode** - Full support for all appearances

---

## 🏗️ **Technical Architecture**

### **Core Components**

```
Sources/
├── main.swift                     # App entry point
├── AppDelegate.swift              # App lifecycle, coordinates all systems
├── MenuBarView.swift              # SwiftUI UI
├── Config.swift                   # Configuration & settings
├── Activity.swift                 # Data models
│
├── AgentEngine.swift              # Main intelligence coordinator
├── AIService.swift                # Claude API integration
├── ScreenshotCaptureEngine.swift  # ScreenCaptureKit integration
├── FileWatcher.swift              # FSEvents file monitoring
├── OCRService.swift               # Vision framework OCR
│
├── GitHubService.swift            # GitHub API client
├── GitHubMonitor.swift            # PR scanning & analysis
├── VSCodeMonitor.swift            # Code editor integration
├── BrowserMonitor.swift           # Browser monitoring
│
├── ClipboardMonitor.swift         # Clipboard intelligence
├── ProductivityTracker.swift      # Time tracking & analytics
├── SmartReminders.swift           # Context-aware reminders
├── TerminalMonitor.swift          # Shell command monitoring
├── NetworkMonitor.swift           # Network status tracking
├── CodeSnippetManager.swift       # Snippet library
├── FormAutomation.swift           # Accessibility-based automation
├── AutoDocGenerator.swift         # AI documentation
├── KeyboardShortcuts.swift        # Global hotkeys
└── MemoryManager.swift            # Learning & insights
```

### **Technologies Used**

- **SwiftUI** - Modern declarative UI
- **ScreenCaptureKit** - macOS screenshot API
- **Vision Framework** - OCR and image analysis
- **FSEvents** - File system change monitoring
- **Accessibility APIs** - Form detection and automation
- **UserNotifications** - Native notifications
- **EventKit** - Calendar integration
- **Network Framework** - Connection monitoring
- **Carbon** - Global keyboard shortcuts
- **Claude AI API** - Real AI analysis

### **Data Storage**

```
~/.background-ai-agent/
├── memory.md              # Main memory/learning file
├── memory.db             # (Future: SQLite database)
├── screenshots/          # Captured screenshots
├── code-fixes/           # AI-generated code fixes
├── snippets/             # Saved code snippets
└── logs/                 # Debug logs
```

---

## 🚀 **Getting Started**

### **Prerequisites**

- macOS 14.0 (Sonoma) or later
- Xcode 15+ or Swift 5.9+
- Claude API key (for AI features)
- GitHub token (optional, for GitHub integration)

### **Installation**

#### **1. Clone & Build**

```bash
git clone <repository-url>
cd background-ai-agent

# Build
make build

# Create .app bundle
make app

# Install to Applications
make install
```

#### **2. Configure API Keys**

Set environment variables:

```bash
export CLAUDE_API_KEY="your-claude-api-key"
export GITHUB_TOKEN="your-github-token"  # Optional
```

Or configure in the app's Settings panel after first launch.

#### **3. Grant Permissions**

On first launch, grant these permissions:

1. **Screen Recording** - For screenshot capture
2. **Accessibility** - For app monitoring & form automation
3. **Notifications** - For alerts

#### **4. Configure Watched Directories** (Optional)

Add project directories to monitor:

```swift
// In Settings UI or:
Settings.shared.watchedDirectories.append("/Users/you/Projects")
```

### **Quick Commands**

```bash
# Build and run
make run

# Just build
make build

# Create app bundle
make app

# Install to /Applications
make install

# Clean build artifacts
make clean

# Or use the build script
./build.sh
```

---

## ⚙️ **Configuration**

### **Settings**

Access via the Settings button in the menu bar popover:

- **Enable/Disable Features**
  - Code Analysis
  - GitHub Integration
  - Browser Monitoring
  - Screenshots
  - Notifications

- **API Keys**
  - Claude API Key
  - GitHub Token

- **Directories to Watch**
  - Add project folders for file watching

- **Launch at Login**
  - Auto-start with macOS

### **Feature Flags**

Edit `Config.swift` to customize:

```swift
AppConfig.enableAIAnalysis = true
AppConfig.enableCodeFixes = true
AppConfig.enableGitHubIntegration = true
AppConfig.screenshotInterval = 30.0  // seconds
```

---

## 💡 **Usage Examples**

### **Code Analysis**

1. Open a code file in VS Code/Xcode
2. Agent captures screenshot or watches file changes
3. AI analyzes code for issues
4. Sends notification: "Found memory leak in loop"
5. Saves auto-fix to `~/.background-ai-agent/code-fixes/`

### **GitHub PR Review**

1. Agent scans your repositories every 5 minutes
2. Finds open PRs
3. Downloads diff and analyzes with Claude
4. Posts review comment with findings
5. Notifies you of results

### **Clipboard Intelligence**

1. Copy code snippet
2. Agent detects it's code
3. AI analyzes for issues
4. Optionally saves to snippet library
5. Notifies about any problems found

### **Form Auto-Fill**

1. Open a web form
2. Agent detects form fields via Accessibility API
3. Generates smart form data (or uses AI)
4. Offers to fill form automatically
5. Fills fields when you approve

### **Terminal Commands**

1. Run `rm -rf /important`
2. Agent detects dangerous command
3. Warns you immediately
4. Suggests safer alternative

---

## 📊 **Analytics & Reports**

### **Productivity Report**

Access via keyboard shortcut or menu:

```
Top Apps (by time):
1. Xcode - 4h 32m
2. Visual Studio Code - 3h 15m
3. Chrome - 1h 45m

Daily Stats:
- Productive Time: 7h 47m
- Communication: 1h 30m
- Browsing: 45m

Focus Sessions: 3 completed
```

### **Code Statistics**

```
Issues Found: 42
- High Severity: 7
- Medium: 23
- Low: 12

Auto-Fixes Generated: 18
Languages Analyzed: Swift, JavaScript, Python
```

---

## 🔒 **Privacy & Security**

- ✅ **100% Local Processing** (except API calls to Claude/GitHub)
- ✅ **No Data Collection** - Nothing sent to third parties
- ✅ **API Keys Stored in Keychain** - macOS secure storage
- ✅ **Screenshots Stored Locally** - Full control over data
- ✅ **Open Source** - Audit the code yourself
- ✅ **Opt-In Features** - Disable anything you don't want
- ✅ **Easy Data Deletion** - Delete `~/.background-ai-agent/` anytime

### **What Gets Sent to APIs?**

- **Claude API**: Code snippets, screenshots (if vision enabled), prompts
- **GitHub API**: Only when scanning PRs/repos you have access to

You can disable AI features and run in local-only mode.

---

## 🛠️ **Development**

### **Project Structure**

- Clean Swift code with modern async/await
- SwiftUI for UI
- Protocol-oriented design
- Dependency injection where appropriate

### **Adding New Features**

1. Create new monitor/service file in `Sources/`
2. Add to `AppDelegate.initializeAdvancedTools()`
3. Wire up activity callback
4. Update README

### **Testing**

```bash
swift test
```

### **Debugging**

Check console output:

```bash
log stream --predicate 'process == "BackgroundAIAgent"' --level debug
```

---

## 🤝 **Contributing**

Contributions welcome! This is an open platform for AI-powered productivity tools.

### **Ideas for More Features**

- Voice commands (Siri integration)
- Multi-display support
- Cloud sync for memory/snippets
- Slack/Discord integration
- Email analysis
- Meeting transcription
- Custom automation rules
- Plugin system
- ...and more!

---

## 📝 **License**

MIT License - Use freely, modify as needed!

---

## 🙏 **Acknowledgments**

**Built with:**
- Claude AI (Anthropic)
- macOS  Sonoma APIs
- Swift & SwiftUI
- Love for productivity

---

## 📞 **Support**

- 🐛 **Issues**: Open a GitHub issue
- 💬 **Discussions**: GitHub Discussions
- 📧 **Email**: [Your contact]

---

**Made with 🧠, ❤️, and WAY too much coffee by your friendly AI assistant**

*This app is NOT a simulation - it's REAL AI-powered automation for your Mac!*
