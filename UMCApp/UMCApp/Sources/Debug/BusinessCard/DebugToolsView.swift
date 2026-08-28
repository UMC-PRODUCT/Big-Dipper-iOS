//
//  DebugToolsView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreDI
import SwiftUI
import VisionKit
import UMCFoundation

/// 시안에 없는 **검증 전용** 도구 모음.
///
/// 제품 화면에는 존재하지 않는 것들이라 루트에서 한 단계 밑으로 격리한다 — 시안 배치를
/// 확인하는 데 방해가 되지 않도록. QR 스캔·UWB 레인징·페이로드 왕복·원본 필드 덤프.
///
/// ## 이 하네스가 무엇을 검증하나
///
/// 아래는 **실기기 2대가 없으면 확인할 수 없는 것들**이다. 시뮬레이터는 무선이 없어
/// Mock transport 로 흐름만 돌고, UWB 는 아예 존재하지 않는다.
///
/// | 도구 | 실기기로만 확인되는 것 |
/// |---|---|
/// | 「근거리 교환」 (`DebugNearbyExchangeView`) | 제품 경로 전체 — MPC 발견·초대 타이브레이크·핸드셰이크·명함 왕복 |
/// | 「UWB」 (``NearbyRangingSection``) | NI 세션의 대칭 조건. MPC 를 빼고 UWB 만 떼어 본다 |
/// | 「QR 스캔」 | 카메라가 실제로 딥링크 문자열을 읽는지 (`DataScannerViewController` 는 시뮬레이터 미지원) |
/// | 「명함첩」 | SwiftData upsert 가 앱 재시작 뒤에도 유지되는지 |
///
/// 나머지(페이로드 왕복·원본 필드 덤프·딥링크 조회)는 시뮬레이터에서도 돈다 — 실기기
/// 검증 순서를 짤 때 뒤로 미뤄도 되는 항목이다.
struct DebugToolsView: View {

    // MARK: - Property

    let container: DIContainer
    let viewModel: BusinessCardDebugViewModel

    @State private var isScanning = false

    // MARK: - Body

    var body: some View {
        List {
            receivedCardsSection
            peerLookupSection
            scanSection
            NearbyRangingSection()
            myCardRawSection
            activityStatRawSection
            payloadSection
        }
        .navigationTitle("검증 도구")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Section

    /// 명함첩 검증. 화면 자체는 시안 그리드라 이 도구들을 둘 자리가 없어 여기로 옮겼다.
    private var receivedCardsSection: some View {
        Section {
            Button("샘플 명함 저장") {
                Task { await viewModel.saveSampleCard() }
            }
            LabeledContent("저장된 명함", value: "\(viewModel.receivedCardCount)장")
        } footer: {
            Text("같은 memberId로 다시 저장하면 새 행이 아니라 갱신되어야 한다(upsert). "
                 + "앱을 껐다 켜도 남아야 한다.")
        }
    }

    /// 카메라 없이 딥링크 조회 경로만 태워 보는 입구. 매핑이 무너지는지 여기서 먼저 걸린다.
    private var peerLookupSection: some View {
        Section {
            NavigationLink {
                DebugPeerLookupView(container: container)
            } label: {
                Label("memberId로 명함 조회", systemImage: "person.crop.circle.badge.questionmark")
            }
        } footer: {
            Text("QR을 찍지 않고 딥링크 조회 경로만 확인한다. 세션 모드 전환도 여기서 한다.")
        }
    }

    private var scanSection: some View {
        Section {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                Button(isScanning ? "스캔 중지" : "스캔 시작") { isScanning.toggle() }
                if isScanning {
                    QRScannerView { payload in
                        Task { await viewModel.handleScanned(payload) }
                    }
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .listRowInsets(EdgeInsets())
                }
            } else {
                Text("이 기기는 카메라 스캔을 지원하지 않는다 (시뮬레이터는 미지원)")
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(viewModel.scanLog.enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption).monospaced()
            }
        } header: {
            Text("QR 스캔 — 상대 명함 받기")
        } footer: {
            Text("상대 기기의 「검증(페이로드)」 QR을 찍으면 명함첩에 저장된다.")
        }
    }

    private var myCardRawSection: some View {
        Section {
            switch viewModel.myCard {
            case .idle, .loading:
                ProgressView()
            case .loaded(let card):
                labeled("memberId", card.memberId)
                labeled("name", card.name)
                labeled("nickname", card.nickname)
                labeled("part", "\(card.partDisplayName) / \(card.partAPIValue)")
                labeled("generation", card.generation)
                labeled("university", card.university)
                labeled("email", card.email ?? "—")
                labeled("github", card.github ?? "—")
                labeled("linkedIn", card.linkedIn ?? "—")
                labeled("blog", card.blog ?? "—")
                labeled("avatarURL", card.avatarURL ?? "—")
                labeled("cardLink", card.cardLink.urlString)
                labeled("qrPayload == cardLink", "\(card.qrPayload == card.cardLink.urlString)")
            case .failed(let error):
                Text("실패: \(error.localizedDescription)").foregroundStyle(.red)
            }
            Button("강제 새로고침 (forceRefresh: true)") {
                Task { await viewModel.reloadMyCard(forceRefresh: true) }
            }
        } header: {
            Text("내 명함 원본 필드 — FetchMyCardUseCase")
        } footer: {
            Text("정본 프로필 위임이 동작하는지 확인. 프로필 편집 후 값이 따라오면 저장 즉시 갱신이 성립.")
        }
    }

    private var activityStatRawSection: some View {
        Section {
            let stat = viewModel.activityStat
            labeled("받은 명함", stat.receivedCardCount)
            labeled("스터디", stat.studyCount)
            labeled("활동", stat.activityCount)
            labeled("스크랩", stat.bookmarkCount)
        } header: {
            Text("활동 카운트 원본 — FetchActivityStatUseCase")
        } footer: {
            Text("네 소스 병렬 조회. 실패한 소스만 0으로 떨어지고 나머지는 유지되어야 한다. 스크랩은 시안 v3에 표시 자리가 없다.")
        }
    }

    private var payloadSection: some View {
        Section {
            ForEach(Array(viewModel.payloadCheck.enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption).monospaced()
            }
        } header: {
            Text("ExchangePayload v2 왕복")
        } footer: {
            Text("내 명함 → 페이로드 → JSON → 디코딩 → 명함 복원까지 실제로 돌린 결과다.")
        }
    }

    // MARK: - Function

    private func labeled(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}
#endif
