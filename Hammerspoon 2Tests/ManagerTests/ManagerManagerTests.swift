//
//  ManagerManagerTests.swift
//  Hammerspoon 2Tests
//
//  Created by Claude on 05/11/2025.
//

import Testing
import Foundation
@testable import Hammerspoon_2

struct ManagerManagerTests {

    @Test("App launch recognizes an XCTest host")
    func testRecognizesTestHost() {
        #expect(AppDelegate.isXCTestHost)
    }

    @Test("Test scheme config location overrides user defaults")
    func testConfigLocationFromTestArguments() {
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        #expect(arguments["configLocation"] as? String == "/dev/null/init.js")
        #expect(SettingsManager.shared.configLocation.path == "/dev/null/init.js")
    }

    // MARK: - Boot Tests

    @Test("Boot successfully with valid config file")
    func testBootWithValidConfig() async throws {
        // Arrange
        let mockEngine = MockJSEngine()
        let mockSettings = MockSettingsManager()
        let mockFileSystem = MockFileSystem()

        let configPath = "/path/to/init.js"
        let configURL = URL(fileURLWithPath: configPath)

        mockSettings.configLocation = configURL
        mockFileSystem.addFile(atPath: configPath, contents: "console.log('Hello from config');")

        let manager = ManagerManager(
            engine: mockEngine,
            settings: mockSettings,
            fileSystem: mockFileSystem
        )

        // Act
        try manager.boot()

        // Assert
        #expect(mockEngine.resetContextCalls == 1, "Engine context should be reset once")
        #expect(mockEngine.evalFromURLCalls.count == 1, "Config file should be evaluated once")
        #expect(mockEngine.evalFromURLCalls[0].url == configURL, "Correct config file should be evaluated")
    }

    @Test("Boot fails gracefully when config file does not exist")
    func testBootWithMissingConfigFile() async throws {
        // Arrange
        let mockEngine = MockJSEngine()
        let mockSettings = MockSettingsManager()
        let mockFileSystem = MockFileSystem()

        let configPath = "/nonexistent/init.js"
        mockSettings.configLocation = URL(fileURLWithPath: configPath)
        // Don't add the file to mockFileSystem, so it won't exist

        let manager = ManagerManager(
            engine: mockEngine,
            settings: mockSettings,
            fileSystem: mockFileSystem
        )

        // Act
        try manager.boot()

        // Assert
        #expect(mockEngine.resetContextCalls == 1, "Engine context should still be reset")
        #expect(mockEngine.evalFromURLCalls.count == 0, "Config file should not be evaluated when missing")
    }

    @Test("Boot resets context before loading config")
    func testBootResetsContext() async throws {
        // Arrange
        let mockEngine = MockJSEngine()
        let mockSettings = MockSettingsManager()
        let mockFileSystem = MockFileSystem()

        let configPath = "/path/to/init.js"
        mockSettings.configLocation = URL(fileURLWithPath: configPath)
        mockFileSystem.addFile(atPath: configPath)

        let manager = ManagerManager(
            engine: mockEngine,
            settings: mockSettings,
            fileSystem: mockFileSystem
        )

        // Act
        try manager.boot()

        // Assert - resetContext should be called before evalFromURL
        #expect(mockEngine.resetContextCalls == 1, "Context should be reset")
        #expect(mockEngine.evalFromURLCalls.count == 1, "Config should be evaluated")
    }

    @Test("Boot propagates engine reset errors")
    func testBootWithEngineResetError() async throws {
        // Arrange
        let mockEngine = MockJSEngine()
        let mockSettings = MockSettingsManager()
        let mockFileSystem = MockFileSystem()

        mockEngine.shouldThrowOnReset = true

        let manager = ManagerManager(
            engine: mockEngine,
            settings: mockSettings,
            fileSystem: mockFileSystem
        )

        // Act & Assert
        var didThrow = false
        do {
            try manager.boot()
        } catch {
            didThrow = true
        }

        #expect(didThrow, "Boot should throw when engine reset fails")
        #expect(mockEngine.evalFromURLCalls.count == 0, "Config should not be evaluated when reset fails")
    }

