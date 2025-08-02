//
//  WebRecorder.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import AsyncHTTPClient
import Foundation
import Logging
import NIOCore
import Vapor

// Decodes the session creation response from the Appium server.
private struct CreateSessionResponse: Decodable {
  struct Value: Decodable {
    let sessionId: String
  }
  let value: Value
}

private struct RecordedEvent: Codable, Sendable {
  let type: String
  let xpath: String
  let value: String?
  let timestamp: Int64
}

// Real Appium session implementation using HTTP client
struct RealAppiumSession {
  let client: HTTPClient
  let id: String
  let platform: String
  let browserName: String
  let appiumUrl: URL

  func deleteSession() async throws {
    let url = appiumUrl.appendingPathComponent("session/\(id)")

    var request = HTTPClientRequest(url: url.absoluteString)
    request.method = .DELETE
    request.headers.add(name: "Content-Type", value: "application/json")

    do {
      let _ = try await client.execute(request, timeout: .seconds(30))
      print("✅ Appium session \(id) deleted successfully")
    } catch {
      print("⚠️ Failed to delete Appium session: \(error)")
    }
  }

  func executeScript(script: String, args: [Any]) async throws -> Any? {
    let url = appiumUrl.appendingPathComponent("session/\(id)/execute/sync")

    let requestBody: [String: Any] = [
      "script": script,
      "args": args,
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

    var request = HTTPClientRequest(url: url.absoluteString)
    request.method = .POST
    request.headers.add(name: "Content-Type", value: "application/json")
    request.body = .bytes(ByteBuffer(data: jsonData))

    let response = try await client.execute(request, timeout: .seconds(30))

    guard response.status == .ok else {
      throw AppiumError.scriptExecutionFailed("HTTP \(response.status.code)")
    }

    let responseData = try await response.body.collect(upTo: 1024 * 1024)  // 1MB limit
    let responseJson = try JSONSerialization.jsonObject(with: Data(buffer: responseData))

    if let responseDict = responseJson as? [String: Any],
      let value = responseDict["value"]
    {
      return value
    }

    return nil
  }
}

enum AppiumError: Error, LocalizedError {
  case sessionCreationFailed(String)
  case scriptExecutionFailed(String)
  case navigationFailed(String)

  var errorDescription: String? {
    switch self {
    case .sessionCreationFailed(let message):
      return "Failed to create Appium session: \(message)"
    case .scriptExecutionFailed(let message):
      return "Failed to execute script: \(message)"
    case .navigationFailed(let message):
      return "Failed to navigate: \(message)"
    }
  }
}

enum WebRecorderError: Error, LocalizedError {
  case sessionSetupFailed(Error)
  case scriptInjectionFailed(Error)
  case eventPollingFailed(Error)
  case serverStartupFailed(Error)

  var errorDescription: String? {
    switch self {
    case .sessionSetupFailed(let error):
      return "Session setup failed: \(error.localizedDescription)"
    case .scriptInjectionFailed(let error):
      return "Script injection failed: \(error.localizedDescription)"
    case .eventPollingFailed(let error):
      return "Event polling failed: \(error.localizedDescription)"
    case .serverStartupFailed(let error):
      return "Server startup failed: \(error.localizedDescription)"
    }
  }
}

// Type alias for compatibility
typealias AppiumSession = RealAppiumSession

public class WebRecorder: @unchecked Sendable {
  // MARK: - Configuration
  private let port: Int
  private let appiumUrl: URL
  private let logger: Logger

  // MARK: - State Management
  private var isRunning = false
  private var isRecording = false
  private let lifecycleQueue = DispatchQueue(label: "WebRecorder.lifecycle", qos: .userInitiated)

  // MARK: - Vapor Server
  private var app: Application?
  private var serverTask: Task<Void, Error>?

  // MARK: - Appium Session
  private var session: RealAppiumSession?
  private let httpClient: HTTPClient

  // MARK: - Event Management
  private var events: [RecordedEvent] = []
  private let eventsQueue = DispatchQueue(label: "WebRecorder.events", qos: .userInitiated)
  private var pollingTask: Task<Void, Never>?
  private let pollingInterval: TimeInterval = 1.0

  // MARK: - Environment Detection
  private var isWSL: Bool {
    // Check if running in WSL by examining /proc/version
    guard let versionData = try? Data(contentsOf: URL(fileURLWithPath: "/proc/version")),
          let versionString = String(data: versionData, encoding: .utf8) else {
      return false
    }
    
    return versionString.lowercased().contains("microsoft") || 
           versionString.lowercased().contains("wsl")
  }

  // MARK: - Initialization
  public init(port: Int = 8080, appiumUrl: URL = URL(string: "http://localhost:4723/wd/hub")!) {
    self.port = port
    self.appiumUrl = appiumUrl
    self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

    var logger = Logger(label: "WebRecorder")
    logger.logLevel = .info
    self.logger = logger

    if isWSL {
      logger.info("WSL environment detected - applying WSL-specific configurations")
    }
    
    logger.info("WebRecorder initialized on port \(port)")
  }

  deinit {
    lifecycleQueue.sync {
      if isRunning {
        logger.warning("WebRecorder deallocated while still running - performing emergency cleanup")
        performCleanup()
      }
    }
  }

  // MARK: - Public Interface
  public func start() async throws {
    lifecycleQueue.sync {
      guard !isRunning else {
        logger.warning("WebRecorder is already running")
        return
      }

      logger.info("Starting WebRecorder...")
      isRunning = true
    }

    do {
      // Initialize Vapor application
      try await setupVaporServer()

      // Set up Appium session (no automatic creation)
      try await setupAppiumSession()

      logger.info("Web recorder started successfully on port \(port)")
      print("🎬 SwiftAppium Web Recorder is running!")
      
      if isWSL {
        print("🐧 WSL Environment Detected")
        print("📱 Web interface: http://localhost:\(port)")
        print("🌐 From Windows: http://localhost:\(port)")
        print("💡 If localhost doesn't work, try your WSL IP address")
        print("🛑 Press Ctrl+C to stop recording")
      } else {
        print("📱 Web interface: http://localhost:\(port)")
        print("🛑 Press Ctrl+C to stop recording")
      }
      
      // Automatically open the web interface in the default browser
      await openWebInterface()

    } catch {
      logger.error("Failed to start WebRecorder: \(error)")
      try await shutdown()
      throw WebRecorderError.serverStartupFailed(error)
    }
  }

  public func shutdown() async throws {
    logger.info("Shutting down WebRecorder...")

    lifecycleQueue.sync {
      guard isRunning else {
        logger.info("WebRecorder is not running")
        return
      }

      isRunning = false
    }

    // Stop event polling
    stopEventPolling()

    // Perform async cleanup
    await performAsyncCleanup()

    logger.info("WebRecorder shutdown complete")
  }

  // MARK: - Vapor Server Setup
  private func setupVaporServer() async throws {
    logger.info("Setting up Vapor server on port \(port)")

    // Create Vapor application with empty arguments to avoid CLI conflicts
    var env = Environment.development
    env.arguments = ["vapor"]  // Just program name, no commands

    let app = try await Application.make(env)
    self.app = app

    // Configure server binding with WSL-specific handling
    if isWSL {
      // In WSL, bind to all interfaces to ensure accessibility from Windows
      app.http.server.configuration.hostname = "0.0.0.0"
      logger.info("WSL detected: binding to 0.0.0.0 for Windows accessibility")
    } else {
      // Native systems: bind to localhost only for security
      app.http.server.configuration.hostname = "127.0.0.1"
    }
    app.http.server.configuration.port = port

    // Configure routes first
    configureVaporRoutes()

    // Add test route
    app.get("test") { req in
      return "WebRecorder is working!"
    }

    logger.info("Starting Vapor server on http://127.0.0.1:\(port)")

    do {
      // Start the application
      try await app.startup()
      logger.info("✅ Vapor application startup completed")

      // Start server in background - this is the key fix
      serverTask = Task { [weak self] in
        do {
          // This will start the HTTP server and keep it running
          try await app.running?.onStop.get()
          self?.logger.info("Vapor server stopped")
        } catch {
          self?.logger.error("Vapor server error: \(error)")
        }
      }

      // Small delay to let server start
      try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

      logger.info("✅ Vapor server is now running and ready to serve requests")

    } catch {
      logger.error("❌ Failed to start Vapor server: \(error)")
      throw error
    }
  }

