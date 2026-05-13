//
//  ChallengerMemeberDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/11/26.
//

import Foundation

/// 현재 기수 패널티 조회 Response DTO
struct ChallengerMemberDTO: Codable {

    // MARK: - Property

    /// 챌린저 고유 ID
    let challengerId: Int
    /// 멤버 고유 ID (서버 응답 String 기준)
    let memberId: String
    /// 기수 번호 (예: 9, 10)
    let gisu: Int
    /// 서버 기수 식별 ID
    let gisuId: Int
    /// 지부 ID
    let chapterId: Int?
    /// 지부명
    let chapterName: String?
    /// 소속 파트 (API 문자열: "PLAN", "IOS" 등)
    let part: String
    /// 포인트 상세 목록 (패널티 + 우수 포인트 포함)
    let challengerPoints: [ChallengerPointDTO]
    /// 이름
    let name: String
    /// 닉네임
    let nickname: String
    /// 이메일
    let email: String?
    /// 학교 ID
    let schoolId: Int
    /// 학교 이름
    let schoolName: String
    /// 프로필 이미지 URL
    let profileImageLink: String?
    /// 챌린저 역할 목록
    let roles: [ChallengerRoleDTO]
    /// 멤버 상태 (ACTIVE / INACTIVE / WITHDRAWN)
    let status: MemberStatus

    private enum CodingKeys: String, CodingKey {
        case challengerId
        case memberId
        case gisu
        case gisuId
        case chapterId
        case chapterName
        case part
        case challengerPoints
        case name
        case nickname
        case email
        case schoolId
        case schoolName
        case profileImageLink
        case roles
        case status
    }

    private enum FallbackCodingKeys: String, CodingKey {
        case memberStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerId = try container.decodeIntFlexibleIfPresent(forKey: .challengerId) ?? 0
        memberId = try container.decodeFlexibleStringIfPresent(forKey: .memberId) ?? ""
        gisu = try container.decodeIntFlexibleIfPresent(forKey: .gisu) ?? 0
        gisuId = try container.decodeIntFlexibleIfPresent(forKey: .gisuId) ?? 0
        chapterId = try container.decodeIntFlexibleIfPresent(forKey: .chapterId)
        chapterName = try container.decodeIfPresent(String.self, forKey: .chapterName)
        part = try container.decodeIfPresent(String.self, forKey: .part) ?? ""
        challengerPoints = try container.decodeIfPresent([ChallengerPointDTO].self, forKey: .challengerPoints)
            ?? decoder.decodePointsArrayFallback()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email)
        schoolId = try container.decodeIntFlexibleIfPresent(forKey: .schoolId) ?? 0
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        profileImageLink = try container.decodeIfPresent(String.self, forKey: .profileImageLink)
        roles = try container.decodeIfPresent([ChallengerRoleDTO].self, forKey: .roles) ?? []
        let fallbackContainer = try decoder.container(keyedBy: FallbackCodingKeys.self)
        status = try container.decodeIfPresent(MemberStatus.self, forKey: .status)
            ?? (try fallbackContainer.decodeIfPresent(MemberStatus.self, forKey: .memberStatus))
            ?? .inactive
    }
}

struct ChallengerRoleDTO: Codable {
    let challengerRoleId: String
    let challengerId: String
    let roleType: ManagementTeam
    let organizationType: OrganizationType
    let organizationId: String?
    let responsiblePart: String?
    let gisuId: String
    let gisu: String?

    private enum CodingKeys: String, CodingKey {
        case challengerRoleId
        case challengerId
        case roleType
        case organizationType
        case organizationId
        case responsiblePart
        case gisuId
        case gisu
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challengerRoleId = try container.decodeFlexibleString(forKey: .challengerRoleId)
        challengerId = try container.decodeFlexibleString(forKey: .challengerId)
        roleType = try container.decode(ManagementTeam.self, forKey: .roleType)
        organizationType = try container.decode(OrganizationType.self, forKey: .organizationType)
        organizationId = try container.decodeFlexibleStringIfPresent(forKey: .organizationId)
        responsiblePart = try container.decodeIfPresent(String.self, forKey: .responsiblePart)
        gisuId = try container.decodeFlexibleString(forKey: .gisuId)
        gisu = try container.decodeFlexibleStringIfPresent(forKey: .gisu)
    }
}

