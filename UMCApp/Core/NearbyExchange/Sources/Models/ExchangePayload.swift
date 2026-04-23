import Foundation

// Android 크로스 플랫폼 교환 포맷 확정 스키마 (PRD v3 기반)
// iOS 측 최소 필드 명세 — 서버팀 협의 후 `profile`, `contacts`, `assets` 등 확장 예정
public struct ExchangePayload: Codable, Sendable, Equatable {

    // MARK: - Property

    public let cardID: String
    public let ownerName: String
    public let usdzURL: URL
    public let timestamp: Date
    /// 스키마 버전. BLE 광고 페이로드의 version 1B와 동일한 값.
    public let version: Int

    // MARK: - Init

    /// HTTPS URL만 허용. HTTP 또는 다른 scheme이면 `NearbyError.invalidPayload`를 throw.
    public init(
        cardID: String,
        ownerName: String,
        usdzURL: URL,
        timestamp: Date = Date(),
        version: Int = 1
    ) throws {
        guard usdzURL.scheme?.lowercased() == "https" else {
            throw NearbyError.invalidPayload("usdzURL must use HTTPS scheme")
        }
        self.cardID = cardID
        self.ownerName = ownerName
        self.usdzURL = usdzURL
        self.timestamp = timestamp
        self.version = version
    }

    // MARK: - Function

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> ExchangePayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExchangePayload.self, from: data)
    }
}

/// BLE 2단계 광고 페이로드 (PRD Q2 결정: Service UUID 16B + cardUUID prefix 8B + version 1B + flags 1B)
/// 풀 JSON은 GATT 또는 서버 fetch로 수신.
public struct BLEAdvertisementPayload: Sendable {

    // MARK: - Property

    public let cardUUIDPrefix: Data   // 8 bytes
    public let version: UInt8         // 1 byte
    public let flags: UInt8           // 1 byte (기수 6bit, 파트 4bit)

    // MARK: - Init

    public init(cardUUIDPrefix: Data, version: UInt8, flags: UInt8) {
        self.cardUUIDPrefix = cardUUIDPrefix
        self.version = version
        self.flags = flags
    }
}
