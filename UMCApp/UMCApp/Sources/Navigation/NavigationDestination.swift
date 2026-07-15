//
//  NavigationDestination.swift
//  UMCApp
//
//  Created by euijjang97 on 7/8/26.
//

import NoticeDomain

/// 탭 내부에서 push되는 화면 목적지를 타입 세이프하게 정의하는 전역 열거형.
///
/// Feature 그룹별로 nested enum을 두고, 아직 탭에 실연결되지 않은 Feature는 케이스를
/// 추가하지 않는다. `AppFlowState`와 마찬가지로 각 Feature가 실제로 탭에 연결되는
/// 후속 이슈에서 케이스가 점진적으로 채워지는 최소 골격이다.
///
/// - Note: `.notice`는 `NoticePresentation`이 자체적으로 들고 있던 로컬 스텁
///   (`NoticeNavigation.swift`)의 목적지 구조를 그대로 옮겼다. 다만 `NoticePresentation`은
///   App 타깃을 참조할 수 없어(Feature → App 의존 방향 금지) `NoticeView`/`NoticeDetailView`가
///   이 타입을 직접 쓰도록 교체할 수는 없다. Notice 탭을 `RootTabView`에 실연결하는 후속
///   이슈에서 (a) Notice가 로컬 타입을 유지한 채 콜백/클로저로 상위와 연동하거나,
///   (b) 여러 Feature가 공유할 신규 Core 모듈을 신설해 이 타입을 옮기는 방안 중 하나를
///   메인테이너 승인 하에 선택해야 한다.
enum NavigationDestination: Hashable {
    case notice(Notice)

    enum Notice: Hashable {
        case detail(detailItem: NoticeDetail)
        case staffNotice
        case editor(mode: NoticeEditorMode, selectedGisuId: String?)
    }
}