private struct DynamicCodingKey: CodingKey {
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
    func decodePointsArrayFallback() throws -> [ChallengerPointDTO] {
        let container = try self.container(keyedBy: DynamicCodingKey.self)
        guard let key = DynamicCodingKey(stringValue: "points") else {
            return []
        }
        return try container.decodeIfPresent([ChallengerPointDTO].self, forKey: key) ?? []
    }
}

// MARK: - ChallengerPointDTO

/// 포인트 상세 항목 DTO
struct ChallengerPointDTO: Codable {
    /// 포인트 고유 ID
    let id: Int
    /// 포인트 유형 (BEST_WORKBOOK / WARNING / OUT)
    let pointType: PointType
    /// 부여된 포인트 값
    let point: Double
    /// 사유 설명
    let description: String
    /// 생성 시각 (ISO 8601 형식)
    let createdAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case pointType
        case point
        case description
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIntFlexibleIfPresent(forKey: .id) ?? 0
        let rawPointType = try container.decodeIfPresent(String.self, forKey: .pointType)
        pointType = rawPointType.flatMap { PointType(rawValue: $0) } ?? .warning
        if let pointValue = try? container.decode(Double.self, forKey: .point) {
            point = pointValue
        } else if let intValue = try? container.decode(Int.self, forKey: .point) {
            point = Double(intValue)
        } else {
            let stringValue = try container.decodeIfPresent(String.self, forKey: .point) ?? "0"
            guard let parsed = Double(stringValue) else {
                throw DecodingError.typeMismatch(
                    Double.self,
                    DecodingError.Context(
                        codingPath: container.codingPath + [CodingKeys.point],
                        debugDescription: "Expected Double or String-number for key 'point'"
                    )
                )
            }
            point = parsed
        }
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

// MARK: - PointType

/// 포인트 유형 열거형
enum PointType: String, Codable {
    case bestWorkbook = "BEST_WORKBOOK"
    case warning = "WARNING"
    case out = "OUT"
    case custom = "CUSTOM"
    case blogChallenge = "BLOG_CHALLENGE"
    case bestWorkbookV2 = "BEST_WORKBOOK_V2"
    case umcEventReview = "UMC_EVENT_REVIEW"
    case peerReviewSubmission = "PEER_REVIEW_SUBMISSION"
    case noWorkbookMission = "NO_WORKBOOK_MISSION"
    case studyLate = "STUDY_LATE"
    case studyAbsent = "STUDY_ABSENT"
    case eventLate = "EVENT_LATE"
    case eventEarlyLeave = "EVENT_EARLY_LEAVE"
    case eventLateCancel = "EVENT_LATE_CANCEL"
    case eventNoShow = "EVENT_NO_SHOW"
    case partLeadFeedbackLate = "PART_LEAD_FEEDBACK_LATE"
    case schoolCoreMeetingAbsent = "SCHOOL_CORE_MEETING_ABSENT"
    case schoolCoreTaskNotCompleted = "SCHOOL_CORE_TASK_NOT_COMPLETED"

    var isPenalty: Bool {
        switch self {
        case .bestWorkbook, .bestWorkbookV2, .blogChallenge, .umcEventReview, .peerReviewSubmission:
            return false
        default:
            return true
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(Int(value))
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected String/Int/Double for key '\(key.stringValue)'"
            )
        )
    }

    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeFlexibleString(forKey: key)
    }

    func decodeIntFlexible(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key),
           let intValue = Int(value) {
            return intValue
        }
        if let value = try? decode(Double.self, forKey: key) {
            return Int(value)
        }
        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Int/String-number/Double for key '\(key.stringValue)'"
            )
        )
    }

    func decodeIntFlexibleIfPresent(forKey key: Key) throws -> Int? {
        if (try? decodeNil(forKey: key)) == true {
            return nil
        }
        return try? decodeIntFlexible(forKey: key)
    }
}

