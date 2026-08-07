//
//  GenerationMappingRecord.swift
//  HomeData
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation
import SwiftData

/// 기수-기수ID 매핑 로컬 저장 모델 (SwiftData + CloudKit Sync)
///
/// 홈 프로필 응답에서 파생한 (gen, gisuId) 매핑을 저장합니다.
///
/// - Note: 서버 응답 DTO가 아닌 로컬 영속 모델이므로 정수 필드를 `Int`로 둔다
///   (`SortDescriptor(\.gen)`가 `String`이면 "10" < "9"로 사전순 정렬돼 틀린다).
///   `String` 경계 변환은 ``ChallengerGenRepository``에서만 수행한다.
@Model
public final class GenerationMappingRecord {

    // MARK: - Property

    /// 서버 기수 식별 ID
    public var gisuId: Int = 0

    /// 기수 번호 (예: 9, 10, 11)
    public var gen: Int = 0

    /// 마지막 업데이트 시간
    public var updatedAt: Date = Date()

    // MARK: - Init

    public init(
        gisuId: Int,
        gen: Int,
        updatedAt: Date = Date()
    ) {
        self.gisuId = gisuId
        self.gen = gen
        self.updatedAt = updatedAt
    }
}
