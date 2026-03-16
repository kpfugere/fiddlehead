@preconcurrency import EventKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "Calendar")

/// Reads calendar events via EventKit. Must stay @MainActor because EKEventStore
/// is not Sendable.
@MainActor
final class CalendarService {
    private let store = EKEventStore()

    // MARK: - Authorization

    var authorizationState: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// Request full calendar access (macOS 14+).
    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            logger.info("Calendar access \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Querying

    /// Returns meetings starting within the given time window that have 2+ attendees
    /// and a detectable video call URL.
    func upcomingMeetings(within window: TimeInterval = 120) -> [MeetingEvent] {
        guard authorizationState == .fullAccess else { return [] }

        let now = Date()
        let end = now.addingTimeInterval(window)

        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-300), end: end, calendars: nil)
        let events = store.events(matching: predicate)

        return events.compactMap { event -> MeetingEvent? in
            guard let attendees = event.attendees, attendees.count >= 2 else { return nil }
            guard let videoURL = extractVideoURL(from: event) else { return nil }

            let names = attendees.compactMap { $0.name ?? $0.url.absoluteString }

            return MeetingEvent(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled Meeting",
                startDate: event.startDate,
                endDate: event.endDate,
                attendees: names,
                videoURL: videoURL
            )
        }
    }

    /// Returns the currently-in-progress meeting with 2+ attendees, if any.
    /// Unlike `upcomingMeetings()`, does not require a video call URL.
    func currentMeeting() -> MeetingEvent? {
        guard authorizationState == .fullAccess else { return nil }

        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-7200), end: now.addingTimeInterval(60), calendars: nil
        )

        return store.events(matching: predicate)
            .filter { $0.startDate <= now && $0.endDate > now }
            .filter { ($0.attendees?.count ?? 0) >= 2 }
            .sorted { $0.startDate > $1.startDate }
            .compactMap { event -> MeetingEvent? in
                let names = event.attendees?.compactMap { $0.name ?? $0.url.absoluteString } ?? []
                return MeetingEvent(
                    id: event.eventIdentifier,
                    title: event.title ?? "Untitled Meeting",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    attendees: names,
                    videoURL: extractVideoURL(from: event)
                )
            }
            .first
    }

    /// Returns all meetings with 2+ attendees that overlap the given time window.
    /// Does not require a video call URL. Sorted by startDate ascending.
    func meetingsDuring(from start: Date, to end: Date) -> [MeetingEvent] {
        guard authorizationState == .fullAccess else { return [] }

        let predicate = store.predicateForEvents(
            withStart: start.addingTimeInterval(-300), end: end, calendars: nil
        )

        return store.events(matching: predicate)
            .filter { ($0.attendees?.count ?? 0) >= 2 }
            .filter { $0.endDate > start && $0.startDate < end }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                let names = event.attendees?.compactMap { $0.name ?? $0.url.absoluteString } ?? []
                return MeetingEvent(
                    id: event.eventIdentifier,
                    title: event.title ?? "Untitled Meeting",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    attendees: names,
                    videoURL: extractVideoURL(from: event)
                )
            }
    }

    // MARK: - Private

    /// Search event notes, location, and URL for known video call patterns.
    private func extractVideoURL(from event: EKEvent) -> URL? {
        let sources = [
            event.notes,
            event.location,
            event.url?.absoluteString
        ].compactMap { $0 }

        let patterns = [
            "https?://[\\w.-]*zoom\\.us/j/[\\w?=&-]+",
            "https?://meet\\.google\\.com/[a-z-]+",
            "https?://teams\\.microsoft\\.com/l/meetup-join/[\\w%/.@?=&-]+"
        ]

        for source in sources {
            for pattern in patterns {
                if let range = source.range(of: pattern, options: .regularExpression) {
                    return URL(string: String(source[range]))
                }
            }
        }

        return nil
    }
}
