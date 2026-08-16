//
//  BusinessCardDebugView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreDI
import CoreNearbyExchange
import SwiftUI
import VisionKit
import BusinessCardDomain
import BusinessCardPresentation
import UMCFoundation

/// 명함 기능 계층(#1193~#1196) 동작 확인용 검증 화면.
///
/// 유닛 테스트가 덮지 못하는 것을 눈으로 확인하는 게 목적이다 — DI 배선, 실제 SwiftData
/// 컨테이너(CloudKit 스키마 포함), 실서버 카운트 응답, QR 실물, 교환 세션 이벤트 스트림.
/// 제품 화면이 아니므로 시안을 따르지 않는다. 릴리스 빌드에는 포함되지 않는다.
struct BusinessCardDebugView: View {

    // MARK: - Property

    @State private var viewModel: BusinessCardDebugViewModel
    @State private var qrMode: QRMode = .deepLink
    @State private var isScanning = false

    private let container: DIContainer

    /// 어떤 QR을 보여줄지. 제품 규칙(딥링크)과 검증용(페이로드 전체)을 나눠 본다.
    enum QRMode: Hashable {
        case deepLink
        case payload
    }

    // MARK: - Init

    init(container: DIContainer) {
        self.container = container
        _viewModel = State(initialValue: BusinessCardDebugViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        List {
            myCardSection
            activityStatSection
            qrSection
            qrScanSection
            receivedCardsSection
            CardEditEntrySection(container: container)
            exchangeSection
            NearbyRangingSection()
            payloadSection
        }
        .navigationTitle("명함 기능 검증")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAll() }
        .refreshable { await viewModel.loadAll() }
    }

    // MARK: - #1194 내 명함

    private var myCardSection: some View {
        Section {
            switch viewModel.myCard {
            case .idle, .loading:
                ProgressView()
            case .loaded(let card):
                labeled("memberId", card.memberId)
                labeled("name", card.name)
                labeled("nickname", card.nickname)
                labeled("part", "\(card.part.name) / \(card.part.apiValue)")
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
                failure(error)
            }
            Button("강제 새로고침 (forceRefresh: true)") {
                Task { await viewModel.reloadMyCard(forceRefresh: true) }
            }
        } header: {
            Text("#1194 내 명함 — FetchMyCardUseCase")
        } footer: {
            Text("정본 프로필 위임이 동작하는지 확인. 프로필 편집 후 값이 따라오면 MP-F06 성립.")
        }
    }

    // MARK: - #1195 활동 카운트

    private var activityStatSection: some View {
        Section {
            let stat = viewModel.activityStat
            labeled("받은 명함", stat.receivedCardCount)
            labeled("스터디", stat.studyCount)
            labeled("활동", stat.activityCount)
            labeled("스크랩", stat.bookmarkCount)
        } header: {
            Text("#1195 활동 카운트 — FetchActivityStatUseCase")
        } footer: {
            Text("네 소스 병렬 조회. 서버 실패 소스는 0으로만 떨어지고 나머지는 유지되어야 한다.")
        }
    }

    // MARK: - #1195 QR

