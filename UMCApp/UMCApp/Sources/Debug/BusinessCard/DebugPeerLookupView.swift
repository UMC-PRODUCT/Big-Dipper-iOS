//
//  DebugPeerLookupView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import BusinessCardDomain
import BusinessCardPresentation
import CoreDI
import Observation
import SwiftUI
import UMCFoundation

/// QR 딥링크가 실제로 명함을 복원하는지 **카메라 없이** 확인하는 화면.
///
/// 딥링크 경로의 진짜 위험은 QR 읽기가 아니라 서버 응답 → 명함 매핑이다:
/// ```
/// GET /member/profile/{id} → toPublic() → toDomain() → toMyCard()
/// ```
/// 응답에 `roles`·`challengerRecords`가 없으면 **에러 없이** `part = Admin`,
/// `generation = "0"`인 명함이 만들어진다. 그래서 조회 결과를 필드별로 펼쳐 보여주고,
/// 무너진 모양이면 경고를 띄운다.
///
/// - Important: stub 세션에서는 의미가 없다. ``StubSessionMode``가 인증을 가짜로 바꾸므로
///   실서버가 401을 준다. 화면 상단에서 현재 세션 모드를 보여주고 전환까지 제공한다.
struct DebugPeerLookupView: View {

    // MARK: - Property

    @State private var viewModel: DebugPeerLookupViewModel
    @State private var isRealSessionForced = StubSessionMode.isRealSessionForced

    // MARK: - Init

    init(container: DIContainer) {
        _viewModel = State(initialValue: DebugPeerLookupViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        List {
            sessionSection
            inputSection
            resultSection
        }
        .navigationTitle("딥링크 조회 (검증)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Section

    private var sessionSection: some View {
        Section {
            LabeledContent("현재 세션") {
                Text(isRealSessionForced ? "실서버" : "stub")
                    .font(.body.bold())
                    .foregroundStyle(isRealSessionForced ? .green : .orange)
            }

            Toggle("실서버 세션 강제", isOn: $isRealSessionForced)
                .onChange(of: isRealSessionForced) { _, newValue in
                    StubSessionMode.setRealSessionForced(newValue)
                }
        } header: {
            Text("세션 모드")
        } footer: {
            Text("""
            stub 세션은 인증을 가짜로 바꾸므로 실서버가 401을 준다. 전환은 **앱을 다시 켜야** \
            반영된다 — DI 등록이 시작 시 한 번만 돌기 때문이다. 실서버로 바꾸면 로그인 화면부터 \
            시작한다(카카오 bundle id 미등록이면 로그인 자체가 막힐 수 있다).
            """)
        }
    }

    private var inputSection: some View {
        Section {
            TextField("memberId (예: 42)", text: $viewModel.memberIdInput)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                Task { await viewModel.lookup() }
            } label: {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("조회").frame(maxWidth: .infinity)
                }
            }
            .disabled(viewModel.memberIdInput.isEmpty || viewModel.isLoading)

            Button("내 memberId로 조회") {
                Task { await viewModel.lookupMyself() }
            }
            .disabled(viewModel.isLoading)
        } header: {
            Text("조회")
        } footer: {
            Text("""
            서버는 `/member/profile/{id}`에 **자기 id로 불러도** 공개 응답(toPublic)을 준다. \
            그래서 내 id로 조회해도 타인 명함과 같은 마스킹 상태를 확인할 수 있다.
            """)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.card {
        case .idle:
            EmptyView()

        case .loading:
            Section { ProgressView().frame(maxWidth: .infinity) }

        case .loaded(let card):
            if card.isLikelyDegraded {
                Section {
                    Label("매핑이 무너졌다", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(.red)

                    Text("""
                    part=Admin · generation=0 은 응답에 roles·challengerRecords 가 없을 때 \
                    나오는 폴백 값이다. 서버가 타인 응답에서 기수 기록까지 지우고 있다는 뜻이라, \
                    딥링크로는 파트·기수를 복원할 수 없다.
                    """)
                    .font(.caption)
                }
            }

            Section("복원된 명함") {
                field("memberId", card.memberId)
                field("이름", card.name)
                field("닉네임", card.nickname)
                field("파트", card.part.name, isSuspicious: card.part == .admin)
                field("기수", card.generation, isSuspicious: card.generation == "0")
                field("학교", card.university)
                field("email", card.email ?? "— (서버가 마스킹)")
                field("github", card.github ?? "—")
                field("linkedIn", card.linkedIn ?? "—")
                field("blog", card.blog ?? "—")
                field("avatarURL", card.avatarURL ?? "—")
            }

            Section("이 명함의 딥링크") {
                Text(card.qrPayload)
                    .font(.caption)
                    .monospaced()
                    .textSelection(.enabled)
            }

        case .failed(let error):
            Section("조회 실패") {
                Text(error.errorDescription ?? error.localizedDescription)
                    .font(.callout)
                    .foregroundStyle(.red)

                Text(String(describing: error))
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Function

    private func field(_ label: String, _ value: String, isSuspicious: Bool = false) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(.callout)
                .foregroundStyle(isSuspicious ? .red : .primary)
                .textSelection(.enabled)
        }
    }
}

private extension MyCard {
    /// 응답에 기수 기록이 없을 때 나오는 폴백 조합.
    var isLikelyDegraded: Bool { part == .admin && generation == "0" }
}

/// ``DebugPeerLookupView`` 상태.
@Observable
final class DebugPeerLookupViewModel {

    // MARK: - Property

    var memberIdInput: String = ""
    private(set) var card: Loadable<MyCard> = .idle

    var isLoading: Bool { card.isLoading }

    private let provider: BusinessCardUseCaseProviding

    // MARK: - Init

    init(container: DIContainer) {
        self.provider = container.resolve(BusinessCardUseCaseProviding.self)
    }

    // MARK: - Function

    func lookup() async {
        await lookup(memberId: memberIdInput.trimmingCharacters(in: .whitespaces))
    }

    /// 내 명함을 먼저 가져와 그 memberId로 타인 조회 경로를 태운다.
    func lookupMyself() async {
        card = .loading
        do {
            let myCard = try await provider.fetchMyCardUseCase.execute(forceRefresh: false)
            memberIdInput = myCard.memberId
            await lookup(memberId: myCard.memberId)
        } catch let error as AppError {
            card = .failed(error)
        } catch {
            card = .failed(.unknown(message: error.localizedDescription))
        }
    }

    // MARK: - Private Function

    private func lookup(memberId: String) async {
        card = .loading
        do {
            card = .loaded(try await provider.fetchPeerCardUseCase.execute(memberId: memberId))
        } catch let error as AppError {
            card = .failed(error)
        } catch {
            card = .failed(.unknown(message: error.localizedDescription))
        }
    }
}
#endif
