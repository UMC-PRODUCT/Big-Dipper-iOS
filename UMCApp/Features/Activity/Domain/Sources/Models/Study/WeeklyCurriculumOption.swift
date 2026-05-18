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

    public let weeklyCurriculumId: Int
    public let weekNo: Int
    public let title: String

    public var id: Int { weeklyCurriculumId }

    public init(weeklyCurriculumId: Int, weekNo: Int, title: String) {
        self.weeklyCurriculumId = weeklyCurriculumId
        self.weekNo = weekNo
        self.title = title
    }
}
