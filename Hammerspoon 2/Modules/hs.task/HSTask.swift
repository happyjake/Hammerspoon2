//
//  HSTask.swift
//  Hammerspoon 2
//
//  Created by Claude on 03/02/2026.
//

import Foundation
import JavaScriptCore
import JavaScriptCoreExtras

/// Object representing an external process task
@objc protocol HSTaskAPI: HSTypeAPI, JSExport {
    /// Start the task
    /// - Returns: The task object for chaining
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/echo", ["hi"])
    /// t.start()
    /// ```
    @objc func start() -> HSTask

    /// Terminate the task (send SIGTERM)
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/sleep", ["60"]).start()
    /// t.terminate()
    /// ```
    @objc func terminate()

    /// Terminate the task with extreme prejudice (send SIGKILL)
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/sleep", ["60"]).start()
    /// t.kill9()
    /// ```
    @objc func kill9()

    /// Interrupt the task (send SIGINT)
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/sleep", ["60"]).start()
    /// t.interrupt()
    /// ```
    @objc func interrupt()

    /// Pause the task (send SIGSTOP)
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/sleep", ["60"]).start()
    /// t.pause()
    /// ```
    @objc func pause()

    /// Resume the task (send SIGCONT)
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/sleep", ["60"]).start()
    /// t.pause(); t.resume()
    /// ```
    @objc func resume()

    /// Wait for the task to complete (blocking)
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/echo", ["hi"]).start()
    /// t.waitUntilExit()
    /// ```
    @objc func waitUntilExit()

    /// Write data to the task's stdin
    /// - Parameter data: The string data to write
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/usr/bin/cat", []).start()
    /// t.sendInput("hello\n")
    /// ```
    @objc func sendInput(_ data: String)

    /// Close the task's stdin
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/usr/bin/cat", []).start()
    /// t.sendInput("hello\n")
    /// t.closeInput()
    /// ```
    @objc func closeInput()

    /// Check if the task is currently running
    /// - Note: true if the task is running, false otherwise
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/sleep", ["10"]).start()
    /// console.log(t.isRunning)
    /// ```
    @objc var isRunning: Bool { get }

    /// The process ID of the running task
    /// - Note: The value will be -1 if the task is not running
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/sleep", ["10"]).start()
    /// console.log(t.pid)
    /// ```
    @objc var pid: Int { get }

    /// The environment variables for the task
    /// - Note: Can only be modified before calling start()
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/usr/bin/env", [])
    /// t.environment = { FOO: "bar" }
    /// t.start()
    /// ```
    @objc var environment: [String: String] { get set }

    /// The working directory for the task
    /// - Note: Can only be modified before calling start()
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/pwd", [])
    /// t.workingDirectory = "/tmp"
    /// t.start()
    /// ```
    @objc var workingDirectory: String? { get set }

    /// The termination status of the task
    /// - Note: Returns the exit code, or nil if the task hasn't terminated
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/echo", ["hi"], () => {
    ///     console.log(t.terminationStatus)
    /// }).start()
    /// ```
    @objc var terminationStatus: NSNumber? { get }

    /// The termination reason
    /// - Note: Returns a string describing why the task terminated, or nil if still running
    /// - Example:
    /// ```js
    /// const t = hs.task.new("/bin/echo", ["hi"], () => {
    ///     console.log(t.terminationReason)
    /// }).start()
    /// ```
    @objc var terminationReason: String? { get }
}

@_documentation(visibility: private)
@MainActor
@objc class HSTask: NSObject, HSTaskAPI {
    @objc var typeName = "HSTask"

    private let launchPath: String
    private let arguments: [String]
    private var _environment: [String: String]
    private var _workingDirectory: String?
    // Strong references — a RUNNING task owns its callbacks: the JS handle is
    // routinely dropped right after `.start()` (fire-and-forget), and a
    // JSManagedValue-backed JSCallback gets zeroed once the task's JS wrapper
    // is collected — leaving completion Promises unresolved forever (same GC
    // bug class as the fire-and-forget timer death). Released in destroy()
    // and after the termination callback has fired; HSTaskModule.shutdown()
    // tears down all live tasks at reload, so JSContext teardown is unaffected.
    private var terminationCallback: JSValue?
    private var streamingCallback: JSValue?

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var stdinPipe: Pipe?

    private var hasStarted = false
    private var exitCode: Int32?
    private var exitReason: String?

    // EOF and exit coordination: the termination callback must only fire after both
    // stdout and stderr pipes have reached EOF, ensuring all streaming data has been
    // delivered to JS before the termination callback sees the accumulated result.
    // stdoutEOF/stderrEOF start true so the non-streaming path works without change.
    private var processExited = false
    private var stdoutEOF = true
    private var stderrEOF = true

