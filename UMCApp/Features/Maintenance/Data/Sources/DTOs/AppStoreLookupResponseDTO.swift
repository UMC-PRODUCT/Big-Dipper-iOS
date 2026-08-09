//
//  AppStoreLookupResponseDTO.swift
//  MaintenanceData
//
//  Created by euijjang97 on 8/9/26.
//

/// iTunes Lookup API 응답 DTO.
///
/// 버전 비교에 쓰지 않는 `resultCount`는 담지 않는다 — 스토어가 정수를 어떤 형태로
/// 직렬화하든 디코딩이 흔들리지 않게 하려는 의도.
struct AppStoreLookupResponseDTO: Codable {

    // MARK: - Property

    let results: [AppStoreAppInfoDTO]

    private enum CodingKeys: String, CodingKey {
        case results
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent(
            [AppStoreAppInfoDTO].self,
            forKey: .results
        ) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(results, forKey: .results)
    }
}

// MARK: - AppStoreAppInfoDTO

/// 스토어에 게시된 앱 정보.
struct AppStoreAppInfoDTO: Codable {

    // MARK: - Property

    let version: String

    private enum CodingKeys: String, CodingKey {
        case version
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
    }
}
