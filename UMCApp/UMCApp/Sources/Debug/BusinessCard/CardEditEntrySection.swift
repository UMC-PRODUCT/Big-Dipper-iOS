//
//  CardEditEntrySection.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreDI
import SwiftUI
import MyPageDomain
import MyPagePresentation

/// 「명함 편집」 진입 검증 섹션.
///
/// 시안의 명함 편집(`12804:30498`)은 사진·닉네임·학교·활동 이력·외부 링크로 기존
/// `MyPageProfileView`와 필드가 같다. 즉 **신규 화면이 아니라 기존 프로필 편집의 재배치**다.
/// 여기서는 그 사실을 확인하기 위해 기존 화면을 그대로 연다 — 편집 후 「내 명함」 섹션의
/// 값이 따라오면 MP-F06(저장 즉시 갱신)이 성립한다는 뜻이다.
struct CardEditEntrySection: View {

    // MARK: - Property

    let container: DIContainer

    @State private var isLoading = false
    @State private var message: String?

    // MARK: - Body

    var body: some View {
        Section {
            NavigationLink("명함 편집 열기 (기존 프로필 편집 화면)") {
                CardEditLoaderView(container: container)
            }
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("명함 편집 — 기존 프로필 편집 재사용")
        } footer: {
            Text("시안의 명함 편집은 기존 프로필 편집과 필드가 같다. 편집 저장 후 위 「내 명함」을 새로고침하면 값이 따라와야 한다.")
        }
    }
}

/// 프로필 스냅샷을 먼저 받아야 편집 화면을 띄울 수 있어 로딩 단계를 한 겹 둔다.
private struct CardEditLoaderView: View {

    let container: DIContainer

    @State private var loadFailure: String?
    @State private var profileData: ProfileData?

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
    }

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
