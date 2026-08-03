//
//  ActivityFeatureView.swift
//  ActivityPresentation
//
//  Created by euijjang97 on 3/6/26.
//

import CoreDI
import SwiftUI
import UMCFoundation

/// Activity 탭의 루트.
///
/// 탭 스택 자체는 상위 `RootTabView` 가 제공하므로 여기서 `NavigationStack` 을 만들지 않고,
/// 이 탭이 다루는 목적지(``ActivityDestination``)의 렌더 분기만 등록한다. 라우팅을 App 이
/// 아니라 이 모듈이 맡기 때문에 목적지 화면들을 `public` 으로 열지 않아도 된다.
///
/// 모듈 밖에는 이 타입만 노출하고, 모드×섹션 분기와 자식 조립은 내부 ``ActivityView`` 가
/// 맡는다. 의존은 앱 루트가 환경에 심어 둔 DI 컨테이너와 전역 에러 처리기에서 받는다.
public struct ActivityFeatureView: View {

    // MARK: - Property

    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler

    // MARK: - Init

    public init() {}

    // MARK: - Body

    public var body: some View {
        ActivityView(container: di, errorHandler: errorHandler)
            .navigationDestination(for: ActivityDestination.self) { destination in
                ActivityRoutingView(destination: destination)
            }
    }
}
