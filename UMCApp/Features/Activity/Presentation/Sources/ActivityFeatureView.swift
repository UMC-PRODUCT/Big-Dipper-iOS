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
/// 탭 스택 자체는 상위 `RootTabView` 가 제공하므로 여기서 `NavigationStack` 을 만들지 않는다.
/// 이 탭이 다루는 목적지(``ActivityDestination``)의 등록은 탭 루트 ``ActivityView`` 가 맡는다 —
/// 목적지가 탭 루트 소유의 공유 ViewModel 을 캡처해야 해서 같은 body 안에 있어야 한다.
/// 라우팅을 App 이 아니라 이 모듈이 맡기 때문에 목적지 화면들을 `public` 으로 열지 않아도 된다.
///
/// 모듈 밖에는 이 타입만 노출하고, 모드×섹션 분기와 자식 조립은 내부 ``ActivityView`` 가
/// 맡는다. 의존은 앱 루트가 환경에 심어 둔 DI 컨테이너와 전역 에러 처리기에서 받는다.
public struct ActivityFeatureView: View {

    // MARK: - Property

    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler

    /// 다른 탭이 올린 진입 요청. 탭 루트가 처리한 뒤 비운다.
    @Binding private var pendingEntry: ActivityEntry?

    // MARK: - Init

    /// - Parameter pendingEntry: 다른 탭에서 넘어온 진입 요청(예: 마이페이지 「나의 스터디」).
    ///   탭 루트 ``ActivityView`` 가 해당 섹션으로 옮긴 뒤 `nil` 로 비운다.
    public init(pendingEntry: Binding<ActivityEntry?>) {
        _pendingEntry = pendingEntry
    }

    // MARK: - Body

    public var body: some View {
        ActivityView(container: di, errorHandler: errorHandler, pendingEntry: $pendingEntry)
    }
}
