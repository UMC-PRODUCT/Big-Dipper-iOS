//
//  DebugCardEditView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreDI
import SwiftUI
import MyPageDomain
import MyPagePresentation

/// 「명함 관리 › 명함 편집」이 여는 화면.
///
/// 시안의 명함 편집(`12804:30498`)은 사진·닉네임·학교·활동 이력·외부 링크로 기존
/// `MyPageProfileView`와 필드가 같다. 즉 **신규 화면이 아니라 기존 프로필 편집의 재배치**다.
/// 그래서 기존 화면을 그대로 연다 — 편집 후 명함 값이 따라오면 「저장 즉시 갱신」이 성립한다.
///
/// 프로필 스냅샷을 먼저 받아야 편집 화면을 띄울 수 있어 로딩 단계를 한 겹 둔다.
struct DebugCardEditView: View {

    // MARK: - Property

    let container: DIContainer
    let viewModel: BusinessCardDebugViewModel

    @State private var loadFailure: String?
    @State private var profileData: ProfileData?

    // MARK: - Body

    var body: some View {
        Group {
            if let profileData {
                MyPageProfileView(container: container, profileData: profileData)
            } else if let loadFailure {
                ContentUnavailableView(
                    "프로필을 불러오지 못했다",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadFailure)
                )
            } else {
                ProgressView()
            }
        }
        .task { await load() }
        // 편집 저장 후 돌아갈 때 명함이 갱신되는지 보려면 명함 쪽도 다시 읽어야 한다.
        .onDisappear { Task { await viewModel.reloadMyCard(forceRefresh: true) } }
    }

    // MARK: - Function

    private func load() async {
        do {
            let provider = container.resolve(MyPageUseCaseProviding.self)
            profileData = try await provider.fetchMyPageProfileUseCase.execute(forceRefresh: false)
        } catch {
            loadFailure = error.localizedDescription
        }
    }
}
#endif
