# Appium Swift Client

![Swift](https://img.shields.io/badge/Swift-6.0-blue)
![Platforms](https://img.shields.io/badge/Platforms-macOS_%7C_Linux_%7C_Windows-blue)
![License](https://img.shields.io/badge/License-Apache_2.0-green)

SwiftAppium is a modern Swift client for the Appium automation server. It provides a type-safe, async/await API for mobile app testing.

- Session Management
  - Create/Delete sessions
  - Get active sessions
  - Get server status

- Element Interactions
  - Find elements
  - Click elements
  - Send keys
  - Get element text
  - Check element state

- App Management
  - Launch/close apps
  - Reset app state
  - Handle app settings

- Device Controls
  - Handle keyboard
  - Manage orientation
  - Take screenshots

## Requirements

- macOS 14.0+
- Swift 6.0+
- Xcode 15.0+

## Setup

### 1. Install Appium Server

First, ensure you have Node.js installed, then install Appium:

```bash
npm install -g appium
```

Start the Appium server:

```bash
appium
```

### 2. Add SwiftAppium to Your Project

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/milcgroup/SwiftAppium.git", from: "1.0.0")
]
```

### 3. Basic Usage

First, import SwiftAppium in your test file:

```swift
import SwiftAppium
import Testing

// Example test function
@Test
func testApp() async throws {
    // Start a session with desired capabilities
    let capabilities = [
        "platformName": "iOS",
        "automationName": "XCUITest",
        udid: "Device UUID",
        "deviceName": "iPhone 16",
        "app": "yourapp.bundle.id"
    ]
    
    // Get server status
    let status = try await client.getStatus()
    print("Server is ready: \(status.ready)")
    
    // Find and interact with elements
    try await client.waitAndClickElement(
        client, sessionId,
        strategy: .accessibilityId,
        selector: "button"
    )
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.
