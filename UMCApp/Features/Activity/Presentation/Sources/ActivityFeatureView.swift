//
//  ActivityFeatureView.swift
//  ActivityPresentation
//
//  Created by euijjang97 on 3/6/26.
//

import SwiftUI
#if DEBUG
import CoreDomain
#endif

public struct ActivityFeatureView: View {
    public init() {}

    public var body: some View {
        #if DEBUG
        debugOperatorStudyHarness
        #else
        Text("Activity Feature")
        #endif
    }
}

#if DEBUG
extension ActivityFeatureView {
    /// 운영진 스터디 관리 화면 DEBUG 하네스 진입점
    @MainActor
    fileprivate var debugOperatorStudyHarness: some View {
        DebugOperatorStudyHarnessView()
    }
}

/// 운영진 스터디 관리 화면의 DEBUG 전용 하네스
///
/// Activity 라우터·DI 배선 이식 전까지, 스텁 UseCase(PreviewSupport)로 이식 화면을
/// 서버·로그인 없이 Activity 탭에서 직접 확인하기 위한 임시 진입점. 앱 타깃이 이
/// 화면들을 참조해야 static 링크에 포함되므로, UMCApp 스킴의 Canvas 프리뷰 호스팅도
/// 이 참조로 활성화된다. 생성 폼은 운영 화면에서 진입점이 게이팅("준비 중")된 상태라
/// 하네스 전용 버튼으로 직접 진입한다. 상위 RootTabView가 탭별 NavigationStack을
/// 제공하므로 여기서 스택을 만들지 않는다.
/// // TODO: Activity 라우터·DIContainer 이식 후 실제 배선으로 교체 - [26.07.24] 이재원
@MainActor
private struct DebugOperatorStudyHarnessView: View {
    @State private var viewModel: OperatorStudyManagementViewModel
    @State private var userSession: UserSessionManager
    @State private var showsCreateForm = false

    init() {
        _viewModel = State(wrappedValue: previewOperatorStudyManagementViewModel())
        _userSession = State(wrappedValue: previewCreateCapableSession())
    }

    var body: some View {
        OperatorStudyManagementView(
            viewModel: viewModel,
            userSession: userSession
        )
        .navigationTitle("스터디 관리")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("생성 폼") {
                    showsCreateForm = true
                }
            }
        }
        .navigationDestination(isPresented: $showsCreateForm) {
            OperatorStudyGroupCreateView(viewModel: viewModel)
        }
    }
}
#endif
