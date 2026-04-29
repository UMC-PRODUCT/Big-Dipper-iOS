//
//  ChallengerSearchDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation

// MARK: - Request

/// 챌린저 커서 검색 요청 DTO
///
/// `GET /api/v1/challenger/search/cursor` 엔드포인트의 Query Parameter
struct ChallengerSearchRequestDTO {
    /// 이전 페이지의 마지막 챌린저 ID (첫 페이지 조회 시 nil)
    let cursor: Int?
    /// 한 페이지에 조회할 항목 수 (기본값 50, 최대 50)
    let size: Int
    /// 이름 또는 닉네임 통합 검색 키워드
    let keyword: String?

    init(
        cursor: Int? = nil,
        size: Int = 50,
        keyword: String? = nil
    ) {
        self.cursor = cursor
        self.size = size
        self.keyword = keyword
    }

    /// Query Parameter Dictionary 변환
    var queryItems: [String: Any] {
        var params: [String: Any] = [
            "size": size
        ]
        if let cursor { params["cursor"] = cursor }
        if let keyword { params["keyword"] = keyword }
        return params
    }
}

// MARK: - Response

/// 챌린저 검색 응답 DTO (Cursor 기반 페이지네이션)
struct ChallengerSearchResponseDTO: Codable {
    let cursor: CursorDTO<ChallengerSearchItemDTO>

    private enum CodingKeys: String, CodingKey {
        case cursor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cursor = try container.decodeIfPresent(CursorDTO<ChallengerSearchItemDTO>.self, forKey: .cursor)
            ?? CursorDTO(content: [], nextCursor: nil, hasNext: false)
    }
}

/// 챌린저 검색 결과 항목 DTO
struct ChallengerSearchItemDTO: Codable {
    /// 멤버 ID (서버 응답 String 기준)
    let memberId: String
    let challengerId: Int
    let nickname: String
    let name: String
    let part: UMCPartType
    let schoolName: String
    let gisu: String
    let profileImageUrl: String?

    private enum CodingKeys: String, CodingKey {
        case memberId
        case challengerId
        case nickname
        case name
        case part
        case schoolName
        case gisu
        case profileImageUrl
    }

    init(
        memberId: String,
        challengerId: Int,
        nickname: String,
        name: String,
        part: UMCPartType,
        schoolName: String,
        gisu: String,
        profileImageUrl: String?
    ) {
        self.memberId = memberId
        self.challengerId = challengerId
        self.nickname = nickname
        self.name = name
        self.part = part
        self.schoolName = schoolName
        self.gisu = gisu
        self.profileImageUrl = profileImageUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memberId = try container.decodeStringFlexibleIfPresent(forKey: .memberId) ?? ""
        let fallbackChallengerId = Int(memberId) ?? 0
        challengerId = try container.decodeIntFlexibleIfPresent(forKey: .challengerId) ?? fallbackChallengerId
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        part = try container.decodeIfPresent(UMCPartType.self, forKey: .part) ?? .pm
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
        gisu = try container.decodeStringFlexibleIfPresent(forKey: .gisu) ?? "0"
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
    }
}

// MARK: - CursorDTO

/// Cursor 기반 페이지네이션 공용 DTO
///
/// 제네릭 타입 `T`로 다양한 목록 응답에 재사용 가능합니다.
struct CursorDTO<T: Codable>: Codable {
    /// 현재 페이지 항목 목록
    let content: [T]
    /// 다음 페이지 조회용 커서 값 (마지막 페이지 시 nil)
    let nextCursor: Int?
    /// 다음 페이지 존재 여부
    let hasNext: Bool

    private enum CodingKeys: String, CodingKey {
        case content
        case nextCursor
        case hasNext
    }

    init(content: [T], nextCursor: Int?, hasNext: Bool) {
        self.content = content
        self.nextCursor = nextCursor
        self.hasNext = hasNext
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent([T].self, forKey: .content) ?? []
        nextCursor = try container.decodeIntFlexibleIfPresent(forKey: .nextCursor)
        hasNext = try container.decodeIfPresent(Bool.self, forKey: .hasNext) ?? false
    }
}

// MARK: - toDomain

extension ChallengerSearchItemDTO {
    /// DTO를 도메인 모델 `ChallengerInfo`로 변환합니다.
    /// - Returns: 변환된 `ChallengerInfo` 도메인 모델
    func toChallengerInfo() -> ChallengerInfo {
        ChallengerInfo(
            memberId: memberId,
            challengerId: challengerId,
            gen: Int(gisu) ?? 0,
            name: name,
            nickname: nickname,
            schoolName: schoolName,
            profileImage: profileImageUrl,
            part: part
        )
    }
}

extension ChallengerSearchResponseDTO {
    /// 응답 DTO의 전체 항목을 `ChallengerInfo` 배열로 변환합니다.
    /// - Returns: 변환된 `ChallengerInfo` 배열
    func toChallengerInfoList() -> [ChallengerInfo] {
        cursor.content.map { $0.toChallengerInfo() }
    }
}

private extension KeyedDecodingContainer {
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
        return nil
    }
}
