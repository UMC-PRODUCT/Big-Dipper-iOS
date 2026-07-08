import AuthDomain
import Foundation
import UMCFoundation

/// 내 프로필 조회 Response DTO
///
/// `GET /api/v1/member/me`
///
/// 부트스트랩 승인 판정에 필요한 최소 필드만 디코딩한다. 서버 정수 필드(멤버 ID, 기수 번호)는
/// 절대규칙 #2에 따라 `String`으로 통일한다.
public struct MemberMeResponseDTO: Codable {

    // MARK: - Property

    public let id: String
    public let name: String
    public let nickname: String
    public let roles: [MemberRoleDTO]
    public let challengerRecords: [MemberChallengerRecordDTO]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case nickname
        case roles
        case challengerRecords
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleStringOrEmpty(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        roles = try container.decodeIfPresent([MemberRoleDTO].self, forKey: .roles) ?? []
        challengerRecords = try container.decodeIfPresent(
            [MemberChallengerRecordDTO].self,
            forKey: .challengerRecords
        ) ?? []
    }
}

// MARK: - MemberRoleDTO

/// 기수별 역할 정보 중 승인 판정에 필요한 기수 번호만 담는다.
public struct MemberRoleDTO: Codable {
    public let gisu: String

    private enum CodingKeys: String, CodingKey {
        case gisu
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gisu = container.decodeFlexibleStringOrEmpty(forKey: .gisu)
    }
}

// MARK: - MemberChallengerRecordDTO

/// 챌린저 이력 중 승인 판정에 필요한 기수 번호만 담는다.
public struct MemberChallengerRecordDTO: Codable {
    public let gisu: String

    private enum CodingKeys: String, CodingKey {
        case gisu
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gisu = container.decodeFlexibleStringOrEmpty(forKey: .gisu)
    }
}

// MARK: - toDomain

extension MemberMeResponseDTO {
    /// DTO → `Profile` 도메인 모델 변환.
    ///
    /// 역할(roles)과 챌린저 이력(challengerRecords) 양쪽에서 기수 번호를 모아 합집합을 구성한다.
    func toDomain() -> Profile {
        let generations = Set(roles.map(\.gisu) + challengerRecords.map(\.gisu))
            .filter { !$0.isEmpty && $0 != "0" }
            .sorted()

        return Profile(
            memberId: id,
            name: name,
            nickname: nickname,
            generations: Array(generations)
        )
    }
}
