import Foundation
import HomeDomain
import UMCFoundation

// MARK: - Main Response

/// 홈 화면(시즌/세대 카드) 구성을 위한 내 프로필 조회 응답 DTO
///
/// `GET /api/v1/member/me`
public struct MyProfileResponseDTO: Codable {

    // MARK: - Property

    public let id: String
    public let roles: [HomeRoleDTO]
    public let challengerRecords: [HomeChallengerRecordDTO]?

    private enum CodingKeys: String, CodingKey {
        case id
        case roles
        case challengerRecords
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        roles = try container.decodeIfPresent([HomeRoleDTO].self, forKey: .roles) ?? []
        challengerRecords = try container.decodeIfPresent(
            [HomeChallengerRecordDTO].self,
            forKey: .challengerRecords
        )
    }

    // MARK: - Function

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(roles, forKey: .roles)
        try container.encodeIfPresent(challengerRecords, forKey: .challengerRecords)
    }
}

// MARK: - HomeRoleDTO

/// 프로필 응답의 `roles[]` 항목 중 시즌 카드 구성에 필요한 기수 정보만 담는다.
public struct HomeRoleDTO: Codable {
    public let gisu: String?
    public let gisuId: String

    private enum CodingKeys: String, CodingKey {
        case gisu
        case gisuId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gisu = try container.decodeFlexibleStringIfPresent(forKey: .gisu)
        gisuId = try container.decodeFlexibleString(forKey: .gisuId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(gisu, forKey: .gisu)
        try container.encode(gisuId, forKey: .gisuId)
    }
}

// MARK: - HomeChallengerRecordDTO

/// 프로필 응답의 `challengerRecords[]` 항목 중 세대(페널티) 카드 구성에 필요한 정보만 담는다.
public struct HomeChallengerRecordDTO: Codable {
    public let gisu: String
    public let gisuId: String
    public let challengerPoints: [HomeChallengerPointDTO]

    private enum CodingKeys: String, CodingKey {
        case gisu
        case gisuId
        case challengerPoints
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gisu = try container.decodeFlexibleString(forKey: .gisu)
        gisuId = try container.decodeFlexibleString(forKey: .gisuId)
        challengerPoints = try container.decodeIfPresent(
            [HomeChallengerPointDTO].self,
            forKey: .challengerPoints
        ) ?? decoder.decodeHomePointsArrayFallback() ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gisu, forKey: .gisu)
        try container.encode(gisuId, forKey: .gisuId)
        try container.encode(challengerPoints, forKey: .challengerPoints)
    }
}

// MARK: - HomeChallengerPointDTO

/// 챌린저 기록의 `challengerPoints[]` 항목 DTO.
///
/// 서버 응답이 `challengerPoints` 키 대신 `points` 키로 내려오는 fallback 케이스도
/// `HomeChallengerRecordDTO` 디코더에서 처리한다.
public struct HomeChallengerPointDTO: Codable {
    public let id: String
    public let pointType: String
    public let point: Double
    public let description: String
    public let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case pointType
        case point
        case description
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        pointType = try container.decode(String.self, forKey: .pointType)
        point = try container.decodeDoubleFlexible(forKey: .point)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pointType, forKey: .pointType)
        try container.encode(point, forKey: .point)
        try container.encode(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Dynamic Coding Key (Fallback)

private struct HomeDynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension Decoder {
    /// `challengerPoints` 키가 누락되었을 때 `points` 키를 fallback으로 디코딩한다.
    func decodeHomePointsArrayFallback() -> [HomeChallengerPointDTO]? {
        guard let container = try? self.container(keyedBy: HomeDynamicCodingKey.self),
              let key = HomeDynamicCodingKey(stringValue: "points") else {
            return nil
        }
        return try? container.decodeIfPresent([HomeChallengerPointDTO].self, forKey: key)
    }
}

// MARK: - Domain Mapping

extension MyProfileResponseDTO {
    /// 역할(roles)/챌린저 기록(challengerRecords)에서 기수별 상벌점 현황을 구성한다.
    func toHomeGenerations() -> [HomeGeneration] {
        (challengerRecords ?? []).map { $0.toHomeGeneration() }
    }

    /// 역할과 챌린저 기록 양쪽에서 기수 번호(`gisu`)를 모아 합집합을 구성한다.
    func mergedGenerationNumbers() -> [String] {
        let recordGenerations = (challengerRecords ?? []).map(\.gisu)
        let roleGenerations = roles.compactMap(\.gisu)
        return Set(recordGenerations + roleGenerations)
            .filter { !$0.isEmpty && $0 != "0" }
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    /// 활동일 계산을 위해 기수 시작일을 조회해야 하는 대상 기수 ID 목록.
    func targetGisuIds() -> [String] {
        let recordGisuIds = (challengerRecords ?? []).map(\.gisuId)
        let roleGisuIds = roles.map(\.gisuId)
        return Array(Set(recordGisuIds + roleGisuIds).filter { !$0.isEmpty && $0 != "0" })
    }
}

extension HomeChallengerRecordDTO {
    /// 상점(보상) 유형 여부 판정에 사용하는 허용 목록.
    ///
    /// `ChallengerPointType.isReward`는 레거시 호환을 위해 `.warning`/`.out`도 양수 배점으로
    /// 유지되어 있어(``ChallengerPointType`` 참고) 그대로 재사용할 수 없다. 대신 실제 상점으로
    /// 취급하는 유형만 명시적으로 나열한다.
    private static let rewardPointTypes: Set<String> = [
        ChallengerPointType.bestWorkbook.rawValue,
        ChallengerPointType.bestWorkbookV2.rawValue,
        ChallengerPointType.blogChallenge.rawValue,
        ChallengerPointType.umcEventReview.rawValue,
        ChallengerPointType.peerReviewSubmission.rawValue,
    ]

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        formatter.timeZone = ServerDateTimeConverter.kstTimeZone
        formatter.locale = Locale(identifier: "ko_KR_POSIX")
        return formatter
    }()

    func toHomeGeneration() -> HomeGeneration {
        let sortedPoints = challengerPoints.sorted { lhs, rhs in
            let lhsDate = ServerDateTimeConverter.parseUTCDateTime(lhs.createdAt) ?? .distantPast
            let rhsDate = ServerDateTimeConverter.parseUTCDateTime(rhs.createdAt) ?? .distantPast
            return lhsDate > rhsDate
        }

        var rewardTotal = 0
        var penaltyTotal = 0

        let pointLogs = sortedPoints.map { point -> PointLog in
            let isReward = Self.rewardPointTypes.contains(point.pointType)
            let intPoint = Int(point.point)

            if isReward {
                rewardTotal += abs(intPoint)
            } else {
                penaltyTotal += abs(intPoint)
            }

            return PointLog(
                id: point.id,
                reason: point.description,
                date: Self.displayDateString(from: point.createdAt),
                point: intPoint,
                isReward: isReward
            )
        }

        return HomeGeneration(
            gisuId: gisuId,
            gen: gisu,
            penaltyPoint: penaltyTotal,
            rewardPoint: rewardTotal,
            pointLogs: pointLogs
        )
    }

    private static func displayDateString(from rawValue: String) -> String {
        guard let date = ServerDateTimeConverter.parseUTCDateTime(rawValue) else { return "" }
        return displayDateFormatter.string(from: date)
    }
}
