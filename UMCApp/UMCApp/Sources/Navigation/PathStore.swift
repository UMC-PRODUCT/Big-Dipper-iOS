import Foundation

/// 탭별 네비게이션 경로를 한 곳에서 관리하는 전역 Store.
///
/// 절대규칙 #1의 명시적 예외(앱 생명주기 전역 관리자)로 `@Observable`을 사용한다.
/// `RootTabView`가 소유하며, 탭별 `NavigationStack`의 path 바인딩 소스로 쓰인다.
@Observable
final class PathStore {

    // MARK: - Property

    var homePath: [NavigationDestination] = []
    var noticePath: [NavigationDestination] = []
    var activityPath: [NavigationDestination] = []
    var communityPath: [NavigationDestination] = []
    var myPagePath: [NavigationDestination] = []

    // MARK: - Init

    init() {}
}