  // MARK: - Session Management
  public func connectToSession(sessionId: String) async throws {
    logger.info("Connecting to existing Appium session: \(sessionId)")

    // Create session object for existing session
    session = RealAppiumSession(
      client: httpClient,
      id: sessionId,
      platform: "mac",  // Could be detected from session info
      browserName: "Chrome",  // Could be detected from session info
      appiumUrl: appiumUrl
    )

    // Verify the session exists and is accessible
    do {
      let script = "return window.navigator.userAgent;"
      _ = try await session?.executeScript(script: script, args: [])
      logger.info("Successfully connected to session: \(sessionId)")

      // Now that we have a session, inject the recorder script and start polling
      try await injectRecorderScript()
      startEventPolling()

    } catch {
      session = nil
      throw AppiumError.sessionCreationFailed("Could not connect to session \(sessionId): \(error)")
    }
  }

  public func discoverAvailableSessions() async throws -> [String] {
    logger.info("Discovering available Appium sessions")

    do {
      // Query Appium server for active sessions
      let sessionsUrl = appiumUrl.appendingPathComponent("sessions")

      var request = HTTPClientRequest(url: sessionsUrl.absoluteString)
      request.method = .GET
      request.headers.add(name: "Content-Type", value: "application/json")

      let response = try await httpClient.execute(request, timeout: .seconds(10))

      guard response.status == .ok else {
        logger.warning("Failed to query Appium sessions: HTTP \(response.status.code)")
        return []
      }

      let responseData = try await response.body.collect(upTo: 1024 * 1024)  // 1MB limit
      let responseJson = try JSONSerialization.jsonObject(with: Data(buffer: responseData))

      // Parse Appium sessions response
      if let responseDict = responseJson as? [String: Any],
        let value = responseDict["value"] as? [[String: Any]]
      {

        let sessionIds = value.compactMap { sessionInfo -> String? in
          return sessionInfo["id"] as? String
        }

        logger.info("Found \(sessionIds.count) active Appium sessions")
        return sessionIds

      } else {
        logger.warning("Unexpected response format from Appium sessions endpoint")
        return []
      }

    } catch {
      logger.error("Failed to discover Appium sessions: \(error)")
      // Don't throw - just return empty array so UI doesn't break
      return []
    }
  }

  private func setupAppiumSession() async throws {
    logger.info("Attempting to auto-connect to existing Appium sessions...")
    
    do {
      // Discover available sessions
      let availableSessions = try await discoverAvailableSessions()
      
      if let firstSession = availableSessions.first {
        logger.info("Found session \(firstSession), connecting automatically...")
        try await connectToSession(sessionId: firstSession)
        logger.info("✅ Successfully auto-connected to session: \(firstSession)")
      } else {
        logger.info("No existing Appium sessions found. Please create a session and refresh the web interface.")
      }
    } catch {
      logger.warning("Failed to auto-connect to Appium session: \(error)")
      logger.info("You can manually connect via the web interface once a session is available.")
    }
  }

  // MARK: - Browser Launching
  private func openWebInterface() async {
    let url = "http://localhost:\(port)"
    logger.info("Opening web interface in default browser: \(url)")
    
    #if canImport(Darwin)
    // macOS
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = [url]
    
    do {
      try task.run()
      logger.info("✅ Web interface opened in default browser")
    } catch {
      logger.warning("Failed to open browser automatically: \(error)")
      print("Please manually open: \(url)")
    }
    
    #elseif canImport(Glibc)
    // Linux/WSL
    if isWSL {
      // WSL-specific browser launching
      await openWebInterfaceWSL(url: url)
    } else {
      // Native Linux
      let task = Process()
      task.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
      task.arguments = [url]
      
      do {
        try task.run()
        logger.info("✅ Web interface opened in default browser")
      } catch {
        logger.warning("Failed to open browser automatically: \(error)")
        print("Please manually open: \(url)")
      }
    }
    #endif
  }
  
  #if canImport(Glibc)
  private func openWebInterfaceWSL(url: String) async {
    logger.info("WSL detected - attempting multiple browser launch methods")
    
    // Method 1: Try Windows browser via cmd.exe
    do {
      let task = Process()
      task.executableURL = URL(fileURLWithPath: "/mnt/c/Windows/System32/cmd.exe")
      task.arguments = ["/c", "start", url]
      
      try task.run()
      task.waitUntilExit()
      
      if task.terminationStatus == 0 {
        logger.info("✅ Web interface opened via Windows browser")
        return
      }
    } catch {
      logger.debug("Windows browser launch failed: \(error)")
    }
    
    // Method 2: Try wslview if available
    do {
      let task = Process()
      task.executableURL = URL(fileURLWithPath: "/usr/bin/wslview")
      task.arguments = [url]
      
      try task.run()
      logger.info("✅ Web interface opened via wslview")
      return
    } catch {
      logger.debug("wslview launch failed: \(error)")
    }
    
    // Method 3: Try xdg-open (might work with X11 forwarding)
    do {
      let task = Process()
      task.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
      task.arguments = [url]
      
      try task.run()
      logger.info("✅ Web interface opened via xdg-open")
      return
    } catch {
      logger.debug("xdg-open launch failed: \(error)")
    }
    
    // Fallback: Provide manual instructions
    logger.warning("All automatic browser launch methods failed in WSL")
    print("🌐 WSL Browser Launch Instructions:")
    print("   Option 1: Open your Windows browser and navigate to: \(url)")
    print("   Option 2: Install wslu package: sudo apt install wslu")
    print("   Option 3: Set up X11 forwarding for Linux browsers")
    print("   Option 4: Use Windows Terminal with --wsl flag")
  }
  #endif

  // MARK: - JavaScript Injection
  private func injectRecorderScript() async throws {
    logger.info("Injecting JavaScript recorder script")

    let maxRetries = isWSL ? 5 : 3  // More retries for WSL
    let retryDelay: UInt64 = isWSL ? 2_000_000_000 : 1_000_000_000  // Longer delay for WSL
    
    for attempt in 1...maxRetries {
      do {
        logger.debug("JavaScript injection attempt \(attempt)/\(maxRetries)")

        let script = generateRecorderScript()
        let result = try await session?.executeScript(script: script, args: [])

        logger.info("JavaScript recorder injected successfully: \(result ?? "unknown")")

        // Verify injection worked with WSL-specific timeout
        try await verifyScriptInjection()

        // Enable debug mode in WSL for better troubleshooting
        if isWSL {
          try await enableDebugMode()
        }

        // Start recording automatically
        isRecording = true
        logger.info("Recording started automatically")

        return

      } catch {
        logger.warning("JavaScript injection attempt \(attempt) failed: \(error)")
        
        if isWSL {
          logger.info("WSL detected - this might be due to browser security policies or timing issues")
        }

        if attempt == maxRetries {
          if isWSL {
            logger.error("JavaScript injection failed in WSL environment. This could be due to:")
            logger.error("1. Browser security policies (CSP)")
            logger.error("2. Chrome running in different security context")
            logger.error("3. Network timing issues between WSL and browser")
            logger.error("Try: Opening browser console to check for errors")
          }
          throw WebRecorderError.scriptInjectionFailed(error)
        }

        // Wait before retry with longer delay for WSL
        try await Task.sleep(nanoseconds: retryDelay)
      }
    }
  }
  
  private func enableDebugMode() async throws {
    guard let session = session else { return }
    
    let debugScript = """
      if (window.swiftAppiumRecorder) {
        window.swiftAppiumRecorder.setDebugMode(true);
        console.log('[SwiftAppium] Debug mode enabled for WSL troubleshooting');
        return 'Debug mode enabled';
      }
      return 'Recorder not found';
    """
    
    do {
      let result = try await session.executeScript(script: debugScript, args: [])
      logger.info("Debug mode enabled: \(result ?? "unknown")")
    } catch {
      logger.warning("Failed to enable debug mode: \(error)")
    }
  }

