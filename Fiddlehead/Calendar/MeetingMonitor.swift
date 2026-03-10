import Combine
import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "MeetingMonitor")

/// Polls the calendar for upcoming meetings and publishes when one is imminent.
@MainActor
final class MeetingMonitor: ObservableObject {
    @Published var upcomingMeeting: MeetingEvent?
    @Published var isShowingPrompt = false
    @Published var calendarAuthorized = false

    private let calendarService = CalendarService()
    private var pollTask: Task<Void, Never>?
    private var dismissedEventIDs = Set<String>()

    /// Start polling for upcoming meetings.
    func startMonitoring() {
        guard pollTask == nil else { return }

        calendarAuthorized = calendarService.authorizationState == .fullAccess

        if !calendarAuthorized {
            Task {
                calendarAuthorized = await calendarService.requestAccess()
                if calendarAuthorized {
                    beginPolling()
                }
            }
        } else {
            beginPolling()
        }
    }

    /// Stop polling.
    func stopMonitoring() {
        pollTask?.cancel()
        pollTask = nil
        upcomingMeeting = nil
        isShowingPrompt = false
    }

    /// User dismissed the meeting prompt — don't show it again for this event.
    func dismissMeeting(_ meeting: MeetingEvent) {
        dismissedEventIDs.insert(meeting.id)
        isShowingPrompt = false
        upcomingMeeting = nil
        logger.info("Meeting dismissed: \(meeting.title, privacy: .public)")
    }

    /// User accepted the meeting prompt — recording will start.
    func acceptMeeting(_ meeting: MeetingEvent) {
        dismissedEventIDs.insert(meeting.id)
        isShowingPrompt = false
        logger.info("Meeting accepted: \(meeting.title, privacy: .public)")
    }

    /// Called when recording ends — allows next meeting to prompt.
    func recordingEnded() {
        upcomingMeeting = nil
    }

    // MARK: - Private

    private func beginPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkForMeetings()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        logger.info("Meeting polling started")
    }

    private func checkForMeetings() {
        let meetings = calendarService.upcomingMeetings(within: 120)
        let now = Date()

        // Find the soonest meeting that hasn't been dismissed and isn't too far past
        let candidate = meetings
            .filter { !dismissedEventIDs.contains($0.id) }
            .filter { $0.secondsUntilStart(from: now) > -300 } // not more than 5 min past
            .sorted { $0.startDate < $1.startDate }
            .first

        guard let meeting = candidate else {
            if isShowingPrompt {
                isShowingPrompt = false
                upcomingMeeting = nil
            }
            return
        }

        let secondsUntil = meeting.secondsUntilStart(from: now)

        // Show prompt when meeting is within 60 seconds of starting (or just started)
        if secondsUntil <= 60 && secondsUntil > -300 {
            if upcomingMeeting?.id != meeting.id {
                upcomingMeeting = meeting
                isShowingPrompt = true
                logger.info("Showing prompt for: \(meeting.title, privacy: .public) (starts in \(Int(secondsUntil))s)")
            }
        }
    }
}
