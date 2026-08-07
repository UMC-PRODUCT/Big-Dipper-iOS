//
//  ChallengerGenRepositoryProtocol.swift
//  CoreDomain
//
//  Created by 이예지 on 5/27/26.
//

/// 기수-기수ID 매핑 로컬 저장소 Repository Protocol
///
/// SwiftData + CloudKit 기반으로 (gen, gisuId) 매핑을 저장/조회합니다.
/// 매핑 생산자(Home)와 소비자(Notice)가 서로 다른 Feature이므로 CoreDomain에 둔다.
public protocol ChallengerGenRepositoryProtocol: Sendable {

    /// 전체 매핑을 교체 저장합니다.
    ///
    /// 입력 목록 기준으로 upsert 후, 입력에 없는 기존 레코드는 삭제합니다.
    /// - Parameter pairs: 저장할 (gen, gisuId) 매핑 목록
    func replaceMappings(_ pairs: [(gen: String, gisuId: String)]) throws

    /// 전체 기수의 (gen, gisuId) 매핑 배열 조회
    /// - Returns: gen 오름차순 정렬된 (gen, gisuId) 튜플 배열
    func fetchGenGisuIdPairs() throws -> [(gen: String, gisuId: String)]
}
