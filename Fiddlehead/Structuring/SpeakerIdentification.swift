import Foundation

enum SpeakerIdentification {
    /// Parse the `<!-- speakers: Speaker 2=Name, Speaker 3=Name -->` comment
    /// appended by the structuring LLM. Returns a dictionary mapping generic labels to identified names.
    static func extractMappings(from content: String) -> [String: String] {
        guard let range = content.range(of: #"<!-- speakers: (.+?) -->"#, options: .regularExpression) else {
            return [:]
        }

        let match = String(content[range])
        let inner = match
            .replacingOccurrences(of: "<!-- speakers: ", with: "")
            .replacingOccurrences(of: " -->", with: "")

        var map: [String: String] = [:]
        for pair in inner.split(separator: ",") {
            let parts = pair.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                if !key.isEmpty && !value.isEmpty {
                    map[key] = value
                }
            }
        }
        return map
    }

    /// Remove the speakers comment from content so it doesn't appear in the saved note.
    static func stripComment(from content: String) -> String {
        content.replacingOccurrences(
            of: #"\n?<!-- speakers: .+? -->\n?"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .newlines)
    }
}
