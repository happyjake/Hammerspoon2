//
//  HSCalendarModule.swift
//  Hammerspoon 2
//

import EventKit
import Foundation
import JavaScriptCore

/// Module for accessing Calendar Events.
@objc protocol HSCalendarModuleAPI: JSExport {
    /// Return the app's current Calendar authorization status.
    /// - Returns: One of `fullAccess`, `writeOnly`, `denied`, `restricted`, or `notDetermined`
    /// - Example:
    /// ```js
    /// const status = hs.calendar.authorizationStatus()
    /// console.log(status)
    /// ```
    @objc func authorizationStatus() -> String

    /// List the Calendars available for Events.
    /// - Returns: Calendar summaries containing `id`, `title`, `writable`, and `isDefault`
    /// - Example:
    /// ```js
    /// for (const calendar of hs.calendar.listCalendars()) {
    ///   console.log(calendar.title, calendar.id)
    /// }
    /// ```
    @objc func listCalendars() -> [[String: Any]]

    /// Create a single Event.
    /// - Parameter options: Event fields: `title`, `start`, `end`, optional `calendar`, `allDay`, `location`, `notes`, `url`, and `alarms`
    ///   Timed `start`/`end` values require an explicit UTC offset or `Z`; all-day values must be `YYYY-MM-DD`.
    ///   `calendar` resolves by id first, then exact title, and defaults to the Calendar for new Events when omitted.
    ///   `alarms` contains non-negative minutes-before values. Recurring Event creation is unsupported.
    /// - Returns: The created Event as a plain object; invalid input, unavailable targets, and save failures throw a JavaScript `Error`
    /// - Example:
    /// ```js
    /// const event = hs.calendar.createEvent({
    ///   title: 'Project check-in',
    ///   start: '2026-07-13T01:00:00Z',
    ///   end: '2026-07-13T01:30:00Z',
    ///   alarms: [10]
    /// })
    /// console.log(event.id)
    /// ```
    @objc func createEvent(_ options: JSValue) -> [String: Any]?
}