  private func generateRecorderScript() -> String {
    return """
      // SwiftAppium Web Recorder JavaScript
      (function() {
          "use strict";
          
          // Namespace for SwiftAppium events to avoid conflicts
          window.swiftAppiumEvents = window.swiftAppiumEvents || [];
          
          // Configuration
          const CONFIG = {
              maxEvents: 10000,
              debugMode: false
          };
          
          // Utility function for logging
          function log(message, data) {
              if (CONFIG.debugMode) {
                  console.log("[SwiftAppium Recorder]", message, data || "");
              }
          }
          
          // Robust XPath generator prioritizing element IDs
          function getXPath(element) {
              if (!element || element.nodeType !== 1) {
                  log("Invalid element for XPath generation");
                  return "";
              }
              
              // Prioritize ID attribute for reliability
              if (element.id && element.id.trim() !== "") {
                  const xpath = "//*[@id=\\"" + element.id + "\\"]";
                  log("Generated ID-based XPath:", xpath);
                  return xpath;
              }
              
              // Fallback to path-based XPath
              const segments = [];
              let currentElement = element;
              
              while (currentElement && currentElement.nodeType === 1 && currentElement !== document.documentElement) {
                  let index = 1;
                  let sibling = currentElement.previousElementSibling;
                  
                  // Count siblings with the same tag name
                  while (sibling) {
                      if (sibling.localName === currentElement.localName) {
                          index++;
                      }
                      sibling = sibling.previousElementSibling;
                  }
                  
                  const tagName = currentElement.localName || "unknown";
                  segments.unshift(tagName + "[" + index + "]");
                  currentElement = currentElement.parentElement;
              }
              
              const xpath = segments.length ? "//" + segments.join("/") : "";
              log("Generated path-based XPath:", xpath);
              return xpath;
          }
          
          // Event validation function
          function isValidEvent(event) {
              return event && 
                     event.isTrusted && 
                     event.target && 
                     event.target.nodeType === 1;
          }
          
          // Add event to the collection with validation
          function addEvent(type, element, value) {
              try {
                  if (!isValidEvent({ isTrusted: true, target: element })) {
                      log("Invalid event, skipping");
                      return;
                  }
                  
                  const xpath = getXPath(element);
                  if (!xpath) {
                      log("Could not generate XPath, skipping event");
                      return;
                  }
                  
                  const eventData = {
                      type: type,
                      xpath: xpath,
                      value: value || null,
                      timestamp: Date.now()
                  };
                  
                  // Prevent event overflow
                  if (window.swiftAppiumEvents.length >= CONFIG.maxEvents) {
                      window.swiftAppiumEvents.shift(); // Remove oldest event
                      log("Event buffer full, removed oldest event");
                  }
                  
                  window.swiftAppiumEvents.push(eventData);
                  log("Event added:", eventData);
                  
              } catch (error) {
                  console.error("[SwiftAppium Recorder] Error adding event:", error);
              }
          }
          
          // Click event handler with comprehensive element support
          function handleClick(event) {
              if (!isValidEvent(event)) {
                  log("Click event validation failed");
                  return;
              }
              
              const element = event.target;
              const tagName = element.tagName.toLowerCase();
              const type = element.type || "";
              
              log("Click event detected on:", element, "tag:", tagName, "type:", type);
              
              // Special handling for different element types
              let eventType = "click";
              let value = null;
              
              if (tagName === "input") {
                  if (type === "checkbox" || type === "radio") {
                      eventType = type + "_click";
                      value = element.checked ? "true" : "false";
                  } else if (type === "submit" || type === "button") {
                      eventType = "button_click";
                      value = element.value || element.textContent || "";
                  }
              } else if (tagName === "button") {
                  eventType = "button_click";
                  value = element.textContent || element.value || "";
              } else if (tagName === "a") {
                  eventType = "link_click";
                  value = element.href || element.textContent || "";
              } else if (tagName === "select") {
                  eventType = "select_click";
                  value = element.value || "";
              }
              
              addEvent(eventType, element, value);
          }
          
          // Input event handler with comprehensive support
          function handleInput(event) {
              if (!isValidEvent(event)) {
                  log("Input event validation failed");
                  return;
              }
              
              const element = event.target;
              const value = element.value || "";
              const tagName = element.tagName.toLowerCase();
              const type = element.type || "";
              
              log("Input event detected on:", element, "value:", value);
              
              let eventType = "input";
              if (tagName === "textarea") {
                  eventType = "textarea_input";
              } else if (tagName === "input") {
                  eventType = type + "_input";
              }
              
              addEvent(eventType, element, value);
          }
          
          // Change event handler for select dropdowns and other form elements
          function handleChange(event) {
              if (!isValidEvent(event)) {
                  log("Change event validation failed");
                  return;
              }
              
              const element = event.target;
              const tagName = element.tagName.toLowerCase();
              const type = element.type || "";
              
              log("Change event detected on:", element);
              
              let eventType = "change";
              let value = null;
              
              if (tagName === "select") {
                  eventType = "select_change";
                  const selectedOption = element.options[element.selectedIndex];
                  value = selectedOption ? selectedOption.text : element.value;
              } else if (tagName === "input") {
                  if (type === "checkbox" || type === "radio") {
                      eventType = type + "_change";
                      value = element.checked ? "true" : "false";
                  } else {
                      eventType = type + "_change";
                      value = element.value || "";
                  }
              }
              
              addEvent(eventType, element, value);
          }
          
          // Keydown event handler for important keys
          function handleKeydown(event) {
              if (!isValidEvent(event)) {
                  log("Keydown event validation failed");
                  return;
              }
              
              // Only capture important keys
              const importantKeys = ["Enter", "Tab", "Escape", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"];
              if (!importantKeys.includes(event.key)) {
                  return;
              }
              
              const element = event.target;
              log("Keydown event detected:", event.key, "on:", element);
              
              addEvent("keydown", element, event.key);
          }
          
          // Form submit handler
          function handleSubmit(event) {
              if (!isValidEvent(event)) {
                  log("Submit event validation failed");
                  return;
              }
              
              const form = event.target;
              log("Form submit detected on:", form);
              
              // Capture form action and method
              const action = form.action || "";
              const method = form.method || "GET";
              const value = method.toUpperCase() + " " + action;
              
              addEvent("form_submit", form, value);
          }
          
          // Focus event handler
          function handleFocus(event) {
              if (!isValidEvent(event)) {
                  log("Focus event validation failed");
                  return;
              }
              
              const element = event.target;
              const tagName = element.tagName.toLowerCase();
              
              // Only capture focus on interactive elements
              if (["input", "textarea", "select", "button"].includes(tagName)) {
                  log("Focus event detected on:", element);
                  addEvent("focus", element, null);
              }
          }
          
          // Remove existing listeners to prevent duplicates
          function removeExistingListeners() {
              const handlers = [
                  "swiftAppiumClickHandler",
                  "swiftAppiumInputHandler", 
                  "swiftAppiumChangeHandler",
                  "swiftAppiumKeydownHandler",
                  "swiftAppiumSubmitHandler",
                  "swiftAppiumFocusHandler"
              ];
              
              handlers.forEach(function(handlerName) {
                  if (window[handlerName]) {
                      const eventType = handlerName.replace("swiftAppium", "").replace("Handler", "").toLowerCase();
                      document.removeEventListener(eventType, window[handlerName], true);
                  }
              });
          }
          
          // Install event listeners
          function installEventListeners() {
              removeExistingListeners();
              
              // Store handlers globally for cleanup
              window.swiftAppiumClickHandler = handleClick;
              window.swiftAppiumInputHandler = handleInput;
              window.swiftAppiumChangeHandler = handleChange;
              window.swiftAppiumKeydownHandler = handleKeydown;
              window.swiftAppiumSubmitHandler = handleSubmit;
              window.swiftAppiumFocusHandler = handleFocus;
              
              // Add event listeners with capture phase for better reliability
              document.addEventListener("click", window.swiftAppiumClickHandler, true);
              document.addEventListener("input", window.swiftAppiumInputHandler, true);
              document.addEventListener("change", window.swiftAppiumChangeHandler, true);
              document.addEventListener("keydown", window.swiftAppiumKeydownHandler, true);
              document.addEventListener("submit", window.swiftAppiumSubmitHandler, true);
              document.addEventListener("focus", window.swiftAppiumFocusHandler, true);
              
              log("All event listeners installed successfully");
          }
          
          // API for retrieving and clearing events
          window.swiftAppiumRecorder = {
              getEvents: function() {
                  return window.swiftAppiumEvents.slice(); // Return copy
              },
              
              clearEvents: function() {
                  const count = window.swiftAppiumEvents.length;
                  window.swiftAppiumEvents = [];
                  log("Cleared", count, "events");
                  return count;
              },
              
              getEventCount: function() {
                  return window.swiftAppiumEvents.length;
              },
              
              setDebugMode: function(enabled) {
                  CONFIG.debugMode = !!enabled;
                  log("Debug mode", enabled ? "enabled" : "disabled");
              },
              
              isInstalled: function() {
                  return true;
              }
          };
          
          // Install the event listeners
          installEventListeners();
          
          // Handle page navigation and dynamic content
          if (document.readyState === "loading") {
              document.addEventListener("DOMContentLoaded", installEventListeners);
          }
          
          log("SwiftAppium Web Recorder initialized successfully");
          return "SwiftAppium Web Recorder initialized";
          
      })();
      """
  }

