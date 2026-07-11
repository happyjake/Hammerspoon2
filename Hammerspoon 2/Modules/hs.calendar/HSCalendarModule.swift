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

    /// List Events from one Calendar that overlap a time window. The window may span at most four years.
    /// - Parameters:
    ///   - calendar: Calendar id or exact title
    ///   - start: Window start as a valid ISO 8601 datetime with an explicit offset from `-14:00` through `+14:00`, or `Z`
    ///   - end: Window end as a valid ISO 8601 datetime with an explicit offset from `-14:00` through `+14:00`, or `Z`
    /// - Returns: Event objects containing `id`, `title`, `start`, `end`, `allDay`, `location`, `notes`, `url`, `attendees`, `organizer`, `status`, `availability`, `recurring`, and `occurrenceStart`. Timed values use UTC `Z`; all-day values are `YYYY-MM-DD`. Each attendee and organizer contains `name`, `url`, `status`, `role`, `type`, and `currentUser`. Non-recurring Events have a `null` `occurrenceStart`.
    /// - Example:
    /// ```js
    /// const events = hs.calendar.listEvents(
    ///   'Work',
    ///   '2026-07-12T00:00:00Z',
    ///   '2026-07-13T00:00:00Z'
    /// )
    /// ```
    @objc(listEvents:::)
    func listEvents(_ calendar: String, _ start: String, _ end: String) -> [[String: Any]]

    /// Search Event titles across all Calendars in a time window. The window may span at most four years.
    /// - Parameters:
    ///   - query: Case-insensitive text to find in Event titles
    ///   - start: Window start as a valid ISO 8601 datetime with an explicit offset from `-14:00` through `+14:00`, or `Z`
    ///   - end: Window end as a valid ISO 8601 datetime with an explicit offset from `-14:00` through `+14:00`, or `Z`
    /// - Returns: Matching Event objects in the same occurrence-aware shape as `listEvents`
    /// - Example:
    /// ```js
    /// const events = hs.calendar.searchEvents(
    ///   'planning',
    ///   '2026-07-12T00:00:00Z',
    ///   '2026-07-19T00:00:00Z'
    /// )
    /// ```
    @objc(searchEvents:::)
    func searchEvents(_ query: String, _ start: String, _ end: String) -> [[String: Any]]

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

    /// Update writable fields on one non-recurring Event.
    /// - Parameters:
    ///   - id: Event identifier returned by `createEvent`, `listEvents`, or `searchEvents`
    ///   - fields: One or more of `calendar`, `title`, `start`, `end`, `allDay`, `location`, `notes`, `url`, and `alarms`.
    ///     Timed `start`/`end` values require an explicit UTC offset or `Z`; all-day values must be `YYYY-MM-DD`.
    ///     Changing `allDay` requires both `start` and `end`. Pass `null` to clear `location`, `notes`, or `url`.
    ///     `calendar` resolves by id first, then exact title. Recurring Event series editing is unsupported in v1.
    /// - Returns: The updated Event as a plain object; unknown ids, recurring series, invalid fields, and save failures throw a JavaScript `Error`
    /// - Example:
    /// ```js
    /// const event = hs.calendar.updateEvent('EVENT_ID', {
    ///   start: '2026-07-13T02:00:00Z',
    ///   end: '2026-07-13T02:30:00Z'
    /// })
    /// ```
    @objc(updateEvent::)
    func updateEvent(_ id: String, _ fields: JSValue) -> [String: Any]?

    /// Delete one non-recurring Event. Recurring Event series deletion is unsupported in v1.
    /// - Parameter id: Event identifier returned by `createEvent`, `listEvents`, or `searchEvents`
    /// - Returns: `true` after the Event is removed; unknown ids, recurring series, and removal failures throw a JavaScript `Error`
    /// - Example:
    /// ```js
    /// hs.calendar.deleteEvent('EVENT_ID')
    /// ```
    @objc func deleteEvent(_ id: String) -> Bool
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

    @objc(listEvents:::)
    func listEvents(_ calendar: String, _ start: String, _ end: String) -> [[String: Any]] {
        guard let window = queryWindow(start: start, end: end, method: "listEvents"),
              let resolvedCalendar = resolveCalendar(calendar, method: "listEvents") else {
            return []
        }

        return events(in: window, calendars: [resolvedCalendar]).map(eventSummary)
    }

    @objc(searchEvents:::)
    func searchEvents(_ query: String, _ start: String, _ end: String) -> [[String: Any]] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throwJavaScriptError("hs.calendar.searchEvents(): query must not be empty")
            return []
        }
        guard let window = queryWindow(start: start, end: end, method: "searchEvents") else { return [] }

        return events(in: window, calendars: nil)
            .filter { $0.title?.localizedCaseInsensitiveContains(trimmedQuery) == true }
            .map(eventSummary)
    }

    private func resolveCalendar(_ identifierOrTitle: String, method: String) -> EKCalendar? {
        let requested = identifierOrTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty else {
            throwJavaScriptError("hs.calendar.\(method)(): calendar must be an id or title")
            return nil
        }

        let calendars = eventStore.eventStore.calendars(for: .event)
        if let matchByIdentifier = calendars.first(where: { $0.calendarIdentifier == requested }) {
            return matchByIdentifier
        }

        let matchesByTitle = calendars.filter { $0.title == requested }
        if matchesByTitle.count == 1 { return matchesByTitle[0] }
        if matchesByTitle.count > 1 {
            let candidates = matchesByTitle
                .sorted { $0.calendarIdentifier < $1.calendarIdentifier }
                .map { "\($0.title) (\($0.calendarIdentifier))" }
                .joined(separator: ", ")
            throwJavaScriptError(
                "hs.calendar.\(method)(): Calendar title '\(requested)' is ambiguous; use an id. Candidates: \(candidates)"
            )
            return nil
        }

        throwJavaScriptError("hs.calendar.\(method)(): Calendar not found: \(requested)")
        return nil
    }

    private func events(
        in window: (start: Date, end: Date),
        calendars: [EKCalendar]?
    ) -> [EKEvent] {
        let predicate = eventStore.eventStore.predicateForEvents(
            withStart: window.start,
            end: window.end,
            calendars: calendars
        )
        return eventStore.eventStore.events(matching: predicate).sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
            if lhs.endDate != rhs.endDate { return lhs.endDate < rhs.endDate }
            if lhs.title != rhs.title { return (lhs.title ?? "") < (rhs.title ?? "") }
            return (lhs.eventIdentifier ?? lhs.calendarItemIdentifier) <
                (rhs.eventIdentifier ?? rhs.calendarItemIdentifier)
        }
    }

    private func eventSummary(_ event: EKEvent) -> [String: Any] {
        let occurrenceDate = event.occurrenceDate
        let recurring = Self.isRecurring(event)
        let organizer: Any
        if let eventOrganizer = event.organizer {
            organizer = participantSummary(eventOrganizer)
        } else {
            organizer = NSNull()
        }

        return [
            "id": event.eventIdentifier ?? event.calendarItemIdentifier,
            "title": event.title ?? "",
            "start": formatEventDate(event.startDate, allDay: event.isAllDay),
            "end": formatEventDate(event.endDate, allDay: event.isAllDay),
            "allDay": event.isAllDay,
            "location": event.location ?? NSNull(),
            "notes": event.notes ?? NSNull(),
            "url": event.url?.absoluteString ?? NSNull(),
            "attendees": (event.attendees ?? []).map(participantSummary),
            "organizer": organizer,
            "status": eventStatus(event.status),
            "availability": eventAvailability(event.availability),
            "recurring": recurring,
            "occurrenceStart": recurring
                ? formatEventDate(occurrenceDate ?? event.startDate, allDay: event.isAllDay)
                : NSNull(),
        ]
    }

    private func participantSummary(_ participant: EKParticipant) -> [String: Any] {
        [
            "name": participant.name ?? NSNull(),
            "url": participant.url.absoluteString,
            "status": participantStatus(participant.participantStatus),
            "role": participantRole(participant.participantRole),
            "type": participantType(participant.participantType),
            "currentUser": participant.isCurrentUser,
        ]
    }

    private func formatEventDate(_ date: Date, allDay: Bool) -> String {
        if allDay {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func eventStatus(_ status: EKEventStatus) -> String {
        switch status {
        case .none:      return "none"
        case .confirmed: return "confirmed"
        case .tentative: return "tentative"
        case .canceled:  return "canceled"
        @unknown default: return "none"
        }
    }

    private func eventAvailability(_ availability: EKEventAvailability) -> String {
        switch availability {
        case .notSupported: return "notSupported"
        case .busy:         return "busy"
        case .free:         return "free"
        case .tentative:    return "tentative"
        case .unavailable:  return "unavailable"
        @unknown default:   return "notSupported"
        }
    }

    private func participantStatus(_ status: EKParticipantStatus) -> String {
        switch status {
        case .unknown:    return "unknown"
        case .pending:    return "pending"
        case .accepted:   return "accepted"
        case .declined:   return "declined"
        case .tentative:  return "tentative"
        case .delegated:  return "delegated"
        case .completed:  return "completed"
        case .inProcess:  return "inProcess"
        @unknown default: return "unknown"
        }
    }

    private func participantRole(_ role: EKParticipantRole) -> String {
        switch role {
        case .unknown:        return "unknown"
        case .required:       return "required"
        case .optional:       return "optional"
        case .chair:          return "chair"
        case .nonParticipant: return "nonParticipant"
        @unknown default:     return "unknown"
        }
    }

    private func participantType(_ type: EKParticipantType) -> String {
        switch type {
        case .unknown:    return "unknown"
        case .person:     return "person"
        case .room:       return "room"
        case .resource:   return "resource"
        case .group:      return "group"
        @unknown default: return "unknown"
        }
    }

    private func queryWindow(start: String, end: String, method: String) -> (start: Date, end: Date)? {
        guard let startDate = parseInstant(start), let endDate = parseInstant(end) else {
            throwJavaScriptError(
                "hs.calendar.\(method)(): start and end must be valid ISO 8601 datetimes with an explicit UTC offset or Z"
            )
            return nil
        }
        guard startDate < endDate else {
            throwJavaScriptError("hs.calendar.\(method)(): end must be after start")
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let maximumEnd = calendar.date(byAdding: .year, value: 4, to: startDate),
              endDate <= maximumEnd else {
            throwJavaScriptError("hs.calendar.\(method)(): query window must not exceed four years")
            return nil
        }
        return (startDate, endDate)
    }

    private func parseInstant(_ value: String) -> Date? {
        let instantPattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"#
        guard value.range(of: instantPattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }

        if value.last != "Z" && value.last != "z" {
            let offset = value.suffix(6)
            guard let offsetHours = Int(offset.dropFirst().prefix(2)),
                  let offsetMinutes = Int(offset.suffix(2)),
                  offsetHours <= 14,
                  offsetMinutes <= 59,
                  offsetHours < 14 || offsetMinutes == 0 else {
                return nil
            }
        }

        let values = String(value.prefix(19))
            .components(separatedBy: CharacterSet(charactersIn: "-T:"))
            .compactMap(Int.init)
        guard values.count == 6 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = DateComponents(
            calendar: calendar,
            timeZone: .gmt,
            year: values[0],
            month: values[1],
            day: values[2],
            hour: values[3],
            minute: values[4],
            second: values[5]
        )
        guard let componentDate = calendar.date(from: components) else { return nil }
        let parsedComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: componentDate
        )
        guard parsedComponents.year == values[0],
              parsedComponents.month == values[1],
              parsedComponents.day == values[2],
              parsedComponents.hour == values[3],
              parsedComponents.minute == values[4],
              parsedComponents.second == values[5] else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) { return date }

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private func throwJavaScriptError(_ message: String) {
        guard let context = JSContext.current() else { return }
        context.exception = JSValue(newErrorFromMessage: message, in: context)
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

        guard let startDate = parseEventDate(
            startString,
            field: "start",
            allDay: allDay,
            in: options,
            method: "createEvent"
        ), let endDate = parseEventDate(
            endString,
            field: "end",
            allDay: allDay,
            in: options,
            method: "createEvent"
        ) else {
            return nil
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
            guard let parsedMinutes = parseAlarmMinutes(
                alarmsValue,
                in: options,
                method: "createEvent"
            ) else { return nil }
            alarmMinutes = parsedMinutes
        }

        let status = authorizationStatus()
        guard status == "fullAccess" else {
            return fail("Calendar access is \(status); grant Calendar access in Hammerspoon 2 and retry", in: options)
        }

        guard let calendar = resolveWritableCalendar(selector: calendarSelector, options: options) else {
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

        return Self.eventResult(event)
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

    private func parseEventDate(
        _ value: String,
        field: String,
        allDay: Bool,
        in options: JSValue,
        method: String
    ) -> Date? {
        if allDay {
            guard Self.isDateOnly(value), let date = Self.parseDateOnly(value) else {
                return fail(
                    "'\(field)' must be a date-only YYYY-MM-DD value when allDay is true",
                    in: options,
                    method: method
                )
            }
            return date
        }

        guard Self.hasExplicitUTCOffset(value) else {
            return fail(
                "'\(field)' must be an ISO 8601 datetime with a UTC offset or Z",
                in: options,
                method: method
            )
        }
        guard let date = Self.parseInstant(value) else {
            return fail(
                "'\(field)' must be a valid ISO 8601 datetime with a UTC offset or Z",
                in: options,
                method: method
            )
        }
        return date
    }

    private func parseAlarmMinutes(
        _ value: JSValue,
        in options: JSValue,
        method: String
    ) -> [Double]? {
        guard value.isArray,
              let lengthValue = value.objectForKeyedSubscript("length"),
              lengthValue.isNumber else {
            return fail(
                "'alarms' must be an array of non-negative minutes-before numbers",
                in: options,
                method: method
            )
        }

        let unsignedCount = lengthValue.toUInt32()
        guard unsignedCount <= UInt32(Int32.max) else {
            return fail(
                "'alarms' must be an array of non-negative minutes-before numbers",
                in: options,
                method: method
            )
        }

        var minutesBefore: [Double] = []
        for index in 0..<Int(unsignedCount) {
            guard let alarmValue = value.atIndex(index), alarmValue.isNumber else {
                return fail(
                    "'alarms' must contain only non-negative minutes-before numbers",
                    in: options,
                    method: method
                )
            }
            let minutes = alarmValue.toDouble()
            guard minutes.isFinite, minutes >= 0 else {
                return fail(
                    "'alarms' must contain only non-negative minutes-before numbers",
                    in: options,
                    method: method
                )
            }
            minutesBefore.append(minutes)
        }
        return minutesBefore
    }

    private func resolveWritableCalendar(
        selector: String?,
        options: JSValue,
        method: String = "createEvent"
    ) -> EKCalendar? {
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
                    return fail("Calendar '\(selector)' was not found", in: options, method: method)
                case 1:
                    calendar = titleMatches[0]
                default:
                    let candidates = titleMatches
                        .sorted { $0.calendarIdentifier < $1.calendarIdentifier }
                        .map { "\($0.title) (id: \($0.calendarIdentifier))" }
                        .joined(separator: ", ")
                    return fail(
                        "Calendar title '\(selector)' is ambiguous; retry with one of these ids: \(candidates)",
                        in: options,
                        method: method
                    )
                }
            }
        } else {
            calendar = store.defaultCalendarForNewEvents
            if calendar == nil {
                return fail(
                    "no default Calendar is configured; pass 'calendar' as an id or title",
                    in: options,
                    method: method
                )
            }
        }

        guard let calendar else { return nil }
        guard calendar.allowsContentModifications else {
            return fail(
                "Calendar '\(calendar.title)' (id: \(calendar.calendarIdentifier)) is read-only",
                in: options,
                method: method
            )
        }
        return calendar
    }

    private static func eventResult(_ event: EKEvent) -> [String: Any] {
        let persistedAlarmMinutes = (event.alarms ?? []).map { -$0.relativeOffset / 60 }

        return [
            "id": event.calendarItemIdentifier,
            "title": event.title ?? "",
            "start": event.isAllDay ? formatDateOnly(event.startDate) : formatInstant(event.startDate),
            "end": event.isAllDay ? formatDateOnly(event.endDate) : formatInstant(event.endDate),
            "allDay": event.isAllDay,
            "location": event.location ?? NSNull(),
            "notes": event.notes ?? NSNull(),
            "url": event.url?.absoluteString ?? NSNull(),
            "alarms": persistedAlarmMinutes,
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

    private func fail<T>(_ message: String, in value: JSValue, method: String = "createEvent") -> T? {
        setException(message, in: value, method: method)
        return nil
    }

    private func setException(_ message: String, in value: JSValue, method: String) {
        JSContext.current()?.exception = JSValue(
            newErrorFromMessage: "hs.calendar.\(method): \(message)",
            in: value.context
        )
    }

    private func fail(_ message: String, method: String) -> Bool {
        guard let context = JSContext.current() else { return false }
        context.exception = JSValue(
            newErrorFromMessage: "hs.calendar.\(method): \(message)",
            in: context
        )
        return false
    }

    private func eventForMutation(id: String) -> EKEvent? {
        let store = eventStore.eventStore
        return store.event(withIdentifier: id) ??
            (store.calendarItem(withIdentifier: id) as? EKEvent)
    }

    private static func isRecurring(_ event: EKEvent) -> Bool {
        event.occurrenceDate != nil || event.hasRecurrenceRules
    }

    @objc(updateEvent::)
    func updateEvent(_ id: String, _ fields: JSValue) -> [String: Any]? {
        let method = "updateEvent"
        let requestedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedID.isEmpty else {
            return fail("'id' must be a non-empty Event identifier", in: fields, method: method)
        }
        guard fields.isObject, !fields.isArray else {
            return fail("fields object required", in: fields, method: method)
        }

        let writableFields = [
            "calendar", "title", "start", "end", "allDay",
            "location", "notes", "url", "alarms",
        ]
        guard writableFields.contains(where: { Self.property($0, in: fields) != nil }) else {
            return fail("at least one writable field is required", in: fields, method: method)
        }

        if let titleValue = Self.property("title", in: fields) {
            guard titleValue.isString,
                  let title = titleValue.toString(),
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return fail("'title' must be a non-empty string", in: fields, method: method)
            }
        }

        if let calendarValue = Self.property("calendar", in: fields) {
            guard calendarValue.isString,
                  let selector = calendarValue.toString(),
                  !selector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return fail("'calendar' must be a non-empty Calendar id or title", in: fields, method: method)
            }
        }

        var suppliedDateStrings: [String: String] = [:]
        for field in ["start", "end"] {
            guard let value = Self.property(field, in: fields) else { continue }
            guard value.isString, let string = value.toString() else {
                return fail("'\(field)' must be a string", in: fields, method: method)
            }
            suppliedDateStrings[field] = string
        }

        for field in ["location", "notes"] {
            guard let value = Self.property(field, in: fields) else { continue }
            guard value.isNull || value.isString else {
                return fail("'\(field)' must be a string or null", in: fields, method: method)
            }
        }

        var eventURL: URL?
        if let urlValue = Self.property("url", in: fields), !urlValue.isNull {
            guard urlValue.isString,
                  let urlString = urlValue.toString(),
                  let parsedURL = URL(string: urlString),
                  parsedURL.scheme != nil else {
                return fail("'url' must be an absolute URL or null", in: fields, method: method)
            }
            eventURL = parsedURL
        }

        var requestedAllDay: Bool?
        if let allDayValue = Self.property("allDay", in: fields) {
            guard allDayValue.isBoolean else {
                return fail("'allDay' must be a boolean", in: fields, method: method)
            }
            requestedAllDay = allDayValue.toBool()
        }

        var parsedDates: [String: Date] = [:]
        if let requestedAllDay {
            for field in ["start", "end"] {
                guard let string = suppliedDateStrings[field] else { continue }
                guard let date = parseEventDate(
                    string,
                    field: field,
                    allDay: requestedAllDay,
                    in: fields,
                    method: method
                ) else { return nil }
                parsedDates[field] = date
            }
        }

        var alarmMinutes: [Double]?
        if let alarmsValue = Self.property("alarms", in: fields) {
            guard let parsedMinutes = parseAlarmMinutes(
                alarmsValue,
                in: fields,
                method: method
            ) else { return nil }
            alarmMinutes = parsedMinutes
        }

        let status = authorizationStatus()
        guard status == "fullAccess" else {
            return fail(
                "Calendar access is \(status); grant Calendar access in Hammerspoon 2 and retry",
                in: fields,
                method: method
            )
        }

        guard let event = eventForMutation(id: requestedID) else {
            return fail("Event id '\(requestedID)' was not found", in: fields, method: method)
        }
        guard !Self.isRecurring(event) else {
            return fail(
                "recurring Event series editing is not supported in v1",
                in: fields,
                method: method
            )
        }
        guard event.calendar.allowsContentModifications else {
            return fail(
                "Calendar '\(event.calendar.title)' (id: \(event.calendar.calendarIdentifier)) is read-only",
                in: fields,
                method: method
            )
        }

        let targetAllDay = requestedAllDay ?? event.isAllDay
        if targetAllDay != event.isAllDay &&
            (Self.property("start", in: fields) == nil || Self.property("end", in: fields) == nil) {
            return fail(
                "changing 'allDay' requires both 'start' and 'end'",
                in: fields,
                method: method
            )
        }

        guard var targetStart = event.startDate, var targetEnd = event.endDate else {
            return fail("stored Event is missing a start or end", in: fields, method: method)
        }
        for field in ["start", "end"] {
            guard let string = suppliedDateStrings[field] else { continue }
            let parsed: Date
            if let prevalidated = parsedDates[field] {
                parsed = prevalidated
            } else {
                guard let parsedDate = parseEventDate(
                    string,
                    field: field,
                    allDay: targetAllDay,
                    in: fields,
                    method: method
                ) else { return nil }
                parsed = parsedDate
            }
            if field == "start" { targetStart = parsed } else { targetEnd = parsed }
        }
        guard targetEnd > targetStart else {
            return fail("'end' must be later than 'start'", in: fields, method: method)
        }

        var targetCalendar = event.calendar
        if let calendarValue = Self.property("calendar", in: fields),
           let selector = calendarValue.toString() {
            guard let resolved = resolveWritableCalendar(
                selector: selector,
                options: fields,
                method: method
            ) else {
                return nil
            }
            targetCalendar = resolved
        }

        if let titleValue = Self.property("title", in: fields) {
            event.title = titleValue.toString()
        }
        event.calendar = targetCalendar
        event.startDate = targetStart
        event.endDate = targetEnd
        event.isAllDay = targetAllDay
        if requestedAllDay != nil || !suppliedDateStrings.isEmpty {
            event.timeZone = targetAllDay ? nil : TimeZone(secondsFromGMT: 0)
        }

        for field in ["location", "notes"] {
            guard let value = Self.property(field, in: fields) else { continue }
            let string = value.isNull ? nil : value.toString()
            if field == "location" { event.location = string } else { event.notes = string }
        }
        if let urlValue = Self.property("url", in: fields) {
            event.url = urlValue.isNull ? nil : eventURL
        }
        if let alarmMinutes {
            for alarm in event.alarms ?? [] { event.removeAlarm(alarm) }
            for minutes in alarmMinutes {
                event.addAlarm(EKAlarm(relativeOffset: -minutes * 60))
            }
        }

        do {
            try eventStore.eventStore.save(event, span: .thisEvent, commit: true)
        } catch {
            return fail(
                "could not save Event: \(error.localizedDescription)",
                in: fields,
                method: method
            )
        }
        return Self.eventResult(event)
    }

    @objc func deleteEvent(_ id: String) -> Bool {
        let method = "deleteEvent"
        let requestedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedID.isEmpty else {
            return fail("'id' must be a non-empty Event identifier", method: method)
        }

        let status = authorizationStatus()
        guard status == "fullAccess" else {
            return fail(
                "Calendar access is \(status); grant Calendar access in Hammerspoon 2 and retry",
                method: method
            )
        }
        guard let event = eventForMutation(id: requestedID) else {
            return fail("Event id '\(requestedID)' was not found", method: method)
        }
        guard !Self.isRecurring(event) else {
            return fail("recurring Event series deletion is not supported in v1", method: method)
        }
        guard event.calendar.allowsContentModifications else {
            return fail(
                "Calendar '\(event.calendar.title)' (id: \(event.calendar.calendarIdentifier)) is read-only",
                method: method
            )
        }

        do {
            // Recurring Events are rejected above, so .thisEvent cannot imply a guessed series span.
            try eventStore.eventStore.remove(event, span: .thisEvent, commit: true)
        } catch {
            return fail("could not delete Event: \(error.localizedDescription)", method: method)
        }
        return true
    }
}
