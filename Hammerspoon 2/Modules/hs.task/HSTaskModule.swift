//
//  TaskModule.swift
//  Hammerspoon 2
//
//  Created by Claude on 03/02/2026.
//

import Foundation
import JavaScriptCore
import JavaScriptCoreExtras

// MARK: - Declare our JavaScript API

/// Module for running external processes
@objc protocol HSTaskModuleAPI: JSExport {
    /// Create a new task
    /// - Parameters:
    ///   - launchPath: The full path to the executable to run
    ///   - arguments: {string[]} An array of arguments to pass to the executable
    ///   - completionCallback: {((exitCode: number, exitReason: string) => void) | null} Optional callback called when the task terminates with exit code and reason
    ///   - environment: {Record<string, string> | null} Optional dictionary of environment variables for the task
    ///   - streamingCallback: {((stream: string, data: string) => void) | null} Optional callback called when the task produces output; stream is "stdout" or "stderr"
    /// - Returns: A task object. Call start() to begin execution.
    /// - Example:
    /// ```js
    /// const task = hs.task.create("/usr/bin/env", ["printenv", "PATH"], (code, reason) => {
    ///     console.log("exited", code)
    /// })
    /// task.start()
    /// ```
    @objc(create:::::)
    func create(_ launchPath: String, _ arguments: JSValue, _ completionCallback: JSFunction?, _ environment: JSValue?, _ streamingCallback: JSFunction?) -> HSTask?

    /// SKIP_DOCS
    @objc var runAsync: JSFunction? { get set }

    /// SKIP_DOCS
    @objc var shell: JSFunction? { get set }

    /// SKIP_DOCS
    @objc var parallel: JSFunction? { get set }

    /// Run multiple tasks in sequence. Swift-retained storage for the JS implementation.
    /// - Example:
    /// ```js
    /// hs.task.sequence([
    ///     ["/bin/echo", ["one"]],
    ///     ["/bin/echo", ["two"]]
    /// ]).then(results => console.log(results))
    /// ```
    @objc var sequence: JSFunction? { get set }

    /// SKIP_DOCS
    @objc var builder: JSFunction? { get set }

    /// TaskBuilder class. Swift-retained storage for the JS implementation.
    /// - Example:
    /// ```js
    /// const b = new hs.task.TaskBuilder().launchPath("/bin/echo")
    /// ```
    @objc var TaskBuilder: JSFunction? { get set }

    /// Run a short-lived command synchronously and return its stdout as a
    /// string. Use sparingly — this blocks the JS thread until the process
    /// exits. Intended for fast utilities (`ps`, `whoami`, `uname`) where
    /// awaiting a Promise would add UI flicker.
    /// - Parameter launchPath: Absolute path to the executable
    /// - Parameter arguments: {string[]} Argument array
    /// - Returns: Combined stdout as a string, or null on failure
    /// - Example:
    /// ```js
    /// const out = hs.task.runSync('/bin/ps', ['-axo', 'pid,rss,comm'])
    /// ```
    @objc func runSync(_ launchPath: String, _ arguments: JSValue) -> String?
}

// MARK: - Implementation

// Actor to safely track active tasks across threads
struct TaskTracker {
    private var activeTasks = Set<ObjectIdentifier>()

    mutating func register(_ task: HSTask) {
        activeTasks.insert(ObjectIdentifier(task))
    }

    mutating func unregister(_ task: HSTask) {
        activeTasks.remove(ObjectIdentifier(task))
    }

    func count() -> Int {
        return activeTasks.count
    }

    mutating func clear() {
        activeTasks.removeAll()
    }
}

@_documentation(visibility: private)
@MainActor
@objc class HSTaskModule: NSObject, HSModuleAPI, HSTaskModuleAPI {
    var name = "hs.task"
    let engineID: UUID

    // Weak refs: running tasks stay alive via their Process termination handler closure;
    // weak refs allow completed/GC'd tasks to be reclaimed while supporting shutdown().
    private var tasks = HSWeakObjectSet<HSTask>()

    // Swift-retained storage for JS-defined functions
    @objc var runAsync: JSFunction? = nil
    @objc var shell: JSFunction? = nil
    @objc var parallel: JSFunction? = nil
    @objc var sequence: JSFunction? = nil
    @objc var builder: JSFunction? = nil
    @objc var TaskBuilder: JSFunction? = nil

    // Track active tasks for testing purposes (thread-safe via actor)
    private var taskTracker = TaskTracker()

    // MARK: - Module lifecycle
    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKDebug("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for task in tasks.allObjects {
            taskTracker.unregister(task)
            task.destroy()
        }
        tasks.removeAllObjects()
        runAsync = nil
        shell = nil
        parallel = nil
        sequence = nil
        builder = nil
        TaskBuilder = nil
    }

    isolated deinit {
        AKDebug("Deinit of \(name): \(engineID)")
    }

    // MARK: - Task Tracking (for testing)

    var createdTaskCount: Int {
        tasks.allObjects.count
    }

    func registerActiveTask(_ task: HSTask) {
        taskTracker.register(task)
    }

    func unregisterActiveTask(_ task: HSTask) {
        taskTracker.unregister(task)
    }

    @MainActor
    func waitForAllTasksToComplete(timeout: TimeInterval = 5.0) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let count = taskTracker.count()

            if count == 0 {
                return true
            }

            try? await Task.sleep(for: .milliseconds(50))
        }

        return false
    }

    // MARK: - Task constructors

    @objc func runSync(_ launchPath: String, _ arguments: JSValue) -> String? {
        guard let bridgedArguments = arguments.toStringArray(method: "hs.task.runSync", parameter: "arguments") else {
            return nil
        }

        let process = Process()
        process.launchPath = launchPath
        process.arguments = bridgedArguments
        let pipe = Pipe()
        process.standardOutput = pipe
        // Send stderr to /dev/null — caller only wants stdout.
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        do {
            try process.run()
            // readDataToEndOfFile() blocks until the pipe is closed, which
            // happens when the process exits — so this also waits for exit.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)
        } catch {
            AKError("hs.task.runSync: failed to launch \(launchPath): \(error.localizedDescription)")
            return nil
        }
    }

    @objc func create(_ launchPath: String, _ arguments: JSValue, _ completionCallback: JSFunction? = nil, _ environment: JSValue? = nil, _ streamingCallback: JSFunction? = nil) -> HSTask? {
        guard let bridgedArguments = arguments.toStringArray(method: "hs.task.create", parameter: "arguments"),
              let bridgedEnvironment = environment.toOptionalStringDictionary(method: "hs.task.create", parameter: "environment")
        else {
            return nil
        }

        let task = HSTask(
            launchPath: launchPath,
            arguments: bridgedArguments,
            environment: bridgedEnvironment,
            terminationCallback: completionCallback,
            streamingCallback: streamingCallback,
            module: self
        )

        tasks.add(task)
        return task
    }
}
