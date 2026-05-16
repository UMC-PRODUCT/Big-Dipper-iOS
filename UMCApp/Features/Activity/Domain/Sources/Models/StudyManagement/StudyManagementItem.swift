//
//  StudyManagementItem.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation

/// 운영진 스터디 관리 카드용 모델
///
/// 챌린저 1명의 워크북 검토 정보를 표현합니다. (`#586` 비활성화 대상)
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
