import Foundation

public enum SnapshotEncoder {
    public static func encode(_ snapshot: CoverageSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    public static func decode(_ data: Data) throws -> CoverageSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CoverageSnapshot.self, from: data)
    }
}
