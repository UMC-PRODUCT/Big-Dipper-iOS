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
/// - Note: 이 타입은 **App 에 남은 과도기 목적지**다. 공유 경로 저장소(`CoreRouting.PathStore`)가
///   타입 소거 `NavigationPath` 를 쓰기 때문에, Feature 는 App 을 참조하지 않고 자기 목적지
///   타입을 자기 모듈에 두면 된다(예: `ActivityPresentation.ActivityDestination`).
///   `.notice` 는 연관값이 `NoticeDomain.NoticeDetail` 이라 Notice 모듈로 옮기는 편이 자연스럽고,
///   그 이전은 Notice 탭 실연결 이슈 소관이라 지금은 App 에 둔다. 옮기고 나면 이 타입은 사라진다.
/// - Note: `NoticePresentation`은 App 타깃을 참조할 수 없어(Feature → App 의존 방향 금지)
///   이 타입을 직접 쓸 수 없다. 그래서 Notice의 각 화면은 콜백 클로저로 화면 전환 의도만
///   상위에 알리고, 실제 push는 `RootTabView`/`NavigationRoutingView`가 수행한다(#1027).
enum NavigationDestination: Hashable {
    case home(Home)
    case notice(Notice)

    enum Home: Hashable {
        case alarmHistory
        case scheduleDetail(scheduleId: String)
    }

    enum Notice: Hashable {
        case detail(detailItem: NoticeDetail)
        case staffNotice
        case editor(
            mode: NoticeEditorMode,
            selectedGisuId: String?,
            initialCategory: EditorMainCategory? = nil
        )
    }
}
