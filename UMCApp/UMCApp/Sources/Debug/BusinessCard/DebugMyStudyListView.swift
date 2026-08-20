//
//  DebugMyStudyListView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import ActivityDomain
import CoreDI
import CoreRouting
import Observation
import SwiftUI
import UMCFoundation

/// 마이페이지 「나의 스터디」 행의 임시 목록 화면.
///
/// 제품 화면이 아니다. 목적은 두 가지다.
/// 1. `GET /api/v1/study-groups/managed` 가 **참여 스터디인지 운영 스터디인지**를 실기기에서
///    가려낸다. 코드로는 확정할 수 없다 — `StudyRouter` 는 "운영 스터디 그룹 페이지 조회"라
///    주석하고 `BusinessCardRouter` 는 같은 경로를 "참여 스터디 목록"이라 주석한다. 요청·응답
///    DTO 에 스코프를 가릴 필드도 없다. 본인의 실제 참여 스터디 수와 대조하는 게 유일한 판별법이다.
/// 2. 행 → 활동 탭 이동 경로를 실제로 밟아 본다.
///
/// 스터디 **상세 화면은 아직 없다**(API·Repository 는 있고 Presentation 만 없음). 그래서 행을
/// 누르면 활동 탭 루트까지만 데려간다.
struct DebugMyStudyListView: View {

    // MARK: - Property

    @State private var viewModel: DebugMyStudyListViewModel

    @Environment(PathStore.self) private var pathStore

    // MARK: - Init

    init(container: DIContainer) {
        _viewModel = State(initialValue: DebugMyStudyListViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        List {
            sourceSection
            resultSection
        }
        .navigationTitle("나의 스터디 (검증)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Section

    private var sourceSection: some View {
        Section("데이터 출처") {
            LabeledContent("엔드포인트") {
                Text("GET /api/v1/study-groups/managed")
                    .font(.caption)
                    .monospaced()
            }

            LabeledContent("UseCase") {
                Text("OperatorStudyManagementUseCase\n.fetchStudyGroupDetailsPage")
                    .font(.caption)
                    .monospaced()
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("확인할 것", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.orange)

                Text("""
                아래 목록이 **본인이 참여 중인** 스터디와 같은가?
                다르다면(예: 운영진만 보이거나, 참여 안 한 그룹이 섞여 있으면) 이 엔드포인트는 \
                운영 스코프이고, 마이페이지 「나의 스터디」 카운트는 다른 엔드포인트로 바꿔야 한다.
                """)
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("성능 함정", systemImage: "tortoise.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.secondary)

                Text("""
                이 조회는 응답을 받은 뒤 페이지에 등장하는 **모든 멤버마다** \
                GET /member/profile/{id} 를 추가로 호출한다(동시 8개). 멤버가 많으면 느리다.
                """)
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.groups {
        case .idle, .loading:
            Section {
                ProgressView().frame(maxWidth: .infinity)
            }

        case .loaded(let groups) where groups.isEmpty:
            Section("결과") {
                Text("빈 목록. 참여/운영 중인 스터디가 없거나 권한이 없다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

        case .loaded(let groups):
            Section("결과 \(groups.count)건\(viewModel.hasNext ? " (다음 페이지 있음)" : "")") {
                ForEach(groups) { group in
                    Button {
                        moveToActivityTab()
                    } label: {
                        row(group)
                    }
                    .buttonStyle(.plain)
                }
            }

        case .failed(let error):
            Section("결과") {
                Text("조회 실패: \(error.errorDescription ?? error.localizedDescription)")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - View Component

    private func row(_ group: StudyGroupInfo) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.body)

                Text(
                    "\(group.part.name) · \(group.memberCount)명 · \(group.formattedCreatedDate)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let mentor = group.primaryMentor {
                    Text("스터디장 \(mentor.name)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.forward.app")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }

    // MARK: - Function

    /// 활동 탭으로 이동한다.
    ///
    /// 확립된 관용구는 "탭 전환 → 그 탭에 push" 2줄이지만(선례 3건, 전부 App 셸),
    /// 스터디 상세 목적지가 아직 없어 여기서는 전환까지만 한다. 목적지가 생기면
    /// `pathStore.push(ActivityDestination.studyDetail(...), on: .activity)` 한 줄이 붙는다.
    private func moveToActivityTab() {
        pathStore.selectedTab = .activity
    }
}

/// ``DebugMyStudyListView`` 상태.
@Observable
final class DebugMyStudyListViewModel {

    // MARK: - Property

    var groups: Loadable<[StudyGroupInfo]> = .idle
    private(set) var hasNext = false

    private let useCase: OperatorStudyManagementUseCaseProtocol

    private enum Constants {
        /// 검증 화면이라 한 페이지만 본다 — 스코프 판별에 페이징까지는 필요 없다.
        static let pageSize = 30
    }

    // MARK: - Init

    init(container: DIContainer) {
        self.useCase = container.resolve(OperatorStudyManagementUseCaseProtocol.self)
    }

    // MARK: - Function

    func load() async {
        groups = .loading
        do {
            let page = try await useCase.fetchStudyGroupDetailsPage(
                cursor: nil,
                size: Constants.pageSize
            )
            groups = .loaded(page.content)
            hasNext = page.hasNext
        } catch let error as AppError {
            groups = .failed(error)
        } catch {
            groups = .failed(.unknown(message: error.localizedDescription))
        }
    }
}
#endif
