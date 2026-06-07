//
//  NoticePostRequestDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import UMCFoundation

// MARK: - Post Notice
/// 공지 생성 요청 DTO
public struct PostNoticeRequestDTO: Encodable {
    /// 공지 제목
    public let title: String
    /// 공지 본문
    public let content: String
    /// 알림 발송 여부
    public let shouldNotify: Bool
    /// 공지 대상 정보
    public let targetInfo: TargetInfoDTO
}

// MARK: - Create Notice Response
/// 공지 생성 응답 DTO
public struct NoticeCreateResponseDTO: Codable {
    /// 생성된 공지 ID
    public let noticeId: String

    private enum CodingKeys: String, CodingKey {
        case noticeId
    }

    /// noticeId가 String 또는 Int로 올 수 있어 유연하게 디코딩
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try? container.decode(String.self, forKey: .noticeId) {
            self.noticeId = id
        } else if let id = try? container.decode(Int.self, forKey: .noticeId) {
            self.noticeId = String(id)
        } else {
            self.noticeId = ""
        }
    }
}

// MARK: - Add Images Response
/// 공지 이미지 추가 응답 DTO
public struct NoticeAddImagesResponseDTO: Codable {
    /// 추가된 이미지 ID 목록
    public let imageIds: [String]

    private enum CodingKeys: String, CodingKey {
        case imageIds
    }

    /// imageIds가 [String] 또는 [Int]로 올 수 있어 유연하게 디코딩
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let ids = try? container.decode([String].self, forKey: .imageIds) {
            self.imageIds = ids
            return
        }
        if let ids = try? container.decode([Int].self, forKey: .imageIds) {
            self.imageIds = ids.map(String.init)
            return
        }
        self.imageIds = []
    }
}

// MARK: - TargetInfoDTO

public struct TargetInfoDTO: Codable {
    public let targetGisuId: String
    public let targetChapterId: String?
    public let targetSchoolId: String?
    public let targetParts: [UMCPartType]?

    private enum CodingKeys: String, CodingKey {
        case targetGisuId
        case targetChapterId
        case targetSchoolId
        case targetParts
    }

    public init(
        targetGisuId: String,
        targetChapterId: String?,
        targetSchoolId: String?,
        targetParts: UMCPartType?
    ) {
        self.targetGisuId = targetGisuId
        self.targetChapterId = targetChapterId
        self.targetSchoolId = targetSchoolId
        self.targetParts = targetParts.map { [$0] }
    }

    public init(
        targetGisuId: String,
        targetChapterId: String?,
        targetSchoolId: String?,
        targetParts: [UMCPartType]?
    ) {
        self.targetGisuId = targetGisuId
        self.targetChapterId = targetChapterId
        self.targetSchoolId = targetSchoolId
        self.targetParts = targetParts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.targetGisuId = container.decodeFlexibleOptionalString(forKey: .targetGisuId) ?? "0"
        self.targetChapterId = container.decodeFlexibleOptionalString(forKey: .targetChapterId)
        self.targetSchoolId = container.decodeFlexibleOptionalString(forKey: .targetSchoolId)
        self.targetParts = try container.decodeIfPresent([UMCPartType].self, forKey: .targetParts)
    }

    /// 공지 생성/수정 요청 인코딩 시 null 규칙을 맞춥니다.
    /// - targetGisuId가 "0" 이하(빈 문자열 또는 0): null
    /// - targetParts 비어있음: null
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let gisuIdInt = Int(targetGisuId) ?? 0
        if gisuIdInt > 0 {
            try container.encode(gisuIdInt, forKey: .targetGisuId)
        } else {
            try container.encodeNil(forKey: .targetGisuId)
        }

        if let chapterId = targetChapterId, let intVal = Int(chapterId) {
            try container.encode(intVal, forKey: .targetChapterId)
        } else {
            try container.encodeNil(forKey: .targetChapterId)
        }

        if let schoolId = targetSchoolId, let intVal = Int(schoolId) {
            try container.encode(intVal, forKey: .targetSchoolId)
        } else {
            try container.encodeNil(forKey: .targetSchoolId)
        }

        if let targetParts, !targetParts.isEmpty {
            try container.encode(targetParts, forKey: .targetParts)
        } else {
            try container.encodeNil(forKey: .targetParts)
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleOptionalString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(Int(value))
        }
        return nil
    }
}