    // Reference to module for task tracking
    private weak var module: HSTaskModule?

    // Deliberate self-retain for the lifetime of the RUNNING process. The
    // module tracks tasks weakly and Process's handlers capture self weakly,
    // so nothing else keeps a started task alive once its JS wrapper is
    // collected — the whole task (pending termination callback included) died
    // at the first GC after a fire-and-forget `.start()`. Set on successful
    // run(), cleared when the termination callback path completes and in
    // destroy() (module shutdown force-terminates all live tasks).
    private var runningSelfRetain: HSTask?

    /// The environment variables for the task
    @objc var environment: [String: String] {
        get { _environment }
        set {
            guard !hasStarted else {
                AKWarning("hs.task.environment: Cannot modify environment after task has started")
                return
            }
            _environment = newValue
        }
    }

    /// The working directory for the task
    @objc var workingDirectory: String? {
        get { _workingDirectory }
        set {
            guard !hasStarted else {
                AKWarning("hs.task.workingDirectory: Cannot modify working directory after task has started")
                return
            }
            _workingDirectory = newValue
        }
    }

    @objc var pid: Int {
        Int(process?.processIdentifier ?? -1)
    }

    @objc var isRunning: Bool {
        return process?.isRunning ?? false
    }

    init(launchPath: String, arguments: [String], environment: [String: String]?, terminationCallback: JSFunction?, streamingCallback: JSFunction?, module: HSTaskModule?) {
        self.launchPath = launchPath
        self.arguments = arguments
        self._environment = environment ?? ProcessInfo.processInfo.environment
        self.module = module
        super.init()
        self.terminationCallback = terminationCallback
        self.streamingCallback = streamingCallback
    }

    isolated deinit {
        destroy()
        AKDebug("deinit of HSTask: \(launchPath)")
    }

    func destroy() {
        terminationCallback = nil
        streamingCallback = nil
        runningSelfRetain = nil

        // This is called when HS is restarting/exiting, to clean up this HSTask.
        // We will send it a SIGTERM, then attempt to wait a few seconds and send a SIGKILL.
        // FIXME: When HS is exiting, the SIGKILL tasks likely won't ever get called.
        guard let process, process.isRunning else { return }
        let pid = process.processIdentifier

        terminate()

        Task.detached {
            try? await Task.sleep(for: .seconds(5))

            let result = kill(pid, SIGKILL)
            let errorMsg = unsafe String(validatingCString: strerror(result)) ?? "NONE"
            print ("hs.task SIGKILL result: \(pid) (\(errorMsg))")
        }
    }

    @objc func start() -> HSTask {
        guard !hasStarted else {
            AKWarning("hs.task:start(): Task has already been started")
            return self
        }

        hasStarted = true

        // Register this task as active
        module?.registerActiveTask(self)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.environment = _environment

        if let workingDir = _workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }

        // Set up pipes for stdin, stdout, stderr
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe

        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.stdinPipe = stdinPipe

        // Set up streaming callbacks if provided
        if streamingCallback != nil {
            setupStreamingCallbacks(stdout: stdoutPipe, stderr: stderrPipe)
        }

