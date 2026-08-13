//
//  CommunityFeatureView.swift
//  CommunityPresentation
//
//  Created by euijjang97 on 3/6/26.
//

import SwiftUI

import CommunityDomain
import CoreDI
import CoreRouting
import UMCFoundation

/// 커뮤니티 탭 진입점.
///
/// 자체 `NavigationStack` 을 만들지 않는다 — 탭별 스택은 상위 탭 셸이 소유한다.
/// 자기 목적지(``CommunityDestination``) 등록은 리스트 화면이 하므로(생성 결과를 리스트
/// ViewModel 에 바로 반영해야 한다) App 은 여전히 커뮤니티 화면 구성을 알 필요가 없다.
public struct CommunityFeatureView: View {

    // MARK: - Property

    @Environment(PathStore.self) private var pathStore
    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler

    // MARK: - Init

    public init() {}

    // MARK: - Body

    public var body: some View {
        CommunityThreadListView(
            viewModel: CommunityThreadListViewModel(
                listUseCase: di.resolve(CommunityThreadListUseCaseProtocol.self),
                roomUseCase: di.resolve(CommunityThreadRoomUseCaseProtocol.self),
                errorHandler: errorHandler
            ),
            onThreadSelected: { thread in
                pathStore.push(
                    CommunityDestination.threadRoom(threadId: thread.id, title: thread.title),
                    on: .community
                )
            }
        )
    }
}
