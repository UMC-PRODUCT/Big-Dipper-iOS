//
//  CommunityDestination.swift
//  CommunityPresentation
//

import Foundation

/// 커뮤니티 탭 내부 목적지.
///
/// App 모듈의 `NavigationDestination` 에 넣지 않는다 — Feature 가 자기 화면 구성을 소유하고,
/// App 은 진입점만 걸어 주는 규약을 따른다(`ActivityDestination` 과 동일).
///
/// - Note: `title` 을 함께 싣는 이유는 상세를 불러오기 전에도 네비게이션 바에 스레드명을
///   띄우기 위해서다. 로드가 끝나면 서버 값으로 대체된다.
public enum CommunityDestination: Hashable {
    case threadRoom(threadId: String, title: String)
    case threadCreate
    /// 참여자 목록. 내가 개설자인지는 목록의 내 행에서 읽으므로 함께 싣지 않는다 —
    /// 위임 직후 값이 바뀌는데 경로에 박아 두면 뒤로 갔다 오기 전까지 옛 권한이 남는다.
    case threadMembers(threadId: String)
}
