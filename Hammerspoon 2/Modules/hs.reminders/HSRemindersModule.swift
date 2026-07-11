//
//  HSRemindersModule.swift
//  Hammerspoon 2
//

import EventKit
import Foundation
import JavaScriptCore

/// Module for accessing Reminders.
@objc protocol HSRemindersModuleAPI: JSExport {
    /// Return the app's current Reminders authorization status.
    /// - Returns: One of `fullAccess`, `denied`, `restricted`, or `notDetermined`
    /// - Example:
    /// ```js
    /// const status = hs.reminders.authorizationStatus()
    /// console.log(status)
    /// ```
    @objc func authorizationStatus() -> String

    /// List the Reminder Lists available for Reminders.
    /// - Returns: Reminder List summaries containing `id`, `title`, `writable`, and `isDefault`
    /// - Example:
    /// ```js
    /// for (const list of hs.reminders.listReminderLists()) {
    ///   console.log(list.title, list.id)
    /// }
    /// ```
    @objc func listReminderLists() -> [[String: Any]]

    /// List Reminders in a Reminder List, filtered by completion state.
    /// - Parameters:
    ///   - list?: {string} A Reminder List id or exact title. Omit it to use the default Reminder List.
    ///   - completed?: {boolean} `true` for completed Reminders or `false` for incomplete Reminders. Defaults to `false`.
    /// - Returns: {Promise<object[]>} A Promise resolving to Reminder summaries
    /// - Example:
    /// ```js
    /// const outstanding = await hs.reminders.listReminders('Work')
    /// const completed = await hs.reminders.listReminders('Work', true)
    /// ```
    @objc func listReminders(_ list: String?, _ completed: NSNumber?) -> JSPromise?

    /// Create a Reminder.
    /// - Parameter options: {{list?: string; title: string; due?: string; priority?: 'none' | 'low' | 'medium' | 'high'; notes?: string}} An object containing the Reminder fields
    /// - Returns: The created Reminder summary, or `null` after throwing a JavaScript error
    /// - Example:
    /// ```js
    /// const reminder = hs.reminders.createReminder({
    ///   list: 'Work',
    ///   title: 'Submit expenses',
    ///   due: '2026-07-14',
    ///   priority: 'high'
    /// })
    /// ```
    @objc func createReminder(_ options: JSValue) -> [String: Any]?

    /// Mark a Reminder complete.
    /// - Parameter id: The Reminder's stable identifier
    /// - Returns: The completed Reminder summary, or `null` after throwing a JavaScript error
    /// - Example:
    /// ```js
    /// const completed = hs.reminders.completeReminder(reminder.id)
    /// ```
    @objc func completeReminder(_ id: String) -> [String: Any]?

    /// Delete a Reminder.
    /// - Parameter id: The Reminder's stable identifier
    /// - Returns: `true` when the Reminder was deleted, or `false` after throwing a JavaScript error
    /// - Example:
    /// ```js
    /// hs.reminders.deleteReminder(reminder.id)
    /// ```
    @objc func deleteReminder(_ id: String) -> Bool
}

private enum HSRemindersModuleError: LocalizedError {
    case noDefaultList
    case listNotFound(String)
    case ambiguousList(String, candidates: [String])
    case readOnlyList(String)
    case reminderNotFound(String)
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .noDefaultList:
            return "No default Reminder List is available"
        case .listNotFound(let target):
            return "Reminder List not found: \(target)"
        case .ambiguousList(let title, let candidates):
            return "Reminder List title '\(title)' is ambiguous; retry with one of these ids: \(candidates.joined(separator: ", "))"
        case .readOnlyList(let title):
            return "Reminder List '\(title)' is read-only"
        case .reminderNotFound(let id):
            return "Reminder not found: \(id)"
        case .invalidInput(let message):
            return message
        }
    }
}

@_documentation(visibility: private)
@MainActor
@objc class HSRemindersModule: NSObject, HSModuleAPI, HSRemindersModuleAPI {
    var name = "hs.reminders"
    let engineID: UUID