@_documentation(visibility: private)
@MainActor
@objc class HSCalendarModule: NSObject, HSModuleAPI, HSCalendarModuleAPI {
    var name = "hs.calendar"
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
        switch eventStore.authorizationStatus(for: .event) {
        case .fullAccess:    return "fullAccess"
        case .writeOnly:     return "writeOnly"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default:    return "notDetermined"
        }
    }

    @objc func listCalendars() -> [[String: Any]] {
        let defaultIdentifier = eventStore.eventStore.defaultCalendarForNewEvents?.calendarIdentifier

        return eventStore.eventStore.calendars(for: .event).map { calendar in
            [
                "id": calendar.calendarIdentifier,
                "title": calendar.title,
                "writable": calendar.allowsContentModifications,
                "isDefault": calendar.calendarIdentifier == defaultIdentifier,
            ]
        }
    }

    @objc func createEvent(_ options: JSValue) -> [String: Any]? {
        guard options.isObject, !options.isArray else {
            return fail("options object required", in: options)
        }

        for field in ["recurrence", "recurrenceRule"] where Self.property(field, in: options) != nil {
            return fail("recurring Event creation is not supported", in: options)
        }

        guard let titleValue = Self.property("title", in: options),
              titleValue.isString,
              let title = titleValue.toString(),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fail("'title' is required and must be a non-empty string", in: options)
        }

        let allDay: Bool
        if let allDayValue = Self.property("allDay", in: options) {
            guard allDayValue.isBoolean else {
                return fail("'allDay' must be a boolean", in: options)
            }
            allDay = allDayValue.toBool()
        } else {
            allDay = false
        }

        guard let startValue = Self.property("start", in: options),
              startValue.isString,
              let startString = startValue.toString() else {
            return fail("'start' is required and must be a string", in: options)
        }
        guard let endValue = Self.property("end", in: options),
              endValue.isString,
              let endString = endValue.toString() else {
            return fail("'end' is required and must be a string", in: options)
        }

        let startDate: Date
        let endDate: Date
        if allDay {
            guard Self.isDateOnly(startString), let parsedStart = Self.parseDateOnly(startString) else {
                return fail("'start' must be a date-only YYYY-MM-DD value when allDay is true", in: options)
            }
            guard Self.isDateOnly(endString), let parsedEnd = Self.parseDateOnly(endString) else {
                return fail("'end' must be a date-only YYYY-MM-DD value when allDay is true", in: options)
            }
            startDate = parsedStart
            endDate = parsedEnd
        } else {
            guard Self.hasExplicitUTCOffset(startString) else {
                return fail("'start' must be an ISO 8601 datetime with a UTC offset or Z", in: options)
            }
            guard let parsedStart = Self.parseInstant(startString) else {
                return fail("'start' must be a valid ISO 8601 datetime with a UTC offset or Z", in: options)
            }
            guard Self.hasExplicitUTCOffset(endString) else {
                return fail("'end' must be an ISO 8601 datetime with a UTC offset or Z", in: options)
            }
            guard let parsedEnd = Self.parseInstant(endString) else {
                return fail("'end' must be a valid ISO 8601 datetime with a UTC offset or Z", in: options)
            }
            startDate = parsedStart
            endDate = parsedEnd
        }

        guard endDate > startDate else {
            return fail("'end' must be later than 'start'", in: options)
        }

        let calendarSelector: String?
        if let calendarValue = Self.property("calendar", in: options) {
            guard calendarValue.isString,
                  let selector = calendarValue.toString(),
                  !selector.isEmpty else {
                return fail("'calendar' must be a non-empty Calendar id or title", in: options)
            }
            calendarSelector = selector
        } else {
            calendarSelector = nil
        }

        var optionalStrings: [String: String] = [:]
        for field in ["location", "notes", "url"] {
            guard let value = Self.property(field, in: options) else { continue }
            guard value.isString, let string = value.toString() else {
                return fail("'\(field)' must be a string", in: options)
            }
            optionalStrings[field] = string
        }

        var eventURL: URL?
        if let urlString = optionalStrings["url"] {
            guard let url = URL(string: urlString), url.scheme != nil else {
                return fail("'url' must be an absolute URL", in: options)
            }
            eventURL = url
        }

        var alarmMinutes: [Double] = []
        if let alarmsValue = Self.property("alarms", in: options) {
            guard alarmsValue.isArray else {
                return fail("'alarms' must be an array of non-negative minutes-before numbers", in: options)
            }
            let count = Int(alarmsValue.objectForKeyedSubscript("length")?.toInt32() ?? 0)
            for index in 0..<count {
                guard let alarmValue = alarmsValue.atIndex(index), alarmValue.isNumber else {
                    return fail("'alarms' must contain only non-negative minutes-before numbers", in: options)
                }
                let minutes = alarmValue.toDouble()
                guard minutes.isFinite, minutes >= 0 else {
                    return fail("'alarms' must contain only non-negative minutes-before numbers", in: options)
                }
                alarmMinutes.append(minutes)
            }
        }

        let status = authorizationStatus()
        guard status == "fullAccess" else {
            return fail("Calendar access is \(status); grant Calendar access in Hammerspoon 2 and retry", in: options)
        }

        guard let calendar = calendarForCreation(selector: calendarSelector, options: options) else {
            return nil
        }

        let store = eventStore.eventStore
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = allDay
        event.timeZone = allDay ? nil : TimeZone(secondsFromGMT: 0)
        event.location = optionalStrings["location"]
        event.notes = optionalStrings["notes"]
        event.url = eventURL
        for minutes in alarmMinutes {
            event.addAlarm(EKAlarm(relativeOffset: -minutes * 60))
        }

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            return fail("could not save Event: \(error.localizedDescription)", in: options)
        }

        return Self.eventResult(event, alarmMinutes: alarmMinutes)
    }

    private static func property(_ key: String, in options: JSValue) -> JSValue? {
        guard let value = options.objectForKeyedSubscript(key), !value.isUndefined else {
            return nil
        }
        return value
    }

    private static func hasExplicitUTCOffset(_ value: String) -> Bool {
        value.range(of: #"(?:Z|[+-]\d{2}:\d{2})$"#, options: .regularExpression) != nil
    }

    private static func isDateOnly(_ value: String) -> Bool {
        value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }

    private static func parseInstant(_ value: String) -> Date? {
        guard value.range(
            of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"#,
            options: .regularExpression
        ) != nil,
        hasValidUTCOffset(value) else {
            return nil
        }

        let dateParts = value.prefix(10).split(separator: "-").compactMap { Int($0) }
        let timeParts = value.dropFirst(11).prefix(8).split(separator: ":").compactMap { Int($0) }
        guard dateParts.count == 3, timeParts.count == 3 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: dateParts[0],
            month: dateParts[1],
            day: dateParts[2],
            hour: timeParts[0],
            minute: timeParts[1],
            second: timeParts[2]
        )
        guard let componentDate = calendar.date(from: components) else { return nil }
        let roundTrip = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: componentDate)
        guard roundTrip.year == dateParts[0],
              roundTrip.month == dateParts[1],
              roundTrip.day == dateParts[2],
              roundTrip.hour == timeParts[0],
              roundTrip.minute == timeParts[1],
              roundTrip.second == timeParts[2] else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func hasValidUTCOffset(_ value: String) -> Bool {
        guard value.last != "Z" else { return true }

        let offset = value.suffix(6)
        guard offset.first == "+" || offset.first == "-" else { return false }

        let parts = offset.dropFirst().split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              hours <= 14,
              minutes <= 59 else {
            return false
        }
        return hours < 14 || minutes == 0
    }

    private static func parseDateOnly(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2]
        )
        guard let date = calendar.date(from: components) else { return nil }
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == parts[0], roundTrip.month == parts[1], roundTrip.day == parts[2] else {
            return nil
        }
        return date
    }

    private func calendarForCreation(selector: String?, options: JSValue) -> EKCalendar? {
        let store = eventStore.eventStore
        let calendar: EKCalendar?

        if let selector {
            let calendars = store.calendars(for: .event)
            if let identifierMatch = calendars.first(where: { $0.calendarIdentifier == selector }) {
                calendar = identifierMatch
            } else {
                let titleMatches = calendars.filter { $0.title == selector }
                switch titleMatches.count {
                case 0:
                    return fail("Calendar '\(selector)' was not found", in: options)
                case 1:
                    calendar = titleMatches[0]
                default:
                    let candidates = titleMatches
                        .sorted { $0.calendarIdentifier < $1.calendarIdentifier }
                        .map { "\($0.title) (id: \($0.calendarIdentifier))" }
                        .joined(separator: ", ")
                    return fail(
                        "Calendar title '\(selector)' is ambiguous; retry with one of these ids: \(candidates)",
                        in: options
                    )
                }
            }
        } else {
            calendar = store.defaultCalendarForNewEvents
            if calendar == nil {
                return fail(
                    "no default Calendar is configured; pass 'calendar' as an id or title",
                    in: options
                )
            }
        }

        guard let calendar else { return nil }
        guard calendar.allowsContentModifications else {
            return fail(
                "Calendar '\(calendar.title)' (id: \(calendar.calendarIdentifier)) is read-only",
                in: options
            )
        }
        return calendar
    }

    private static func eventResult(_ event: EKEvent, alarmMinutes: [Double]) -> [String: Any] {
        [
            "id": event.calendarItemIdentifier,
            "title": event.title ?? "",
            "start": event.isAllDay ? formatDateOnly(event.startDate) : formatInstant(event.startDate),
            "end": event.isAllDay ? formatDateOnly(event.endDate) : formatInstant(event.endDate),
            "allDay": event.isAllDay,
            "location": event.location ?? NSNull(),
            "notes": event.notes ?? NSNull(),
            "url": event.url?.absoluteString ?? NSNull(),
            "alarms": alarmMinutes,
        ]
    }

    private static func formatInstant(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func formatDateOnly(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func fail<T>(_ message: String, in value: JSValue) -> T? {
        setException(message, in: value)
        return nil
    }

    private func setException(_ message: String, in value: JSValue) {
        JSContext.current()?.exception = JSValue(
            newErrorFromMessage: "hs.calendar.createEvent: \(message)",
            in: value.context
        )
    }
}
