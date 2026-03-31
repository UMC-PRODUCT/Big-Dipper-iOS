//
//  NoticeReadRepositoryProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 3/12/26.
//

import Foundation

/// 공지 읽음 상태의 로컬 저장소 인터페이스입니다.
///
/// 서버 목록 응답에 `isRead`가 없는 동안, 현재 계정 기준으로 읽은 공지 ID를
/// SwiftData에 저장하고 목록 표시에 재사용합니다.
protocol NoticeReadRepositoryProtocol {

    /// 특정 멤버가 읽은 공지 ID 집합을 조회합니다.
    func fetchReadNoticeIDs(memberId: Int) throws -> Set<String>

    /// 특정 멤버의 공지를 읽음 상태로 저장합니다.
    func markAsRead(noticeId: String, memberId: Int) throws
}
