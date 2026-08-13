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
}
