//
//  WeeklyCurriculumOption.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation

/// 주차 커리큘럼 선택 옵션
///
/// 스터디 그룹 일정을 주차 커리큘럼과 연결할 때 사용자가 고르는 한 줄짜리 옵션입니다.
public struct WeeklyCurriculumOption: Hashable, Identifiable, Sendable {

    /// 주차 커리큘럼 식별자 (서버 응답)
    public let weeklyCurriculumId: String

    /// 주차 번호 (서버 응답)
    public let weekNo: String

    public let title: String

    public var id: String { weeklyCurriculumId }

    public init(weeklyCurriculumId: String, weekNo: String, title: String) {
        self.weeklyCurriculumId = weeklyCurriculumId
        self.weekNo = weekNo
        self.title = title
    }
}
