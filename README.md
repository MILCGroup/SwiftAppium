# SwiftAppium

![Swift](https://img.shields.io/badge/Swift-6.0-blue)
![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Linux-blue)
![License](https://img.shields.io/badge/License-Apache_2.0-green)

A modern Swift client library for Appium automation with a powerful **Web Recorder** that captures browser interactions and generates executable Swift test code automatically.

## ✨ Key Features

- **🎬 Web Recorder** - Record browser interactions and generate Swift test code automatically
- **🚀 One-Command Setup** - Just run `swiftappium` to start recording
- **🔄 Auto-Connect** - Automatically discovers and connects to existing Appium sessions
- **⚡ Real-time Playback** - Replay recorded events instantly in the browser
- **📱 Cross-Platform** - Works on macOS and Linux
- **🎯 Type-safe API** - Modern Swift with async/await support

## Requirements

- **macOS 14.0+** or **Linux** (Ubuntu 20.04+)
- **Swift 5.10+**
- **Appium Server 2.0+**
- **Chrome/Chromium browser**

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install Node.js and Appium
brew install node                    # macOS
# or: apt-get install nodejs npm     # Linux

npm install -g appium
appium driver install chromium
```

### 2. Start Appium Server

```bash
appium
```

### 3. Start Recording

```bash
# Clone and build SwiftAppium
git clone https://github.com/milcgroup/SwiftAppium.git
cd SwiftAppium
swift build

# Start the web recorder
swift run swiftappium
```

That's it! The web recorder will:
- ✅ **Auto-open** your browser to the recording interface
- ✅ **Auto-connect** to your Appium session  
- ✅ **Start recording** immediately

### 4. Record Your First Test

1. **Navigate to any website** in your browser
2. **Interact normally** - click buttons, fill forms, navigate pages
3. **Watch events appear** in real-time in the recording interface
4. **Click "▶️ Play Events"** to replay your interactions
5. **Click "💾 Export Swift Code"** to download your test

**Generated Swift code example:**
```swift
import SwiftAppium
import Testing

@Test("Recorded browser interactions")
func recordedBrowserTest() async throws {
    let session = try await Session(
        host: "127.0.0.1",
        port: 4723,
        driver: Driver.Chromium()
    )
    
    // Click login button
    try await session.click(
        Element(.xpath, Selector("//button[@id='login']"))
    )
    
    // Type username
    try await session.type(
        Element(.xpath, Selector("//input[@name='username']")),
        text: "testuser"
    )
}
```

## 🎬 Web Recorder Features

### ✅ **Automatic Everything**
- **Auto-connects** to existing Appium sessions
- **Auto-opens** browser interface  
- **Auto-starts** recording when connected
- **Auto-generates** clean Swift code

### ✅ **Smart Event Capture**
- **Click events** - Buttons, links, any clickable element
- **Text input** - Forms, search boxes, text areas
- **Element detection** - Robust XPath generation with ID prioritization
- **Event validation** - Filters out invalid or duplicate events

### ✅ **Real-time Playback**
- **Instant replay** - Test your recorded interactions immediately
- **Visual feedback** - See events execute in real-time
- **Error handling** - Graceful handling of missing elements

### ✅ **Clean Code Generation**
- **Modern Swift** - Uses async/await patterns
- **SwiftAppium API** - Generated code uses the full SwiftAppium library
- **Proper structure** - Includes imports, error handling, and test framework integration
- **Executable immediately** - No manual editing required

## 🛠️ Advanced Usage

### Custom Port
```bash
swift run swiftappium --port 9090
```

### Custom Appium Server
```bash
swift run swiftappium --appium-url http://remote-server:4723
```

### Command Line Options
```bash
swift run swiftappium --help
```

## 🔧 How It Works

The web recorder uses a sophisticated approach to capture and replay browser interactions:

1. **JavaScript Injection** - Injects event listeners into browser pages
2. **Event Capture** - Records genuine user interactions (clicks, typing)
3. **Smart Selectors** - Generates robust XPath selectors (prioritizes element IDs)
4. **Real-time Sync** - Updates the web interface as events are captured
5. **Code Generation** - Converts events to clean, executable Swift code
6. **Playback Engine** - Replays events using WebDriver commands

## 📚 Documentation

- **[Error Handling](Sources/Documentation.docc/ErrorHandling.md)** - Error handling strategies
- **[Troubleshooting](Sources/Documentation.docc/Troubleshooting.md)** - Common issues and solutions

## 🚨 Troubleshooting

### Common Issues

**"No active Appium sessions found"**
```bash
# Make sure Appium server is running
appium

# In another terminal, create a browser session
# (or use your existing Appium client)
```

**"Port 8080 is in use"**
```bash
# Use a different port
swift run swiftappium --port 9090
```

**"Failed to open browser automatically"**
- Manually navigate to `http://localhost:8080`
- Check that you have a default browser set

**Events not being captured**
- Make sure you're interacting with the actual browser window (not the recording interface)
- Some sites with strict CSP may block JavaScript injection
- Try refreshing the page and reconnecting

## Contributing

We welcome contributions! Please see our contributing guidelines and feel free to submit issues and pull requests.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE.txt) file for details.