        // Set up termination handler.
        // We only mark the process as exited here; the actual termination callback
        // fires via callTerminationCallbackIfReady() once both pipes also signal EOF.
        // This prevents the race where the termination callback resolves the JS
        // Promise with empty stdout because streaming Tasks haven't run yet.
        process.terminationHandler = { [weak self] process in
            guard let self = self else { return }

            let exitCode = process.terminationStatus
            let terminationReason = process.terminationReason

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.exitCode = exitCode
                self.exitReason = self.getTerminationReasonString(terminationReason)
                self.processExited = true
                self.callTerminationCallbackIfReady()
            }
        }

        // Launch the process
        do {
            try process.run()
            runningSelfRetain = self
        } catch {
            AKError("hs.task:start(): Failed to start task: \(error.localizedDescription)")
            // Unregister and free the pipe fds if we never launched
            module?.unregisterActiveTask(self)
            releasePipes()
        }

        return self
    }

    @objc func terminate() {
        process?.terminate()
    }

    @objc func interrupt() {
        process?.interrupt()
    }

    @objc func pause() {
        guard let process = process, process.isRunning else { return }
        kill(process.processIdentifier, SIGSTOP)
    }

    @objc func resume() {
        guard let process = process, process.isRunning else { return }
        kill(process.processIdentifier, SIGCONT)
    }

    @objc func kill9() {
        guard let process = process, process.isRunning else { return }
        kill(process.processIdentifier, SIGKILL)
    }

    @objc func waitUntilExit() {
        process?.waitUntilExit()
    }

    @objc func sendInput(_ data: String) {
        guard let stdinPipe = stdinPipe else {
            AKWarning("hs.task:sendInput(): stdin pipe not available")
            return
        }

        if let dataToWrite = data.data(using: .utf8) {
            do {
                try stdinPipe.fileHandleForWriting.write(contentsOf: dataToWrite)
            } catch {
                AKError("hs.task:sendInput(): Failed to write to stdin: \(error.localizedDescription)")
            }
        }
    }

    @objc func closeInput() {
        do {
            try stdinPipe?.fileHandleForWriting.close()
        } catch {
            AKError("hs.task:closeInput(): Failed to close stdin: \(error.localizedDescription)")
        }
    }

    @objc var terminationStatus: NSNumber? {
        guard let exitCode = exitCode else { return nil }
        return NSNumber(value: exitCode)
    }

    @objc var terminationReason: String? {
        return exitReason
    }

    // MARK: - Private helpers

    private func setupStreamingCallbacks(stdout: Pipe, stderr: Pipe) {
        // Mark both pipes as not-yet-closed; callTerminationCallbackIfReady() will
        // only fire once both signal EOF AND the process has exited.
        stdoutEOF = false
        stderrEOF = false

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }

            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.stdoutEOF = true
                    self.callTerminationCallbackIfReady()
                }
                return
            }
            guard let output = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let cb = self.streamingCallback, !cb.isUndefined else { return }
                guard let context = cb.context else { return }
                cb.call(withArguments: ["stdout", output])
                if let exception = context.exception, !exception.isUndefined {
                    AKError("hs.task: Error in streaming callback: \(exception.toString() ?? "unknown error")")
                    context.exception = nil
                }
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }

            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.stderrEOF = true
                    self.callTerminationCallbackIfReady()
                }
                return
            }
            guard let output = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let cb = self.streamingCallback, !cb.isUndefined else { return }
                guard let context = cb.context else { return }
                cb.call(withArguments: ["stderr", output])
                if let exception = context.exception, !exception.isUndefined {
                    AKError("hs.task: Error in streaming callback: \(exception.toString() ?? "unknown error")")
                    context.exception = nil
                }
            }
        }
    }

    private func callTerminationCallbackIfReady() {
        guard processExited && stdoutEOF && stderrEOF else { return }

        if let cb = terminationCallback, cb.isFunction, !cb.isUndefined {
            guard let context = cb.context else {
                module?.unregisterActiveTask(self)
                return
            }
            cb.call(withArguments: [exitCode ?? 0, exitReason ?? "unknown"])
            if let exception = context.exception, !exception.isUndefined {
                AKError("hs.task: Error in termination callback: \(exception.toString() ?? "unknown error")")
                context.exception = nil
            }
        }

        // The task is finished and both callbacks are one-shot from here on —
        // release them so a dead task doesn't pin JS closures until GC/deinit.
        terminationCallback = nil
        streamingCallback = nil

        module?.unregisterActiveTask(self)
        releasePipes()
        runningSelfRetain = nil
    }

    // Close the parent-side pipe descriptors the moment the child exits, instead
    // of waiting for JSC to garbage-collect this wrapper. Each task holds three
    // open fds (stdout + stderr read ends, stdin write end); because the JS
    // wrapper is tiny it creates almost no heap pressure, so GC rarely runs and
    // the fds accumulate ~3 per task. Left unchecked they exhaust the process
    // descriptor limit and every later open() fails with EMFILE — which surfaces
    // far from here (e.g. ImageIO "could not create destination" when the
    // clipboard watcher transcodes an image, dropped sockets, etc.). Idempotent:
    // niling the pipes means a later deinit has nothing left to close.
    private func releasePipes() {
        // Tear down any streaming read sources BEFORE closing the underlying fds.
        // Closing an fd still monitored by a readabilityHandler's dispatch source
        // is a libdispatch contract violation — the source can fire on a closed
        // handle and raise an uncatchable NSFileHandleOperationException (SIGABRT).
        // The normal-exit path already nils these in the EOF branch; doing it here
        // too makes the launch-failure path (run() threw after the handlers were
        // installed) safe as well. Idempotent — niling an already-nil handler is a
        // no-op, as is the non-streaming case where none were ever installed.
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        try? stdoutPipe?.fileHandleForReading.close()
        try? stderrPipe?.fileHandleForReading.close()
        try? stdinPipe?.fileHandleForWriting.close()
        stdoutPipe = nil
        stderrPipe = nil
        stdinPipe = nil
    }

    private func getTerminationReasonString(_ reason: Process.TerminationReason) -> String {
        switch reason {
        case .exit:
            return "exit"
        case .uncaughtSignal:
            return "uncaughtSignal"
        @unknown default:
            return "unknown"
        }
    }
}