  private func verifyScriptInjection() async throws {
    logger.debug("Verifying JavaScript injection")

    guard let session = session else {
      throw WebRecorderError.sessionSetupFailed(
        NSError(
          domain: "WebRecorder", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "No active session"]))
    }

    let verificationScript =
      "return window.swiftAppiumRecorder && window.swiftAppiumRecorder.isInstalled();"

    do {
      let result = try await session.executeScript(script: verificationScript, args: [])

      if let isInstalled = result as? Bool, isInstalled {
        logger.info("JavaScript recorder verification successful")
      } else {
        throw WebRecorderError.scriptInjectionFailed(
          NSError(
            domain: "WebRecorder", code: -2,
            userInfo: [NSLocalizedDescriptionKey: "Script verification failed"]))
      }
    } catch {
      logger.error("JavaScript recorder verification failed: \(error)")
      throw WebRecorderError.scriptInjectionFailed(error)
    }
  }

  // MARK: - Event Polling & Management
  private func startEventPolling() {
    logger.info("Starting event polling")

    pollingTask = Task { [weak self] in
      while let self = self, !Task.isCancelled {
        if self.isRecording {
          await self.pollForEvents()
        }

        do {
          try await Task.sleep(nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))
        } catch {
          self.logger.info("Event polling task cancelled")
          break
        }
      }
      self?.logger.info("Event polling stopped")
    }
  }

  private func stopEventPolling() {
    logger.info("Stopping event polling")
    pollingTask?.cancel()
    pollingTask = nil
  }

  private func pollForEvents() async {
    guard let session = session else {
      return
    }

    do {
      // First check if recorder is still installed (WSL browsers might reload/navigate)
      let checkScript = "return window.swiftAppiumRecorder && window.swiftAppiumRecorder.isInstalled();"
      let isInstalled = try await session.executeScript(script: checkScript, args: [])
      
      if let installed = isInstalled as? Bool, !installed {
        logger.warning("JavaScript recorder not found - attempting re-injection")
        if isWSL {
          logger.info("WSL: Browser may have navigated or reloaded, re-injecting recorder")
        }
        try await injectRecorderScript()
        return
      }

      let script = "return window.swiftAppiumRecorder.getEvents();"
      let result = try await session.executeScript(script: script, args: [])

      if let eventsArray = result as? [[String: Any]], !eventsArray.isEmpty {
        logger.info("Polling found \(eventsArray.count) new events")

        let clearScript = "return window.swiftAppiumRecorder.clearEvents();"
        _ = try await session.executeScript(script: clearScript, args: [])

        for eventDict in eventsArray {
          // Manual decoding to handle potential type mismatches
          let type = eventDict["type"] as? String ?? "unknown"
          let xpath = eventDict["xpath"] as? String ?? ""
          let value = eventDict["value"] as? String
          let timestamp =
            eventDict["timestamp"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)

          let event = RecordedEvent(type: type, xpath: xpath, value: value, timestamp: timestamp)
          appendEvent(event)
        }
      } else if isWSL {
        // In WSL, occasionally check if events are being captured at all
        let eventCountScript = "return window.swiftAppiumRecorder ? window.swiftAppiumRecorder.getEventCount() : -1;"
        let eventCount = try await session.executeScript(script: eventCountScript, args: [])
        
        if let count = eventCount as? Int, count == 0 {
          // No events captured - this might indicate an issue
          logger.debug("WSL: No events captured yet. Recorder status: installed")
        }
      }
    } catch {
      logger.error("Failed to poll for events: \(error)")
      
      if isWSL {
        logger.warning("WSL: Event polling failed - this might be due to:")
        logger.warning("1. Browser security restrictions")
        logger.warning("2. Network timing issues")
        logger.warning("3. JavaScript execution context changes")
        
        // Try to re-establish connection
        do {
          logger.info("WSL: Attempting to re-inject recorder script")
          try await injectRecorderScript()
        } catch {
          logger.error("WSL: Failed to re-inject recorder script: \(error)")
        }
      }
    }
  }

  private func getAllEvents() -> [RecordedEvent] {
    return getEvents()
  }

  private func getEventCount() -> Int {
    return getEvents().count
  }

  private func clearEvents() {
    setEvents([])
    logger.info("All recorded events cleared")
  }

  private func getEvents() -> [RecordedEvent] {
    return eventsQueue.sync {
      return events
    }
  }

  private func setEvents(_ newEvents: [RecordedEvent]) {
    eventsQueue.sync {
      events = newEvents
    }
  }

  private func appendEvent(_ event: RecordedEvent) {
    eventsQueue.sync {
      events.append(event)
    }
  }

  // MARK: - Event Playback
  private func replayEvents(session: AppiumSession, events: [RecordedEvent]) async {
    logger.info("Starting playback of \(events.count) events")
    
    // Sort events by timestamp to maintain proper execution order
    let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
    
    for (index, event) in sortedEvents.enumerated() {
      do {
        logger.debug("Replaying event \(index + 1)/\(sortedEvents.count): \(event.type) on \(event.xpath)")
        
        switch event.type {
        case "click", "button_click", "link_click", "checkbox_click", "radio_click":
          try await replayClickEvent(session: session, event: event)
          
        case "input", "textarea_input", "text_input", "password_input":
          try await replayInputEvent(session: session, event: event)
          
        case "select_change":
          try await replaySelectEvent(session: session, event: event)
          
        default:
          logger.warning("Unsupported event type for playback: \(event.type)")
        }
        
        // Add delay between events to simulate realistic user interaction
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
      } catch {
        logger.error("Failed to replay event \(index + 1): \(error)")
        // Continue with next event rather than stopping playback
      }
    }
    
    logger.info("Playback completed for \(sortedEvents.count) events")
  }
  
  private func replayClickEvent(session: AppiumSession, event: RecordedEvent) async throws {
    let script = """
      var element = document.evaluate(arguments[0], document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
      if (element) {
        element.click();
        return true;
      } else {
        throw new Error('Element not found: ' + arguments[0]);
      }
    """
    
    _ = try await session.executeScript(script: script, args: [event.xpath])
  }
  
  private func replayInputEvent(session: AppiumSession, event: RecordedEvent) async throws {
    let script = """
      var element = document.evaluate(arguments[0], document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
      if (element) {
        element.focus();
        element.value = arguments[1] || '';
        
        // Trigger input events to simulate real user interaction
        var inputEvent = new Event('input', { bubbles: true });
        element.dispatchEvent(inputEvent);
        
        var changeEvent = new Event('change', { bubbles: true });
        element.dispatchEvent(changeEvent);
        
        return true;
      } else {
        throw new Error('Element not found: ' + arguments[0]);
      }
    """
    
    _ = try await session.executeScript(script: script, args: [event.xpath, event.value ?? ""])
  }
  
  private func replaySelectEvent(session: AppiumSession, event: RecordedEvent) async throws {
    let script = """
      var element = document.evaluate(arguments[0], document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
      if (element && element.tagName.toLowerCase() === 'select') {
        // Try to find option by text content first
        var options = element.options;
        for (var i = 0; i < options.length; i++) {
          if (options[i].text === arguments[1] || options[i].value === arguments[1]) {
            element.selectedIndex = i;
            break;
          }
        }
        
        // Trigger change event
        var changeEvent = new Event('change', { bubbles: true });
        element.dispatchEvent(changeEvent);
        
        return true;
      } else {
        throw new Error('Select element not found: ' + arguments[0]);
      }
    """
    
    _ = try await session.executeScript(script: script, args: [event.xpath, event.value ?? ""])
  }

  // MARK: - Vapor Configuration
  private func configureVaporRoutes() {
    logger.info("Configuring Vapor routes for web server")

    guard let app = app else {
      logger.error("Vapor app not initialized")
      return
    }

    // Configure CORS for local development
    let corsConfiguration = CORSMiddleware.Configuration(
      allowedOrigin: .all,
      allowedMethods: [.GET, .POST, .OPTIONS],
      allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

    // Main web UI route
    app.get { [weak self] req async throws -> Response in
      print("🔍 Main route called!")

      guard let self = self else {
        print("❌ WebRecorder instance not available")
        throw Abort(.internalServerError, reason: "WebRecorder instance not available")
      }

      print("✅ Generating HTML...")
      let html = self.generateWebUIHTML()
      print("✅ HTML generated, length: \(html.count)")

      return Response(
        status: .ok,
        headers: HTTPHeaders([("Content-Type", "text/html")]),
        body: .init(string: html)
      )
    }

    // Events JSON API endpoint - optimized for performance
    app.get("events.json") { [weak self] req async throws -> Response in
      let startTime = Date()

      guard let self = self else {
        throw Abort(.internalServerError, reason: "WebRecorder instance not available")
      }

      let events = self.getAllEvents()
      let jsonData = try JSONEncoder().encode(events)

      let processingTime = Date().timeIntervalSince(startTime)
      self.logger.debug("Events API processed \(events.count) events in \(processingTime)s")

      return Response(
        status: .ok,
        headers: HTTPHeaders([
          ("Content-Type", "application/json"),
          ("Cache-Control", "no-cache"),
        ]),
        body: .init(data: jsonData)
      )
    }

    // Health check endpoint with WSL diagnostics
    app.get("health") { [weak self] req async throws -> Response in
      guard let self = self else {
        throw Abort(.serviceUnavailable, reason: "WebRecorder not available")
      }

      var healthData: [String: Any] = [
        "status": "healthy",
        "isRecording": self.isRecording,
        "eventCount": self.getEventCount(),
        "hasSession": self.session != nil,
        "timestamp": Date().timeIntervalSince1970,
        "isWSL": self.isWSL
      ]
      
      // Add WSL-specific diagnostics
      if self.isWSL {
        healthData["wslDiagnostics"] = [
          "environment": "WSL detected",
          "networkBinding": "0.0.0.0 (WSL mode)",
          "browserLaunch": "Multi-method fallback enabled"
        ]
      }

      let jsonData = try JSONSerialization.data(withJSONObject: healthData)

      return Response(
        status: .ok,
        headers: HTTPHeaders([("Content-Type", "application/json")]),
        body: .init(data: jsonData)
      )
    }
    
    // WSL-specific diagnostics endpoint
    if isWSL {
      app.get("wsl-diagnostics") { [weak self] req async throws -> Response in
        guard let self = self else {
          throw Abort(.internalServerError, reason: "WebRecorder instance not available")
        }
        
        var diagnostics: [String: Any] = [
          "wslDetected": true,
          "timestamp": Date().timeIntervalSince1970
        ]
        
        // Test JavaScript recorder status
        if let session = self.session {
          do {
            let testScript = """
              return {
                recorderInstalled: !!(window.swiftAppiumRecorder),
                eventCount: window.swiftAppiumRecorder ? window.swiftAppiumRecorder.getEventCount() : -1,
                eventsArray: window.swiftAppiumEvents ? window.swiftAppiumEvents.length : -1,
                userAgent: navigator.userAgent,
                location: window.location.href
              };
            """
            
            let result = try await session.executeScript(script: testScript, args: [])
            diagnostics["browserStatus"] = result
            
          } catch {
            diagnostics["browserError"] = error.localizedDescription
          }
        } else {
          diagnostics["sessionStatus"] = "No active session"
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: diagnostics)
        
        return Response(
          status: .ok,
          headers: HTTPHeaders([("Content-Type", "application/json")]),
          body: .init(data: jsonData)
        )
      }
    }

    // Clear events endpoint
    app.post("clear") { [weak self] req async throws -> Response in
      guard let self = self else {
        throw Abort(.internalServerError, reason: "WebRecorder instance not available")
      }

      let eventCount = self.getEventCount()
      self.clearEvents()

      let responseData: [String: Any] = [
        "success": true,
        "message": "Cleared \(eventCount) events",
        "clearedCount": eventCount,
      ]

      let jsonData = try JSONSerialization.data(withJSONObject: responseData)

      return Response(
        status: .ok,
        headers: HTTPHeaders([("Content-Type", "application/json")]),
        body: .init(data: jsonData)
      )
    }

    // Export Swift code endpoint
    app.get("export.swift") { [weak self] req async throws -> Response in
      guard let self = self else {
        throw Abort(.internalServerError, reason: "WebRecorder instance not available")
      }

      let swiftCode = self.generateSwiftCode()

      return Response(
        status: .ok,
        headers: HTTPHeaders([
          ("Content-Type", "text/plain"),
          ("Content-Disposition", "attachment; filename=SwiftAppiumTest.swift"),
        ]),
        body: .init(string: swiftCode)
      )
    }

    // Session management endpoints
    app.get("session", "info") { [weak self] req async throws -> Response in
      guard let self = self else {
        throw Abort(.internalServerError, reason: "WebRecorder instance not available")
      }

      let sessionData: [String: Any] = [
        "hasSession": self.session != nil,
        "sessionId": self.session?.id ?? "",
        "platform": self.session?.platform ?? "",
        "browserName": self.session?.browserName ?? "",
      ]

      let jsonData = try JSONSerialization.data(withJSONObject: sessionData)

      return Response(
        status: .ok,
        headers: HTTPHeaders([("Content-Type", "application/json")]),
        body: .init(data: jsonData)
      )
    }

    // Connect to existing session endpoint
    app.post("session", "connect") { [weak self] req async throws -> Response in
      guard let self = self else {
        throw Abort(.internalServerError, reason: "WebRecorder instance not available")
      }

      struct ConnectRequest: Codable {
        let sessionId: String
      }

      let connectRequest = try req.content.decode(ConnectRequest.self)
      let sessionId = connectRequest.sessionId.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !sessionId.isEmpty else {
        let errorResponse = ["success": false, "error": "Session ID cannot be empty"]
        let jsonData = try JSONSerialization.data(withJSONObject: errorResponse)
        return Response(
          status: .badRequest,
          headers: HTTPHeaders([("Content-Type", "application/json")]),
          body: .init(data: jsonData)
        )
      }

      do {
        try await self.connectToSession(sessionId: sessionId)

        let responseData: [String: Any] = [
          "success": true,
          "message": "Successfully connected to session \(sessionId)",
          "sessionId": sessionId,
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: responseData)

        return Response(
          status: .ok,
          headers: HTTPHeaders([("Content-Type", "application/json")]),
          body: .init(data: jsonData)
        )
      } catch {
        self.logger.error("Failed to connect to session: \(error)")

        let errorResponse = [
          "success": false, "error": "Failed to connect to session: \(error.localizedDescription)",
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: errorResponse)

        return Response(
          status: .ok,  // Return 200 but with error in response
          headers: HTTPHeaders([("Content-Type", "application/json")]),
          body: .init(data: jsonData)
        )
      }
    }

    // Discover available sessions endpoint
    app.get("sessions", "discover") { [weak self] req async throws -> Response in
      guard let self = self else {
        throw Abort(.internalServerError, reason: "WebRecorder instance not available")
      }

      do {
        let sessions = try await self.discoverAvailableSessions()

        let responseData: [String: Any] = [
          "success": true,
          "sessions": sessions.map { ["sessionId": $0] },
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: responseData)

        return Response(
          status: .ok,
          headers: HTTPHeaders([("Content-Type", "application/json")]),
          body: .init(data: jsonData)
        )
      } catch {
        self.logger.error("Failed to discover sessions: \(error)")

        let errorResponse = [
          "success": false, "error": "Failed to discover sessions: \(error.localizedDescription)",
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: errorResponse)

        return Response(
          status: .ok,
          headers: HTTPHeaders([("Content-Type", "application/json")]),
          body: .init(data: jsonData)
        )
      }
    }

    // Recording toggle endpoint
    app.post("recording", "toggle") { [weak self] req async throws -> Response in
      guard let self = self else {
        throw Abort(.internalServerError, reason: "WebRecorder instance not available")
      }

      self.isRecording.toggle()

      let responseData: [String: Any] = [
        "success": true,
        "isRecording": self.isRecording,
        "message": self.isRecording ? "Recording started" : "Recording stopped",
      ]

      let jsonData = try JSONSerialization.data(withJSONObject: responseData)

      return Response(
        status: .ok,
        headers: HTTPHeaders([("Content-Type", "application/json")]),
        body: .init(data: jsonData)
      )
    }

    // Playback endpoint to replay recorded events
    app.post("playback") { [weak self] req async throws -> Response in
      guard let self = self else {
        throw Abort(.internalServerError, reason: "WebRecorder instance not available")
      }
      
      guard let session = self.session else {
        let errorData: [String: Any] = [
          "success": false,
          "error": "No active session. Please connect to an Appium session first."
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: errorData)
        return Response(
          status: .badRequest,
          headers: HTTPHeaders([("Content-Type", "application/json")]),
          body: .init(data: jsonData)
        )
      }
      
      let events = self.getAllEvents()
      guard !events.isEmpty else {
        let errorData: [String: Any] = [
          "success": false,
          "error": "No events to replay. Record some interactions first."
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: errorData)
        return Response(
          status: .badRequest,
          headers: HTTPHeaders([("Content-Type", "application/json")]),
          body: .init(data: jsonData)
        )
      }
      
      // Start playback in background
      Task { [weak self] in
        await self?.replayEvents(session: session, events: events)
      }
      
      let responseData: [String: Any] = [
        "success": true,
        "message": "Playback started for \(events.count) events",
        "eventCount": events.count
      ]
      
      let jsonData = try JSONSerialization.data(withJSONObject: responseData)
      return Response(
        status: .ok,
        headers: HTTPHeaders([("Content-Type", "application/json")]),
        body: .init(data: jsonData)
      )
    }

    logger.info("Vapor routes configured successfully")
    print("✅ Vapor web server routes configured")
  }

  private func generateWebUIHTML() -> String {
    let eventCount = getEventCount()
    let recordingStatus = isRecording ? "Recording" : "Stopped"
    let sessionStatus = session != nil ? "Connected" : "No Session"

    return """
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>SwiftAppium Web Recorder</title>
          <style>
              * {
                  margin: 0;
                  padding: 0;
                  box-sizing: border-box;
              }
              
              body {
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
                  line-height: 1.6;
                  color: #333;
                  background-color: #f5f5f5;
                  margin: 0;
                  padding: 0;
                  height: 100vh;
                  overflow: hidden;
              }
              
              .main-container {
                  display: flex;
                  flex-direction: column;
                  height: 100vh;
              }
              
              .header {
                  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                  color: white;
                  padding: 12px 20px;
                  display: flex;
                  justify-content: space-between;
                  align-items: center;
                  flex-shrink: 0;
              }
              
              .header h1 {
                  font-size: 1.5em;
                  margin: 0;
                  font-weight: 300;
              }
              
              .header-status {
                  display: flex;
                  gap: 20px;
                  align-items: center;
                  font-size: 0.9em;
              }
              
              .status-item {
                  display: flex;
                  align-items: center;
                  gap: 5px;
              }
              
              .status-dot {
                  width: 8px;
                  height: 8px;
                  border-radius: 50%;
                  background: #28a745;
              }
              
              .status-dot.recording {
                  background: #dc3545;
                  animation: pulse 1s infinite;
              }
              
              .status-dot.stopped {
                  background: #6c757d;
              }
              
              .status-dot.disconnected {
                  background: #ffc107;
              }
              
              @keyframes pulse {
                  0% { opacity: 1; }
                  50% { opacity: 0.5; }
                  100% { opacity: 1; }
              }
              
              .content-area {
                  display: flex;
                  flex: 1;
                  overflow: hidden;
              }
              
              .controls-panel {
                  flex: 1;
                  display: flex;
                  flex-direction: column;
                  border-right: 2px solid #e9ecef;
                  background: white;
              }
              
              .controls-header {
                  background: #f8f9fa;
                  padding: 15px;
                  border-bottom: 1px solid #e9ecef;
              }
              
              .controls-header h2 {
                  font-size: 1.2em;
                  margin: 0;
                  color: #495057;
              }
              
              .controls-content {
                  padding: 20px;
                  flex: 1;
                  overflow-y: auto;
              }
              
              .control-group {
                  margin-bottom: 25px;
              }
              
              .control-group h3 {
                  font-size: 1em;
                  margin-bottom: 10px;
                  color: #495057;
                  border-bottom: 1px solid #e9ecef;
                  padding-bottom: 5px;
              }
              
              .btn {
                  background: #007bff;
                  color: white;
                  border: none;
                  padding: 10px 20px;
                  border-radius: 4px;
                  cursor: pointer;
                  font-size: 14px;
                  margin: 5px;
                  transition: background-color 0.2s;
              }
              
              .btn:hover {
                  background: #0056b3;
              }
              
              .btn:disabled {
                  background: #6c757d;
                  cursor: not-allowed;
              }
              
              .btn.success {
                  background: #28a745;
              }
              
              .btn.success:hover {
                  background: #1e7e34;
              }
              
              .btn.danger {
                  background: #dc3545;
              }
              
              .btn.danger:hover {
                  background: #c82333;
              }
              
              .btn.warning {
                  background: #ffc107;
                  color: #212529;
              }
              
              .btn.warning:hover {
                  background: #e0a800;
              }
              
              .events-panel {
                  flex: 2;
                  display: flex;
                  flex-direction: column;
                  background: white;
              }
              
              .events-header {
                  background: #f8f9fa;
                  padding: 15px;
                  border-bottom: 1px solid #e9ecef;
                  display: flex;
                  justify-content: space-between;
                  align-items: center;
              }
              
              .events-header h2 {
                  font-size: 1.2em;
                  margin: 0;
                  color: #495057;
              }
              
              .events-controls {
                  display: flex;
                  gap: 8px;
              }
              
              .events-filter {
                  padding: 6px 10px;
                  border: 1px solid #ddd;
                  border-radius: 4px;
                  font-size: 12px;
                  width: 150px;
              }
              
              .events-container {
                  flex: 1;
                  overflow-y: auto;
                  padding: 0;
              }
              
              .events-table {
                  width: 100%;
                  border-collapse: collapse;
                  font-size: 13px;
              }
              
              .events-table th {
                  background: #f8f9fa;
                  padding: 10px 8px;
                  text-align: left;
                  border-bottom: 2px solid #e9ecef;
                  font-weight: 600;
                  color: #495057;
                  position: sticky;
                  top: 0;
                  z-index: 10;
              }
              
              .events-table td {
                  padding: 8px;
                  border-bottom: 1px solid #f1f3f4;
                  vertical-align: top;
              }
              
              .events-table tr:hover {
                  background: #f8f9fa;
              }
              
              .event-type {
                  display: inline-block;
                  padding: 2px 6px;
                  border-radius: 3px;
                  font-size: 11px;
                  font-weight: 500;
                  text-transform: uppercase;
              }
              
              .event-type.click { background: #e3f2fd; color: #1976d2; }
              .event-type.input { background: #e8f5e8; color: #388e3c; }
              .event-type.change { background: #fff3e0; color: #f57c00; }
              .event-type.keydown { background: #f3e5f5; color: #7b1fa2; }
              .event-type.submit { background: #ffebee; color: #d32f2f; }
              .event-type.focus { background: #e0f2f1; color: #00796b; }
              
              .xpath-cell {
                  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
                  font-size: 11px;
                  max-width: 200px;
                  word-break: break-all;
                  color: #6f42c1;
              }
              
              .value-cell {
                  max-width: 150px;
                  word-break: break-word;
                  color: #495057;
              }
              
              .timestamp-cell {
                  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
                  font-size: 11px;
                  color: #6c757d;
                  white-space: nowrap;
              }
              
              .no-events {
                  text-align: center;
                  padding: 40px;
                  color: #6c757d;
              }
              

              
              @media (max-width: 768px) {
                  .content-area {
                      flex-direction: column;
                  }
                  
                  .controls-panel {
                      flex: 1;
                      border-right: none;
                      border-bottom: 2px solid #e9ecef;
                  }
                  
                  .events-panel {
                      flex: 1;
                  }
                  
                  .header {
                      flex-direction: column;
                      gap: 10px;
                  }
                  
                  .header-status {
                      justify-content: center;
                  }
              }
          </style>
      </head>
      <body>
          <div class="main-container">
              <div class="header">
                  <h1>🎬 SwiftAppium Web Recorder</h1>
                  <div class="header-status">
                      <div class="status-item">
                          <div class="status-dot \(sessionStatus == "Connected" ? "" : "disconnected")" id="session-dot"></div>
                          <span id="session-status">\(sessionStatus)</span>
                      </div>
                      <div class="status-item">
                          <div class="status-dot \(recordingStatus == "Recording" ? "recording" : "stopped")" id="recording-dot"></div>
                          <span id="recording-status">\(recordingStatus)</span>
                      </div>
                      <div class="status-item">
                          <span id="event-count">\(eventCount) events</span>
                      </div>
                  </div>
              </div>
              
              <div class="content-area">
                  <div class="controls-panel">
                      <div class="controls-header">
                          <h2>🎛️ Controls</h2>
                      </div>
                      
                      <div class="controls-content">

                          
                          <div class="control-group">
                              <h3>Events</h3>
                              <button class="btn primary" onclick="playbackEvents()">▶️ Play Events</button>
                              <button class="btn warning" onclick="clearEvents()">🗑️ Clear Events</button>
                              <button class="btn" onclick="exportSwiftCode()">💾 Export Swift Code</button>
                          </div>
                          
                          \(isWSL ? """
                          <div class="control-group">
                              <h3>🐧 WSL Diagnostics</h3>
                              <button class="btn" onclick="runWSLDiagnostics()">🔍 Run Diagnostics</button>
                              <button class="btn" onclick="testRecording()">🧪 Test Recording</button>
                              <div id="wsl-diagnostics" style="margin-top: 10px; font-size: 12px; color: #666;"></div>
                          </div>
                          """ : "")
                          

                          

                      </div>
                  </div>
                  
                  <div class="events-panel">
                      <div class="events-header">
                          <h2>📋 Recorded Events</h2>
                          <div class="events-controls">
                              <input type="text" class="events-filter" id="events-filter" placeholder="Filter events..." onkeyup="filterEvents()">
                              <button class="btn" onclick="exportSwiftCode()">💾 Export</button>
                          </div>
                      </div>
                      
                      <div class="events-container">
                          <table class="events-table" id="events-table">
                              <thead>
                                  <tr>
                                      <th style="width: 80px;">Type</th>
                                      <th style="width: 200px;">XPath</th>
                                      <th style="width: 150px;">Value</th>
                                      <th style="width: 100px;">Time</th>
                                  </tr>
                              </thead>
                              <tbody id="events-body">
                                  <tr>
                                      <td colspan="4" class="no-events">
                                          No events recorded yet. Start recording and interact with the browser to capture events.
                                      </td>
                                  </tr>
                              </tbody>
                          </table>
                      </div>
                  </div>
              </div>
          </div>
          
          <script>
              let isRecording = \(recordingStatus == "Recording" ? "true" : "false");
              let hasSession = \(sessionStatus == "Connected" ? "true" : "false");
              let allEvents = [];
              let filteredEvents = [];
              
              // Update events display
              async function updateEvents() {
                  try {
                      const response = await fetch("/events.json");
                      if (!response.ok) throw new Error("Failed to fetch events");
                      
                      const events = await response.json();
                      allEvents = events;
                      applyEventFilter();
                      
                      // Update event count in header
                      document.getElementById("event-count").textContent = events.length + " events";
                      
                  } catch (error) {
                      console.error("Failed to update events:", error);
                  }
              }
              
              // Apply current filter to events
              function applyEventFilter() {
                  const filterText = document.getElementById("events-filter").value.toLowerCase();
                  
                  if (!filterText) {
                      filteredEvents = allEvents;
                  } else {
                      filteredEvents = allEvents.filter(event => 
                          event.type.toLowerCase().includes(filterText) ||
                          event.xpath.toLowerCase().includes(filterText) ||
                          (event.value && event.value.toLowerCase().includes(filterText))
                      );
                  }
                  
                  renderEventsTable();
              }
              
              // Render events table
              function renderEventsTable() {
                  const tbody = document.getElementById("events-body");
                  
                  if (filteredEvents.length === 0) {
                      tbody.innerHTML = "<tr><td colspan=\\"4\\" class=\\"no-events\\">No events match the current filter.</td></tr>";
                      return;
                  }
                  
                  tbody.innerHTML = "";
                  
                  filteredEvents.forEach(event => {
                      const row = tbody.insertRow();
                      
                      // Type cell with colored badge
                      const typeCell = row.insertCell();
                      const eventType = event.type.replace("_", " ");
                      const typeClass = event.type.split("_")[0]; // Get base type for styling
                      typeCell.innerHTML = `<span class="event-type \\${typeClass}">\\${eventType}</span>`;
                      
                      // XPath cell
                      const xpathCell = row.insertCell();
                      xpathCell.className = "xpath-cell";
                      xpathCell.textContent = event.xpath;
                      xpathCell.title = event.xpath; // Full xpath on hover
                      
                      // Value cell
                      const valueCell = row.insertCell();
                      valueCell.className = "value-cell";
                      valueCell.textContent = event.value || "";
                      if (event.value) {
                          valueCell.title = event.value; // Full value on hover
                      }
                      
                      // Timestamp cell
                      const timestampCell = row.insertCell();
                      timestampCell.className = "timestamp-cell";
                      const timestamp = new Date(event.timestamp);
                      const timeString = timestamp.toLocaleTimeString("en-US", {
                          hour12: false,
                          hour: "2-digit",
                          minute: "2-digit",
                          second: "2-digit",
                          fractionalSecondDigits: 3
                      });
                      timestampCell.textContent = timeString;
                  });
              }
              
              // Filter events as user types
              function filterEvents() {
                  applyEventFilter();
              }
              
              // Update session status
              async function updateSessionStatus() {
                  try {
                      const response = await fetch("/session/info");
                      const data = await response.json();
                      
                      const sessionDot = document.getElementById("session-dot");
                      const sessionStatus = document.getElementById("session-status");
                      
                      if (data.hasSession) {
                          sessionDot.className = "status-dot";
                          sessionStatus.textContent = "Connected";
                          hasSession = true;
                      } else {
                          sessionDot.className = "status-dot disconnected";
                          sessionStatus.textContent = "No Session";
                          hasSession = false;
                      }
                  } catch (error) {
                      console.error("Failed to update session status:", error);
                  }
              }
              
              // Recording is automatic - no manual controls needed
              
              // Clear events
              async function clearEvents() {
                  if (!confirm("Are you sure you want to clear all recorded events?")) {
                      return;
                  }
                  
                  try {
                      const response = await fetch("/clear", {
                          method: "POST",
                          headers: { "Content-Type": "application/json" }
                      });
                      
                      const result = await response.json();
                      if (result.success) {
                          allEvents = [];
                          filteredEvents = [];
                          renderEventsTable();
                          document.getElementById("event-count").textContent = "0 events";
                      } else {
                          alert("Failed to clear events: " + (result.error || "Unknown error"));
                      }
                  } catch (error) {
                      alert("Failed to clear events: " + error.message);
                  }
              }
              
              // Export Swift code
              function exportSwiftCode() {
                  if (allEvents.length === 0) {
                      alert("No events to export. Record some interactions first.");
                      return;
                  }
                  
                  window.location.href = "/export.swift";
              }
              
              // Playback recorded events
              async function playbackEvents() {
                  if (allEvents.length === 0) {
                      alert("No events to playback. Record some interactions first.");
                      return;
                  }
                  
                  try {
                      const response = await fetch("/playback", {
                          method: "POST",
                          headers: { "Content-Type": "application/json" }
                      });
                      
                      const result = await response.json();
                      
                      if (result.success) {
                          alert("Playback started! " + result.message);
                      } else {
                          alert("Playback failed: " + result.error);
                      }
                  } catch (error) {
                      alert("Failed to start playback: " + error.message);
                  }
              }
              
              // Session management is now automatic - no manual functions needed
              
              \(isWSL ? """
              // WSL-specific diagnostic functions
              async function runWSLDiagnostics() {
                  const diagnosticsDiv = document.getElementById("wsl-diagnostics");
                  diagnosticsDiv.innerHTML = "🔍 Running WSL diagnostics...";
                  
                  try {
                      const response = await fetch("/wsl-diagnostics");
                      const data = await response.json();
                      
                      let html = "<strong>WSL Environment Detected</strong><br>";
                      
                      if (data.browserStatus) {
                          const status = data.browserStatus;
                          html += `📊 Recorder Status: ${status.recorderInstalled ? '✅ Installed' : '❌ Not Found'}<br>`;
                          html += `📈 Event Count: ${status.eventCount}<br>`;
                          html += `🌐 Location: ${status.location}<br>`;
                          html += `🖥️ User Agent: ${status.userAgent.substring(0, 50)}...<br>`;
                      }
                      
                      if (data.browserError) {
                          html += `❌ Browser Error: ${data.browserError}<br>`;
                      }
                      
                      if (data.sessionStatus) {
                          html += `⚠️ Session: ${data.sessionStatus}<br>`;
                      }
                      
                      diagnosticsDiv.innerHTML = html;
                      
                  } catch (error) {
                      diagnosticsDiv.innerHTML = `❌ Diagnostics failed: ${error.message}`;
                  }
              }
              
              async function testRecording() {
                  const diagnosticsDiv = document.getElementById("wsl-diagnostics");
                  diagnosticsDiv.innerHTML = "🧪 Testing recording functionality...";
                  
                  try {
                      const initialCount = allEvents.length;
                      
                      setTimeout(async () => {
                          await updateEvents();
                          const newCount = allEvents.length;
                          
                          if (newCount > initialCount) {
                              diagnosticsDiv.innerHTML = "✅ Recording is working! New events detected.";
                          } else {
                              diagnosticsDiv.innerHTML = `
                                  ⚠️ No new events detected. Possible issues:<br>
                                  • JavaScript recorder not properly injected<br>
                                  • Browser security policies blocking event capture<br>
                                  • Network issues between WSL and browser<br>
                                  <br>
                                  💡 Try: Open browser console (F12) and check for errors
                              `;
                          }
                      }, 2000);
                      
                      diagnosticsDiv.innerHTML = "🧪 Test in progress... Please wait 2 seconds...";
                      
                  } catch (error) {
                      diagnosticsDiv.innerHTML = `❌ Test failed: ${error.message}`;
                  }
              }
              """ : "")
              
              // Initialize and start periodic updates
              function initialize() {
                  updateSessionStatus();
                  updateEvents();
                  
                  // Set up periodic updates
                  setInterval(updateEvents, 1000);           // Update events every second
                  setInterval(updateSessionStatus, 5000);    // Update session every 5 seconds
              }
              
              // Handle Enter key in session ID input
              document.addEventListener("DOMContentLoaded", function() {
                  initialize();
                  
                  // Add Enter key support for session ID input
                  const sessionIdInput = document.getElementById("session-id-input");
                  if (sessionIdInput) {
                      sessionIdInput.addEventListener("keypress", function(e) {
                          if (e.key === "Enter") {
                              connectToSession();
                          }
                      });
                  }
              });
              
              // Handle page visibility changes to pause/resume updates
              document.addEventListener("visibilitychange", function() {
                  if (!document.hidden) {
                      // Page is visible, resume updates
                      updateEvents();
                  }
              });
          </script>
      </body>
      </html>
      """
  }

  // MARK: - Code Generation
  private func generateSwiftCode() -> String {
    logger.info("Generating Swift code from recorded events")

    let events = getAllEvents()
    guard !events.isEmpty else {
      return """
        // No events recorded yet.
        // Interact with the browser to record actions.

        import SwiftAppium
        import Testing
        import Logging

        @Test("Recorded browser interactions")
        func recordedBrowserTest() async throws {
            // No events to replay
        }
        """
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let timestamp = dateFormatter.string(from: Date())

    var swiftCode = """
      // Generated by SwiftAppium Web Recorder on \(timestamp)
      import SwiftAppium
      import Testing
      import Logging

      @Test("Recorded browser interactions")
      func recordedBrowserTest() async throws {
          // Create logger for test execution
          let testLogger = Logger(label: "RecordedTest")
          
          // Set up session (replace with your actual session configuration)
          let session = try await Session(
              host: "127.0.0.1",
              port: 4723,
              driver: Driver.Chromium()
          )
          
          // Recorded interactions:
      """

    // Sort events by timestamp to maintain execution order
    let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }

    for event in sortedEvents {
      let escapedXPath = event.xpath
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")

      switch event.type {
      case "click":
        swiftCode += """

          // Click on element: \(escapedXPath)
          try await session.click(
              Element(.xpath, Selector("\(escapedXPath)")),
              testLogger
          )
          """

      case "input":
        let escapedValue = (event.value ?? "")
          .replacingOccurrences(of: "\\", with: "\\\\")
          .replacingOccurrences(of: "\"", with: "\\\"")
        swiftCode += """

          // Type text into element: \(escapedXPath)
          try await session.type(
              Element(.xpath, Selector("\(escapedXPath)")),
              text: "\(escapedValue)",
              logger: testLogger
          )
          """

      default:
        swiftCode += """

          // Unsupported event type: \(event.type)
          """
      }
    }

    swiftCode += """

      }
      """

    return swiftCode
  }

  // MARK: - Browser Navigation & Interaction
  private func takeScreenshot(session: AppiumSession) async throws -> Data {
    logger.debug("Taking screenshot of browser session")

    let script = "return window.navigator.userAgent;"
    _ = try await session.executeScript(script: script, args: [])

    // For now, return empty data - actual screenshot implementation would go here
    return Data()
  }

  private func navigateToURL(session: AppiumSession, url: String) async throws {
    logger.info("Navigating browser to URL: \(url)")

    let script = "window.location.href = arguments[0];"
    _ = try await session.executeScript(script: script, args: [url])

    // Wait for navigation to complete
    try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
  }

  private func refreshBrowser(session: AppiumSession) async throws {
    logger.info("Refreshing browser")

    let script = "window.location.reload();"
    _ = try await session.executeScript(script: script, args: [])

    // Wait for refresh to complete
    try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
  }

  private func getCurrentURL(session: AppiumSession) async throws -> String {
    logger.debug("Getting current browser URL")

    let script = "return window.location.href;"
    let result = try await session.executeScript(script: script, args: [])

    return result as? String ?? ""
  }

  // MARK: - Lifecycle
  private func performAsyncCleanup() async {
    logger.info("Performing cleanup...")

    // Stop event polling
    pollingTask?.cancel()
    pollingTask = nil

    // Clean up Appium session
    if let session = session {
      do {
        try await session.deleteSession()
      } catch {
        logger.warning("Failed to delete Appium session: \(error)")
      }
    }

    // Shutdown Vapor server properly
    if let app = app {
      do {
        try await app.asyncShutdown()
        logger.info("Vapor server shut down successfully")
      } catch {
        logger.warning("Failed to shutdown Vapor server gracefully: \(error)")
      }
    }

    // Cancel server task
    serverTask?.cancel()

    // Close HTTP client
    do {
      try await httpClient.shutdown()
      logger.info("HTTP client shut down successfully")
    } catch {
      logger.warning("Failed to shutdown HTTP client: \(error)")
    }

    isRunning = false
    logger.info("Cleanup complete")
  }

  // Keep the old performCleanup for deinit (synchronous context)
  private func performCleanup() {
    logger.info("Performing synchronous cleanup...")

    // Stop event polling
    pollingTask?.cancel()
    pollingTask = nil

    // Cancel server task
    serverTask?.cancel()

    // Close HTTP client synchronously
    try? httpClient.shutdown().wait()

    isRunning = false
    logger.info("Synchronous cleanup complete")
  }
}
