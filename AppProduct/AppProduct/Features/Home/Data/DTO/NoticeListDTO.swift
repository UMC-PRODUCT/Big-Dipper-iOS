//
//  NoticeListRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/11/26.
//

import Foundation

/// 홈 화면 최근 공지 Request DTO
struct NoticeListRequestDTO {
    /// 기수 ID (필수)
    let gisuId: Int
    /// 지부 ID (null이면 해당 기수의 전체 공지 조회)
    let chapterId: Int?
    /// 학교 ID (null이면 지부 레벨까지만 필터링)
    let schoolId: Int?
    /// 파트 (null이면 파트 구분 없이 조회)
    let part: UMCPartType?
    /// 대상 역할 하한선 (필수). 일반 챌린저 공지는 `CHALLENGER`,
    /// 운영진 공지는 `CENTRAL_MEMBER` / `SCHOOL_CORE` / `SCHOOL_PART_LEADER`.
    let noticeTab: String
    /// 페이지 번호 (0부터 시작)
    let page: Int
    /// 페이지 크기
    let size: Int
    /// 정렬 기준
    let sort: [String]

    init(
        gisuId: Int,
        chapterId: Int? = nil,
        schoolId: Int? = nil,
        part: UMCPartType? = nil,
        noticeTab: String = "CHALLENGER",
        page: Int = 0,
        size: Int = 10,
        sort: [String] = ["createdAt,DESC"]
    ) {
        self.gisuId = gisuId
        self.chapterId = chapterId
        self.schoolId = schoolId
        self.part = part
        self.noticeTab = noticeTab
        self.page = page
        self.size = size
        self.sort = sort
    }

    /// Query Parameter Dictionary 변환
    var toParameters: [String: Any] {
        var params: [String: Any] = [
            "gisuId": gisuId,
            "noticeTab": noticeTab,
            "page": page,
            "size": size
        ]
        if !sort.isEmpty {
            params["sort"] = sort
        }
        if let chapterId { params["chapterId"] = chapterId }
        if let schoolId { params["schoolId"] = schoolId }
        if let part { params["part"] = part.apiValue }
        return params
    }
}

/// 홈 화면 최근 공지 Response DTO
struct NoticeListResponseDTO: Codable {
    let id: String
    let noticeId: Int
    let title: String
    let content: String
    let shouldSendNotification: Bool
    let viewCount: String
    let createdAt: String
    /// 서버 응답은 targetInfo를 단일 객체로 내려줍니다.
    let targetInfo: TargetInfoDTO
    let authorChallengerId: String
    let authorNickname: String
    let authorName: String

    private enum CodingKeys: String, CodingKey {
        case id
        case noticeId
        case title
        case content
        case shouldSendNotification
        case viewCount
        case createdAt
        case targetInfo
        case authorChallengerId
        case authorNickname
        case authorName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedId = try container.decodeStringFlexibleIfPresent(forKey: .id) ?? "0"
        let decodedNoticeId = try container.decodeIntFlexibleIfPresent(forKey: .noticeId)

        self.id = decodedId
        self.noticeId = decodedNoticeId ?? Int(decodedId) ?? 0
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.shouldSendNotification = try container.decodeBoolFlexibleIfPresent(forKey: .shouldSendNotification) ?? false
        self.viewCount = try container.decodeStringFlexibleIfPresent(forKey: .viewCount) ?? "0"
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.targetInfo = try container.decodeIfPresent(TargetInfoDTO.self, forKey: .targetInfo)
            ?? TargetInfoDTO(targetGisuId: 0, targetChapterId: nil, targetSchoolId: nil, targetParts: nil as [UMCPartType]?)
        self.authorChallengerId = try container.decodeStringFlexibleIfPresent(forKey: .authorChallengerId) ?? "0"
        self.authorNickname = try container.decodeIfPresent(String.self, forKey: .authorNickname) ?? ""
        self.authorName = try container.decodeIfPresent(String.self, forKey: .authorName) ?? ""
    }
}

// MARK: - toDomain