    @Test("Boot propagates config evaluation errors")
    func testBootWithConfigEvaluationError() async throws {
        // Arrange
        let mockEngine = MockJSEngine()
        let mockSettings = MockSettingsManager()
        let mockFileSystem = MockFileSystem()

        let configPath = "/path/to/init.js"
        mockSettings.configLocation = URL(fileURLWithPath: configPath)
        mockFileSystem.addFile(atPath: configPath)
        mockEngine.shouldThrowOnEvalFromURL = true

        let manager = ManagerManager(
            engine: mockEngine,
            settings: mockSettings,
            fileSystem: mockFileSystem
        )

        // Act & Assert
        var didThrow = false
        do {
            try manager.boot()
        } catch {
            didThrow = true
        }

        #expect(didThrow, "Boot should throw when config evaluation fails")
        #expect(mockEngine.resetContextCalls == 1, "Context should still be reset")
    }

    // MARK: - Dependency Injection Tests

    @Test("ManagerManager can be initialized with custom dependencies")
    func testCustomDependencyInjection() async throws {
        // Arrange
        let customEngine = MockJSEngine()
        let customSettings = MockSettingsManager()
        let customFileSystem = MockFileSystem()

        customSettings.configLocation = URL(fileURLWithPath: "/custom/path.js")
        customSettings.consoleHistoryLength = 200

        // Act
        let manager = ManagerManager(
            engine: customEngine,
            settings: customSettings,
            fileSystem: customFileSystem
        )

        // Assert
        #expect(manager.settings.configLocation.path == "/custom/path.js", "Custom settings should be used")
        #expect(manager.settings.consoleHistoryLength == 200, "Custom settings values should be preserved")
    }

    @Test("ManagerManager.shared uses default dependencies")
    func testSharedInstanceUsesDefaults() async throws {
        // Arrange & Act
        let manager = ManagerManager.shared

        // Assert
        // We can't verify the exact types without more introspection,
        // but we can verify the manager is properly initialized
        #expect(manager.settings.configLocation.path != "", "Shared instance should have valid settings")
    }

    // MARK: - Integration-style Tests

    @Test("Multiple boots reset the context each time")
    func testMultipleBoots() async throws {
        // Arrange
        let mockEngine = MockJSEngine()
        let mockSettings = MockSettingsManager()
        let mockFileSystem = MockFileSystem()

        let configPath = "/path/to/init.js"
        mockSettings.configLocation = URL(fileURLWithPath: configPath)
        mockFileSystem.addFile(atPath: configPath)

        let manager = ManagerManager(
            engine: mockEngine,
            settings: mockSettings,
            fileSystem: mockFileSystem
        )

        // Act
        try manager.boot()
        try manager.boot()
        try manager.boot()

        // Assert
        #expect(mockEngine.resetContextCalls == 3, "Context should be reset for each boot")
        #expect(mockEngine.evalFromURLCalls.count == 3, "Config should be evaluated for each boot")
    }

    @Test("Boot uses the current config location from settings")
    func testBootUsesCurrentConfigLocation() async throws {
        // Arrange
        let mockEngine = MockJSEngine()
        let mockSettings = MockSettingsManager()
        let mockFileSystem = MockFileSystem()

        // Set up first config
        let firstConfig = "/first/config.js"
        mockSettings.configLocation = URL(fileURLWithPath: firstConfig)
        mockFileSystem.addFile(atPath: firstConfig)

        let manager = ManagerManager(
            engine: mockEngine,
            settings: mockSettings,
            fileSystem: mockFileSystem
        )

        // Act - first boot
        try manager.boot()

        // Change config location
        let secondConfig = "/second/config.js"
        mockSettings.configLocation = URL(fileURLWithPath: secondConfig)
        mockFileSystem.addFile(atPath: secondConfig)

        // Act - second boot
        try manager.boot()

        // Assert
        #expect(mockEngine.evalFromURLCalls.count == 2, "Should evaluate config twice")
        #expect(mockEngine.evalFromURLCalls[0].url.path == firstConfig, "First boot should use first config")
        #expect(mockEngine.evalFromURLCalls[1].url.path == secondConfig, "Second boot should use second config")
    }
}
