# 🚀 Quick Start Guide

Get your Background AI Agent up and running in 5 minutes!

## Step 1: Build the App

Choose your preferred method:

### Option A: Using Make (Recommended)
```bash
make build      # Build the executable
make app        # Create .app bundle
make install    # Install to /Applications
```

### Option B: Using Build Script
```bash
./build.sh      # Automated build with nice output
```

### Option C: Manual Swift Build
```bash
swift build -c release
.build/release/BackgroundAIAgent
```

## Step 2: Launch the App

After building:

```bash
# If you used 'make app'
open BackgroundAIAgent.app

# If you installed to Applications
open /Applications/BackgroundAIAgent.app

# Or run directly
.build/release/BackgroundAIAgent
```

## Step 3: Grant Permissions

On first launch, you'll see permission dialogs:

1. **✅ Click "Open System Settings"** for Screen Recording
   - Enable permission for BackgroundAIAgent
   - Restart the app

2. **✅ Click "Open System Settings"** for Accessibility
   - Enable permission for BackgroundAIAgent

3. **✅ Allow Notifications** when prompted

## Step 4: Start Using It!

1. **Look for the brain icon** in your menu bar (top right)
2. **Click it** to see the beautiful UI
3. **Toggle it ON** if not already enabled
4. **Open VS Code or a browser** and watch the magic happen!

## What to Expect

### When you open VS Code/Xcode:
- App takes a screenshot
- Analyzes your code
- Might send a notification like:
  > "Fixed Memory Leak - Found potential memory leak in your loop. Added proper cleanup!"

### When you open Safari/Chrome:
- Monitors browser content
- Detects forms (offers to auto-fill)
- Might notify about documentation or PRs

### When working with GitHub:
- Scans pull requests periodically
- Analyzes code changes
- Reports issues or improvements

## Your Memory File

The AI learns about you and saves insights here:
```bash
~/.background-ai-agent/memory.md
```

Open it to see what the AI has learned about your habits!

## Screenshots

Screenshots are saved here:
```bash
~/.background-ai-agent/screenshots/
```

## Controls

Click the menu bar icon to access:
- **Toggle Switch** - Turn monitoring on/off
- **Settings** - Configure what gets monitored
- **Memory** - View your AI's learned patterns
- **Refresh** - Update the activity feed
- **Quit** - Close the app

## Troubleshooting

### App doesn't appear in menu bar
- Check if it's running: `ps aux | grep BackgroundAIAgent`
- Look for the brain icon in the top-right corner

### No notifications appearing
- Go to System Settings > Notifications
- Find BackgroundAIAgent
- Enable "Allow Notifications"

### Screenshots not working
- Go to System Settings > Privacy & Security > Screen Recording
- Enable permission for BackgroundAIAgent
- Restart the app

### Can't access certain features
- Go to System Settings > Privacy & Security > Accessibility
- Enable permission for BackgroundAIAgent

## Tips

- **Pause when needed**: Use the toggle to pause monitoring during sensitive work
- **Check memory file**: Your AI's insights are in `~/.background-ai-agent/memory.md`
- **Privacy first**: All processing happens locally, nothing goes to the cloud
- **Clean up**: Delete `~/.background-ai-agent/` to reset all data

## What's Next?

- Let the AI watch your workflow for a day
- Check the memory file to see what it learned
- Watch for helpful notifications
- Customize settings to your preferences

---

**Enjoy your AI assistant!** 🧠✨

For more details, see [README.md](README.md)
