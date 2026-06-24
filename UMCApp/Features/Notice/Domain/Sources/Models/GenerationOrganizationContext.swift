//
//  GenerationOrganizationContext.swift
//  NoticeData
//
//  Created by 이예지 on 5/27/26.
//

import Foundation

/// 기수별 사용자 소속 조직 정보를 저장/복원하기 위한 모델입니다.
public struct GenerationOrganizationContext: Codable, Equatable {
    public let gen: String
    public let chapterId: String?
    public let chapterName: String?
    public let schoolId: String?
    public let schoolName: String?
}
