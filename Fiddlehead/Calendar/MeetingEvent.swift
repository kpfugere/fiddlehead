import Foundation

/// Lightweight value type representing a calendar meeting.
struct MeetingEvent: Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let attendees: [String]
    let videoURL: URL?

    var attendeeCount: Int { attendees.count }

    func secondsUntilStart(from now: Date = Date()) -> TimeInterval {
        startDate.timeIntervalSince(now)
    }
}
