//
//  FetchRecentNoticesUseCaseProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 7/11/26.
//

import NoticeDomain

/// 홈 화면 내 최근 공지 조회 UseCase 인터페이스
public protocol FetchRecentNoticesUseCaseProtocol {
    /// - Parameter gisuId: 최신 기수 식별자 (서버 정수를 String으로 보존, 절대규칙 #2)
    /// - Returns: 최신순 최근 공지 목록 (상위 5건)
    func execute(gisuId: String) async throws -> [NoticeItemModel]
}
