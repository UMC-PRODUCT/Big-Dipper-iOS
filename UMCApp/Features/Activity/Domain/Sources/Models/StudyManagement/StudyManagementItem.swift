//
//  StudyManagementItem.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation

/// 운영진 스터디 관리 카드용 모델
///
/// 챌린저 1명의 워크북 검토 정보를 표현합니다.
///
/// - Note: **현재 소비자 0건(dormant) — 미사용이지만 의도적으로 존치한다.**
///   `#586` 에서 제출 현황 UI 가 비활성화되며 소비자가 사라졌고, 재활성화는 `#999`
///   (운영진 스터디 제출 현황 UI + 백엔드 결선)에서 다룬다. `#999` 는 서버 제출 현황
///   API 미제공이라는 하드 블로커로 대기 중이며, 그 본문이 이 모델을 "dormant 상태로
///   준비돼 있다"고 전제하고 활성화 대상으로 지정해 두었다.
///   따라서 dead-code 스윕에서 삭제하지 말 것 — 삭제하려면 `#999` 를 먼저 닫아야 한다.
public struct StudyManagementItem: Identifiable, Equatable {

    // MARK: - Property

    public let id: UUID
    public let profile: String?
    public let name: String
    public let school: String
    public let part: String
    public let title: String
    public let state: StudySubmitState

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        profile: String? = nil,
        name: String,
        school: String,
        part: String,
        title: String,
        state: StudySubmitState = .examine
    ) {
        self.id = id
        self.profile = profile
        self.name = name
        self.school = school
        self.part = part
        self.title = title
        self.state = state
    }
}

/// 워크북 제출 상태 (서버 contract: rawValue 그대로 전송)
public enum StudySubmitState: String, Equatable {
    case examine = "검토"
}
