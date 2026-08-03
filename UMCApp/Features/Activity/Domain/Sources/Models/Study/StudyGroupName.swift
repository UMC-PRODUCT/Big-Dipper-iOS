//
//  StudyGroupName.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 8/3/26.
//

import Foundation

/// 스터디 그룹 이름 항목
///
/// 그룹 필터 드롭다운처럼 **목록 전체가 필요하지만 상세는 필요 없는** 화면을 위한 경량 모델입니다.
/// `GET /api/v1/study-groups/names` 응답에 대응하며, 요청자가 관리할 수 있는 그룹만 내려옵니다.
///
/// 상세 정보(멤버·멘토·파트)가 필요하면 ``StudyGroupInfo`` 를 사용하세요.
public struct StudyGroupName: Identifiable, Equatable, Sendable {

    // MARK: - Property

    /// 스터디 그룹 식별자 (서버 응답)
    public let groupId: String
    /// 스터디 그룹명
    public let name: String

    // MARK: - Identifiable

    public var id: String { groupId }

    // MARK: - Initializer

    public init(groupId: String, name: String) {
        self.groupId = groupId
        self.name = name
    }
}
