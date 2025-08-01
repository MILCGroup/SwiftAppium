//
//  main.swift
//  SwiftAppium
//  https://github.com/milcgroup/SwiftAppium
//  See LICENSE for information
//

import ArgumentParser
import Foundation

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

// Global references for signal handling
private nonisolated(unsafe) var globalRecorder: WebRecorder?

struct SwiftAppiumCLI: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swiftappium",
    abstract:
      "SwiftAppium Web Recorder - Capture browser interactions and generate Swift test code",
    version: "1.0.0"
  )

  @Option(name: .long, help: "Port for the web interface (default: 8080)")
  var port: Int = 8080

  @Option(name: .long, help: "Appium server URL (default: http://localhost:4723)")
  var appiumUrl: String = "http://localhost:4723"

  func validate() throws {
    // Validate port range
    guard port > 0 && port <= 65535 else {
      throw ValidationError("Port must be between 1 and 65535")
    }

    // Validate Appium URL format
    guard let url = URL(string: appiumUrl),
      url.scheme != nil,
      url.host != nil
    else {
      throw ValidationError("Invalid Appium server URL: \(appiumUrl)")
    }
  }

  func run() throws {
    // Check if port is available
    if !isPortAvailable(port: port) {
      print(
        "ERROR: Port \(port) is in use. Please free the port or specify a different one using --port <number>."
      )
      throw ExitCode.failure
    }

    // Validate Appium server URL
    guard let appiumURL = URL(string: appiumUrl) else {
      print("ERROR: Invalid Appium server URL: \(appiumUrl)")
      throw ExitCode.failure
    }

    print("Starting SwiftAppium Web Recorder...")
    print("Web UI will be available at: http://localhost:\(port)")
    print("Appium server: \(appiumURL.absoluteString)")
    print("Press Ctrl+C to stop recording")

    // Use RunLoop.main.run() to handle async code
    Task {
      do {
        // Create and start the recorder
        let recorder = WebRecorder(port: port, appiumUrl: appiumURL)

        // Set up signal handling
        globalRecorder = recorder

        // Set up signal handlers for graceful shutdown
        signal(SIGINT) { _ in
          print("\nReceived SIGINT, shutting down gracefully...")
          Task {
            try? await globalRecorder?.shutdown()
            Foundation.exit(0)
          }
        }

        signal(SIGTERM) { _ in
          print("\nReceived SIGTERM, shutting down gracefully...")
          Task {
            try? await globalRecorder?.shutdown()
            Foundation.exit(0)
          }
        }

        // Start the recorder - this will block until interrupted
        try await recorder.start()

      } catch {
        print("Error starting WebRecorder: \(error.localizedDescription)")
        Foundation.exit(1)
      }
    }

    // Keep the main thread alive
    RunLoop.main.run()
  }

  private func isPortAvailable(port: Int) -> Bool {
    let socketFD = socket(AF_INET, Int32(SOCK_STREAM), Int32(0))
    guard socketFD != -1 else { return false }

    defer {
      #if canImport(Darwin)
        Darwin.close(socketFD)
      #elseif canImport(Glibc)
        Glibc.close(socketFD)
      #endif
    }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(port).bigEndian
    addr.sin_addr.s_addr = INADDR_ANY

    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }

    return bindResult == 0
  }
}

SwiftAppiumCLI.main()
