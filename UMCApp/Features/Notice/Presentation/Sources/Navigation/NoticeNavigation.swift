//
//  NoticeNavigation.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI
import NoticeDomain

// TODO: PathStore / NavigationDestination 교체
//
// #910에서 App 타깃(UMCApp/UMCApp/Sources/Navigation)에 전역 PathStore/NavigationDestination
// 골격을 추가하고, 그 안에 이 파일과 동일한 형태의 `NavigationDestination.Notice` 케이스
// (detail/staffNotice/editor)를 이미 이식해 두었다. 다만 `NoticePresentation`은 App 타깃을
// import할 수 없으므로(Feature → App 의존 방향 금지) 이 로컬 타입을 지금 당장 지울 수는 없다.
// Notice 탭을 `RootTabView`에 실연결하는 후속 이슈에서 다음 중 하나로 정리한다.
//   (a) 이 로컬 타입을 유지한 채, 상위(App)가 콜백/클로저(예: AppFlow 패턴)로 연동한다.
//   (b) 여러 Feature가 공유할 신규 Core 모듈(예: CoreNavigation)을 신설해 이 타입을 옮긴다.
//       (신규 모듈 신설이므로 메인테이너 승인 필요)
@Observable
public final class PathStore {
    public var noticePath: [NavigationDestination] = []
    public init() {}
}

public enum NavigationDestination: Hashable {
    case notice(NoticeDestination)
}

public enum NoticeDestination: Hashable {
    case detail(detailItem: NoticeDetail)
    case staffNotice
    case editor(mode: NoticeEditorMode, selectedGisuId: String?)
}

public struct NavigationRoutingView: View {
    private let destination: NavigationDestination
    public init(destination: NavigationDestination) {
        self.destination = destination
    }
    public var body: some View {
        // TODO: Route to actual destination views
        Text("Navigation destination: \(String(describing: destination))")
    }
}