// MARK: - toDomain

extension ChallengerMemberDTO {
    func toMemberProfileSummary() -> MemberProfileSummary {
        let resolvedRoleName = ManagementTeam.highestPriority(in: roles.map(\.roleType))?.korean ?? "챌린저"

        return MemberProfileSummary(
            memberId: memberId,
            name: name,
            nickname: nickname,
            generation: gisu,
            organizationName: chapterName ?? schoolName,
            roleName: resolvedRoleName,
            profileImageURL: profileImageLink
        )
    }

    /// DTO → GenerationData 변환 (홈 화면 상벌점 카드용)
    ///
    /// - Parameter gisuId: MyProfileDTO의 RoleDTO에서 전달받은 기수 식별 ID
    /// - Returns: 상점/벌점이 포함된 `GenerationData`
    func toGenerationData(gisuId: Int) -> GenerationData {
        let maxRecentLogs = 3

        // ISO 8601 파싱 (소수 초 유무 모두 허용)
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let internetDateTimeFormatter = ISO8601DateFormatter()
        internetDateTimeFormatter.formatOptions = [.withInternetDateTime]

        func parseISODate(_ raw: String) -> Date? {
            fractionalFormatter.date(from: raw) ?? internetDateTimeFormatter.date(from: raw)
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM.dd"

        let penaltyDisplayFormatter = DateFormatter()
        penaltyDisplayFormatter.dateFormat = "yyyy.MM.dd"

        // 벌점/상점 분리
        let penaltyPoints = challengerPoints.filter { $0.pointType.isPenalty }
        let rewardPoints = challengerPoints.filter { !$0.pointType.isPenalty }

        let penaltyTotal = penaltyPoints.reduce(0) { $0 + Int($1.point) }
        let rewardTotal = rewardPoints.reduce(0) { $0 + Int($1.point) }

        // 상벌점 통합 기록 (최신순 정렬, 전체)
        let allPointsSorted = challengerPoints
            .sorted { lhs, rhs in
                let lhsDate = parseISODate(lhs.createdAt) ?? .distantPast
                let rhsDate = parseISODate(rhs.createdAt) ?? .distantPast
                return lhsDate > rhsDate
            }

        let pointLogs = allPointsSorted.map { point in
            let dateString: String
            if let date = parseISODate(point.createdAt) {
                dateString = displayFormatter.string(from: date)
            } else {
                dateString = point.createdAt
            }
            let isReward = !point.pointType.isPenalty
            return PointLogItem(
                reason: point.description,
                date: dateString,
                point: isReward ? Int(point.point) : -Int(point.point),
                isReward: isReward
            )
        }

        // 기존 penaltyLogs 유지 (하위호환)
        let recentPenaltyPoints = penaltyPoints
            .sorted { lhs, rhs in
                let lhsDate = parseISODate(lhs.createdAt) ?? .distantPast
                let rhsDate = parseISODate(rhs.createdAt) ?? .distantPast
                return lhsDate > rhsDate
            }
            .prefix(maxRecentLogs)

        let penaltyLogs = recentPenaltyPoints.map { point in
            let dateString: String
            if let date = parseISODate(point.createdAt) {
                dateString = penaltyDisplayFormatter.string(from: date)
            } else {
                dateString = point.createdAt
            }
            return PenaltyInfoItem(
                reason: point.description,
                date: dateString,
                penaltyPoint: Int(point.point)
            )
        }

        return GenerationData(
            gisuId: gisuId,
            gen: gisu,
            penaltyPoint: penaltyTotal,
            rewardPoint: rewardTotal,
            pointLogs: Array(pointLogs),
            penaltyLogs: penaltyLogs
        )
    }
}
