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
        let recurring = occurrenceDate != nil || event.hasRecurrenceRules
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
}