extension NoticeListResponseDTO {
    /// DTO → RecentNoticeData 변환
    func toRecentNoticeData() -> RecentNoticeData {
        let category: RecentCategory
        if targetInfo.targetSchoolId != nil {
            category = .univ
        } else if targetInfo.targetChapterId != nil {
            category = .oranization
        } else {
            category = .operationsTeam
        }

        let date = createdAt.toISO8601Date()

        return RecentNoticeData(
            noticeId: noticeId,
            category: category,
            title: title,
            createdAt: date
        )
    }
}

// MARK: - TargetInfoDTO

struct TargetInfoDTO: Codable {
    let targetGisuId: Int
    let targetChapterId: Int?
    let targetSchoolId: Int?
    let targetParts: [UMCPartType]?

    private enum CodingKeys: String, CodingKey {
        case targetGisuId
        case targetChapterId
        case targetSchoolId
        case targetParts
    }

    init(
        targetGisuId: Int,
        targetChapterId: Int?,
        targetSchoolId: Int?,
        targetParts: UMCPartType?
    ) {
        self.targetGisuId = targetGisuId
        self.targetChapterId = targetChapterId
        self.targetSchoolId = targetSchoolId
        self.targetParts = targetParts.map { [$0] }
    }

    init(
        targetGisuId: Int,
        targetChapterId: Int?,
        targetSchoolId: Int?,
        targetParts: [UMCPartType]?
    ) {
        self.targetGisuId = targetGisuId
        self.targetChapterId = targetChapterId
        self.targetSchoolId = targetSchoolId
        self.targetParts = targetParts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.targetGisuId = try container.decodeIntFlexibleIfPresent(forKey: .targetGisuId) ?? 0
        self.targetChapterId = try container.decodeIntFlexibleIfPresent(forKey: .targetChapterId)
        self.targetSchoolId = try container.decodeIntFlexibleIfPresent(forKey: .targetSchoolId)
        self.targetParts = try container.decodeIfPresent([UMCPartType].self, forKey: .targetParts)
    }

    /// 공지 생성/수정 요청 인코딩 시 null 규칙을 맞춥니다.
    /// - targetGisuId <= 0: null
    /// - targetParts 비어있음: null
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if targetGisuId > 0 {
            try container.encode(targetGisuId, forKey: .targetGisuId)
        } else {
            try container.encodeNil(forKey: .targetGisuId)
        }

        try container.encodeIfPresent(targetChapterId, forKey: .targetChapterId)
        try container.encodeIfPresent(targetSchoolId, forKey: .targetSchoolId)

        if let targetParts, !targetParts.isEmpty {
            try container.encode(targetParts, forKey: .targetParts)
        } else {
            try container.encodeNil(forKey: .targetParts)
        }
    }
}

// MARK: - PageDTO

/// Spring Boot Pageable 공통 응답 DTO (Offset 기반)
struct PageDTO<T: Codable>: Codable {
    /// 현재 페이지 항목 목록
    let content: [T]
    /// 현재 페이지 번호 (0부터 시작)
    let page: String
    /// 한 페이지 항목 수
    let size: String
    /// 전체 항목 수
    let totalElements: String
    /// 전체 페이지 수
    let totalPages: String
    /// 다음 페이지 존재 여부
    let hasNext: Bool
    /// 이전 페이지 존재 여부
    let hasPrevious: Bool
}

private extension KeyedDecodingContainer {
    func decodeStringFlexibleIfPresent(forKey key: Key) throws -> String? {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(Int(value))
        }
        if let value = try? decode(Bool.self, forKey: key) {
            return String(value)
        }
        return nil
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

    func decodeBoolFlexibleIfPresent(forKey key: Key) throws -> Bool? {
        if let value = try? decode(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? decode(String.self, forKey: key) {
            switch value.lowercased() {
            case "true", "1", "y", "yes":
                return true
            case "false", "0", "n", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}

private extension String {
    func toISO8601Date() -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: self) {
            return parsed
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self) ?? Date()
    }
}