    private let eventStore = HSEventStore.shared

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKDebug("Init of \(name): \(engineID)")
    }

    func shutdown() {}

    isolated deinit {
        AKDebug("Deinit of \(name): \(engineID)")
    }

    @objc func authorizationStatus() -> String {
        switch eventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:    return "fullAccess"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .notDetermined: return "notDetermined"
        case .writeOnly:     return "denied"
        @unknown default:    return "notDetermined"
        }
    }

    @objc func listReminderLists() -> [[String: Any]] {
        let defaultIdentifier = eventStore.eventStore.defaultCalendarForNewReminders()?.calendarIdentifier

        return eventStore.eventStore.calendars(for: .reminder).map { list in
            [
                "id": list.calendarIdentifier,
                "title": list.title,
                "writable": list.allowsContentModifications,
                "isDefault": list.calendarIdentifier == defaultIdentifier,
            ]
        }
    }

    @objc func listReminders(_ list: String?, _ completed: NSNumber?) -> JSPromise? {
        guard let context = JSContext.current() else { return nil }

        let resolvedList: EKCalendar
        do {
            resolvedList = try resolveList(list)
        } catch {
            return context.createRejectedPromise(with: error.localizedDescription)
        }

        let predicate: NSPredicate
        if completed?.boolValue ?? false {
            predicate = eventStore.eventStore.predicateForCompletedReminders(
                withCompletionDateStarting: nil,
                ending: nil,
                calendars: [resolvedList]
            )
        } else {
            predicate = eventStore.eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: [resolvedList]
            )
        }

        return wrapAsyncInJSPromise(in: context) { [weak self] holder in
            guard let self else {
                holder.rejectWithMessage("hs.reminders is no longer available")
                return
            }
            self.eventStore.eventStore.fetchReminders(matching: predicate) { reminders in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let reminders else {
                            holder.rejectWithMessage("Could not fetch Reminders; grant Reminders access in Hammerspoon 2 and retry")
                            return
                        }
                        holder.resolveWith(reminders.map { self.reminderSummary($0) })
                    }
                }
            }
        }
    }

    @objc func createReminder(_ options: JSValue) -> [String: Any]? {
        let context = options.context
        do {
            guard options.isObject && !options.isArray else {
                throw HSRemindersModuleError.invalidInput("hs.reminders.createReminder: options object required")
            }

            let titleValue = options.objectForKeyedSubscript("title")
            guard let titleValue, titleValue.isString,
                  let title = titleValue.toString(),
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw HSRemindersModuleError.invalidInput("hs.reminders.createReminder: 'title' must be a non-empty string")
            }

            let list = try optionalString(in: options, key: "list")
            let due = try optionalString(in: options, key: "due").map(parseDue)
            let priority = try priorityValue(try optionalString(in: options, key: "priority") ?? "none")
            let notes = try optionalString(in: options, key: "notes")

            let targetList = try resolveList(list)
            guard targetList.allowsContentModifications else {
                throw HSRemindersModuleError.readOnlyList(targetList.title)
            }

            let reminder = EKReminder(eventStore: eventStore.eventStore)
            reminder.calendar = targetList
            reminder.title = title
            reminder.dueDateComponents = due
            reminder.priority = priority
            reminder.notes = notes
            try eventStore.eventStore.save(reminder, commit: true)
            return reminderSummary(reminder)
        } catch {
            context?.exception = JSValue(newErrorFromMessage: error.localizedDescription, in: context)
            return nil
        }
    }

    @objc func completeReminder(_ id: String) -> [String: Any]? {
        guard let context = JSContext.current() else { return nil }
        do {
            guard let reminder = eventStore.eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
                throw HSRemindersModuleError.reminderNotFound(id)
            }
            guard reminder.calendar.allowsContentModifications else {
                throw HSRemindersModuleError.readOnlyList(reminder.calendar.title)
            }

            reminder.isCompleted = true
            reminder.completionDate = Date()
            try eventStore.eventStore.save(reminder, commit: true)
            return reminderSummary(reminder)
        } catch {
            context.exception = JSValue(newErrorFromMessage: error.localizedDescription, in: context)
            return nil
        }
    }

    @objc func deleteReminder(_ id: String) -> Bool {
        guard let context = JSContext.current() else { return false }
        do {
            guard let reminder = eventStore.eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
                throw HSRemindersModuleError.reminderNotFound(id)
            }
            guard reminder.calendar.allowsContentModifications else {
                throw HSRemindersModuleError.readOnlyList(reminder.calendar.title)
            }

            try eventStore.eventStore.remove(reminder, commit: true)
            return true
        } catch {
            context.exception = JSValue(newErrorFromMessage: error.localizedDescription, in: context)
            return false
        }
    }

    private func resolveList(_ target: String?) throws -> EKCalendar {
        let lists = eventStore.eventStore.calendars(for: .reminder)
        guard let target else {
            guard let defaultList = eventStore.eventStore.defaultCalendarForNewReminders() else {
                throw HSRemindersModuleError.noDefaultList
            }
            return defaultList
        }

        if let identifierMatch = lists.first(where: { $0.calendarIdentifier == target }) {
            return identifierMatch
        }

        let titleMatches = lists.filter { $0.title == target }
        if titleMatches.count == 1, let titleMatch = titleMatches.first {
            return titleMatch
        }
        if titleMatches.count > 1 {
            let candidates = titleMatches.map { "\($0.title) (\($0.calendarIdentifier))" }
            throw HSRemindersModuleError.ambiguousList(target, candidates: candidates)
        }
        throw HSRemindersModuleError.listNotFound(target)
    }

    private func reminderSummary(_ reminder: EKReminder) -> [String: Any] {
        [
            "id": reminder.calendarItemIdentifier,
            "listId": reminder.calendar.calendarIdentifier,
            "listTitle": reminder.calendar.title,
            "title": reminder.title ?? "",
            "due": reminder.dueDateComponents.flatMap(dueString) ?? NSNull(),
            "priority": priorityBucket(reminder.priority),
            "notes": reminder.notes ?? NSNull(),
            "completed": reminder.isCompleted,
            "completionDate": reminder.completionDate.map(instantString) ?? NSNull(),
        ]
    }

    private func priorityBucket(_ priority: Int) -> String {
        switch priority {
        case 1...4: return "high"
        case 5:     return "medium"
        case 6...9: return "low"
        default:    return "none"
        }
    }

    private func dueString(_ components: DateComponents) -> String? {
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        if components.hour == nil && components.minute == nil && components.second == nil {
            return padded(year, length: 4) + "-" + padded(month, length: 2) + "-" + padded(day, length: 2)
        }

        var resolved = components
        if resolved.calendar == nil {
            resolved.calendar = Calendar(identifier: .gregorian)
        }
        if resolved.timeZone == nil {
            resolved.timeZone = .current
        }
        guard let date = resolved.date else { return nil }
        return instantString(date)
    }

    private func instantString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func optionalString(in options: JSValue, key: String) throws -> String? {
        guard let value = options.objectForKeyedSubscript(key), !value.isUndefined, !value.isNull else {
            return nil
        }
        guard value.isString, let string = value.toString() else {
            throw HSRemindersModuleError.invalidInput("hs.reminders.createReminder: '\(key)' must be a string")
        }
        return string
    }

    private func priorityValue(_ priority: String) throws -> Int {
        switch priority {
        case "none":   return 0
        case "high":   return 1
        case "medium": return 5
        case "low":    return 9
        default:
            throw HSRemindersModuleError.invalidInput(
                "hs.reminders.createReminder: 'priority' must be one of none, low, medium, or high"
            )
        }
    }

    private func parseDue(_ due: String) throws -> DateComponents {
        if due.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            let parts = due.split(separator: "-").compactMap { Int($0) }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
            guard components.isValidDate(in: calendar) else {
                throw HSRemindersModuleError.invalidInput("hs.reminders.createReminder: 'due' is not a valid date")
            }
            return components
        }

        let instantPattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"#
        guard due.range(of: instantPattern, options: .regularExpression) != nil else {
            throw HSRemindersModuleError.invalidInput(
                "hs.reminders.createReminder: timed 'due' must be an ISO 8601 instant with an explicit offset or Z"
            )
        }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let wholeSeconds = ISO8601DateFormatter()
        wholeSeconds.formatOptions = [.withInternetDateTime]
        guard let date = fractional.date(from: due) ?? wholeSeconds.date(from: due) else {
            throw HSRemindersModuleError.invalidInput("hs.reminders.createReminder: 'due' is not a valid ISO 8601 instant")
        }

        let utc = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )
        components.calendar = calendar
        components.timeZone = utc
        return components
    }

    private func padded(_ value: Int, length: Int) -> String {
        let raw = String(value)
        return String(repeating: "0", count: max(0, length - raw.count)) + raw
    }
}