    private var qrSection: some View {
        Section {
            Picker("QR 종류", selection: $qrMode) {
                Text("제품(딥링크)").tag(QRMode.deepLink)
                Text("검증(페이로드)").tag(QRMode.payload)
            }
            .pickerStyle(.segmented)

            if let image = qrMode == .deepLink ? viewModel.qrImage : viewModel.qrPayloadImage {
                HStack {
                    Spacer()
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
                Text(qrMode == .deepLink
                     ? viewModel.qrPayload
                     : "ExchangePayload JSON (명함 전체)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("QR 미생성")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("QR 보여주기 — GenerateCardQRUseCase")
        } footer: {
            Text("제품 QR은 딥링크만 싣는다(수신 측이 프로필 API로 복원 — 미구현). 검증 QR은 명함 전체를 실어 상대가 스캔하면 실제로 명함첩에 저장된다.")
        }
    }

    // MARK: - QR 스캔

    private var qrScanSection: some View {
        Section {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                Button(isScanning ? "스캔 중지" : "스캔 시작") {
                    isScanning.toggle()
                }
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
                Text(line)
                    .font(.caption)
                    .monospaced()
            }
        } header: {
            Text("QR 스캔 — 상대 명함 받기")
        } footer: {
            Text("상대 기기의 「검증(페이로드)」 QR을 찍으면 명함첩에 저장된다. 딥링크 QR은 memberId 파싱까지만 확인된다.")
        }
    }

    // MARK: - #1195 명함첩 (SwiftData)

    private var receivedCardsSection: some View {
        Section {
            TextField("검색 (이름·닉네임·파트·학교)", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await viewModel.reloadReceivedCards() } }

            HStack {
                Button("샘플 명함 저장") {
                    Task { await viewModel.saveSampleCard() }
                }
                Spacer()
                Text("count: \(viewModel.receivedCardCount)")
                    .foregroundStyle(.secondary)
            }

            switch viewModel.receivedCards {
            case .idle, .loading:
                ProgressView()
            case .loaded(let cards) where cards.isEmpty:
                Text("빈 명함첩")
                    .foregroundStyle(.secondary)
            case .loaded(let cards):
                ForEach(cards) { card in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(card.profile.name) / \(card.profile.nickname)")
                        Text("\(card.profile.part.name) · \(card.profile.generation)기 · \(card.profile.university)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("id=\(card.id) memberId=\(card.profile.memberId)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .swipeActions {
                        Button("삭제", role: .destructive) {
                            Task { await viewModel.delete(id: card.id) }
                        }
                    }
                }
            case .failed(let error):
                failure(error)
            }
        } header: {
            Text("#1195 명함첩 — SwiftData 저장소")
        } footer: {
            Text("같은 memberId로 다시 저장하면 새 행이 아니라 갱신되어야 한다(upsert). 앱을 껐다 켜도 남아야 한다.")
        }
    }

    // MARK: - #1193/#1196 교환

    private var exchangeSection: some View {
        Section {
            labeled("Wi-Fi Aware 지원", "\(WiFiAwareTransport.isSupported)")
            labeled("주입된 transport", viewModel.transportTypeName)

            #if canImport(DeviceDiscoveryUI)
            NavigationLink {
                WiFiAwarePairingView()
            } label: {
                Label("기기 페어링", systemImage: "dot.radiowaves.left.and.right")
            }
            #endif

            HStack {
                Button(viewModel.isExchanging ? "세션 중지" : "교환 세션 시작") {
                    Task { await viewModel.toggleExchange() }
                }
                Spacer()
                Text("peers: \(viewModel.peers.count)")
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.peers, id: \.id) { peer in
                Button {
                    Task { await viewModel.send(to: peer) }
                } label: {
                    VStack(alignment: .leading) {
                        Text(peer.displayName ?? peer.id)
                        Text("탭하면 내 명함 전송")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if viewModel.eventLog.isEmpty {
                Text("이벤트 없음")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.eventLog.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption)
                        .monospaced()
                }
            }
        } header: {
            Text("#1193·#1196 교환 — ExchangeCardsUseCase")
        } footer: {
            Text("시뮬레이터는 MockNearbyTransport라 즉시 이벤트가 흐른다. 실기기는 Wi-Fi Aware — 페어링된 기기가 없으면 notPaired가 떠야 정상.")
        }
    }

    // MARK: - #1193 페이로드 왕복

    private var payloadSection: some View {
        Section {
            ForEach(Array(viewModel.payloadCheck.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption)
                    .monospaced()
            }
        } header: {
            Text("#1193 ExchangePayload v2 왕복")
        } footer: {
            Text("내 명함 → 페이로드 → JSON → 디코딩 → 명함 복원까지 실제로 돌린 결과다.")
        }
    }

    // MARK: - Function

    private func labeled(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }

    private func failure(_ error: AppError) -> some View {
        Text("실패: \(error.localizedDescription)")
            .foregroundStyle(.red)
            .font(.callout)
    }
}
#endif
