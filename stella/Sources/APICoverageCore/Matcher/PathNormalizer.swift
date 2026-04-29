import Foundation

public enum PathNormalizer {
    public static func normalize(_ rawArm: String) -> String {
        var working = rawArm
        if let queryIndex = working.firstIndex(of: "?") {
            working = String(working[..<queryIndex])
        }

        let pattern = #"\\\(([^)]+)\)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsString = working as NSString
        let matches = regex.matches(
            in: working,
            range: NSRange(location: 0, length: nsString.length)
        )

        var result = working
        for match in matches.reversed() {
            let inner = nsString.substring(with: match.range(at: 1))
            let identifier = inner.split(separator: ".").last.map(String.init) ?? inner
            let cleaned = identifier
                .split(separator: ",")
                .first
                .map { $0.trimmingCharacters(in: .whitespaces) } ?? identifier

            result = (result as NSString).replacingCharacters(
                in: match.range,
                with: "{\(cleaned)}"
            )
        }

        return result
    }
}
