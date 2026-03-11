import Foundation
import os.log

private let logger = Logger(subsystem: "com.kylefugere.Fiddlehead", category: "MeetingSplitter")

/// A chunk of transcript segments assigned to a specific calendar meeting.
struct MeetingSegment {
    let meeting: MeetingEvent
    let segments: [TranscriptSegment]

    var duration: TimeInterval {
        guard let first = segments.first, let last = segments.last else { return 0 }
        return last.endTime - first.startTime
    }
}

/// Pure-logic splitter that assigns transcript segments to calendar meetings
/// based on timestamp alignment. No API calls, no state.
enum MeetingSplitter {

    /// Splits a transcript across multiple meetings using calendar event boundaries.
    ///
    /// Returns `nil` when splitting isn't applicable (0–1 meetings overlap the recording),
    /// signaling the caller to use the normal single-note path.
    ///
    /// Gap segments (not covered by any meeting) are appended to the nearest meeting
    /// by time proximity.
    static func split(
        transcript: AssembledTranscript,
        meetings: [MeetingEvent],
        recordingStart: Date
    ) -> [MeetingSegment]? {
        guard meetings.count >= 2 else { return nil }
        guard !transcript.segments.isEmpty else { return nil }

        // Pass 1: Assign each segment to a meeting or mark as gap
        var assignments: [(segment: TranscriptSegment, meetingIndex: Int?)] = []

        for segment in transcript.segments {
            let midpoint = recordingStart.addingTimeInterval((segment.startTime + segment.endTime) / 2)

            let matchIndex = meetings.firstIndex { meeting in
                midpoint >= meeting.startDate && midpoint < meeting.endDate
            }

            assignments.append((segment, matchIndex))
        }

        // Pass 2: Assign gap segments to nearest meeting
        for i in assignments.indices where assignments[i].meetingIndex == nil {
            let midpoint = recordingStart.addingTimeInterval(
                (assignments[i].segment.startTime + assignments[i].segment.endTime) / 2
            )

            var bestIndex = 0
            var bestDistance = TimeInterval.greatestFiniteMagnitude

            for (j, meeting) in meetings.enumerated() {
                let distToStart = abs(midpoint.timeIntervalSince(meeting.startDate))
                let distToEnd = abs(midpoint.timeIntervalSince(meeting.endDate))
                let dist = min(distToStart, distToEnd)
                if dist < bestDistance {
                    bestDistance = dist
                    bestIndex = j
                }
            }

            assignments[i].meetingIndex = bestIndex
        }

        // Group consecutive segments by meeting, preserving order
        var result: [MeetingSegment] = []
        var currentMeetingIndex = assignments[0].meetingIndex!
        var currentSegments: [TranscriptSegment] = []

        for assignment in assignments {
            let idx = assignment.meetingIndex!
            if idx == currentMeetingIndex {
                currentSegments.append(assignment.segment)
            } else {
                result.append(MeetingSegment(
                    meeting: meetings[currentMeetingIndex],
                    segments: currentSegments
                ))
                currentMeetingIndex = idx
                currentSegments = [assignment.segment]
            }
        }
        // Flush last group
        result.append(MeetingSegment(
            meeting: meetings[currentMeetingIndex],
            segments: currentSegments
        ))

        // Merge non-consecutive groups for the same meeting
        // (e.g., if gap segments on both sides of a meeting got assigned to different meetings
        //  but some earlier gap also belongs to this meeting)
        var merged: [String: MeetingSegment] = [:]
        var order: [String] = []

        for segment in result {
            if var existing = merged[segment.meeting.id] {
                existing = MeetingSegment(
                    meeting: existing.meeting,
                    segments: existing.segments + segment.segments
                )
                merged[segment.meeting.id] = existing
            } else {
                merged[segment.meeting.id] = segment
                order.append(segment.meeting.id)
            }
        }

        let final = order.compactMap { merged[$0] }

        // If everything ended up in one meeting, no split needed
        guard final.count >= 2 else { return nil }

        logger.info("Split transcript into \(final.count) meeting segments")
        for seg in final {
            logger.info("  → \(seg.meeting.title): \(seg.segments.count) segments, \(String(format: "%.0f", seg.duration))s")
        }

        return final
    }
}
