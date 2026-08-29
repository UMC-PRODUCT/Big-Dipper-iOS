//
//  NearbyRangingSection.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CryptoKit
import SwiftUI
import VisionKit
import BusinessCardData
import BusinessCardPresentation
import CoreNearbyExchange

/// UWB(Nearby Interaction) 거리 검증 섹션 — **제품 ``PeerRangingCoordinator`` 를 그대로 돌린다.**
///
/// 예전에는 이 화면이 자기 `NISession` 래퍼를 따로 들고 있었다. 제품과 같은 일을 하는 두
/// 번째 구현이라, 갈라지는 순간 「하네스에선 되는데 제품에선 안 된다」를 판단할 근거가
/// 사라진다. 그래서 세션 관리·토큰 직렬화·델리게이트는 전부 제품 타입에 맡기고 여기는
/// **토큰을 나르는 채널만** 바꿔 낀다.
///
/// | | 토큰 채널 | 목적 |
/// |---|---|---|
/// | 제품 | MPC 세션 (`NearbyMessage.handshake`) | 페어링 없이 자동 교환 |
/// | 여기 | QR | MPC 없이 **UWB 만** 따로 떼어 본다 |
///
/// 채널을 갈아 끼울 수 있는 건 `PeerRangingCoordinator` 가 ``NearbyHandshakeProviding``
/// 으로만 바깥과 이야기하기 때문이다 — 이 화면은 MPC 대신 자기가 그 역할을 맡는다.
/// 교환 흐름까지 함께 보려면 「근거리 교환」 화면이 제품 경로(MPC + NI)를 통째로 돈다.
///
/// - Note: 방향(수평각)은 여기서 보지 않는다. 제품이 거리만 쓰기 때문이다 —
///   `PeerRangingCoordinator` 도 `NINearbyObject.direction` 을 흘리지 않는다.
///
/// **두 기기 절차**: 양쪽 다 「내 토큰 QR 만들기」 → 서로 상대 QR을 스캔 → 거리 표시.
struct NearbyRangingSection: View {

    // MARK: - Constants

    fileprivate enum Constants {
        /// 이 화면은 상대가 한 명뿐이라 피어 키가 고정이다. 제품에서는 MPC 세션 식별자가 온다.
        static let peerID = "qr-peer"
        static let qrSide: CGFloat = 200
        static let scannerHeight: CGFloat = 240
        /// 토큰 지문 길이(바이트). 두 기기 화면을 눈으로 맞대보는 용도라 짧게 자른다.
        static let fingerprintByteCount = 3
    }

    // MARK: - Property

    @State private var coordinator: PeerRangingCoordinator?
    @State private var distanceTask: Task<Void, Never>?
    @State private var myTokenQR: CGImage?
    @State private var distanceText = "—"
    @State private var isScanning = false
    @State private var log: [String] = []
    /// 레인징을 시작했는지. 「거리 —」가 세션 미시작인지 상대 미발견인지 가른다.
    @State private var isRanging = false
    @State private var updateCount = 0
    /// 토큰 지문. **두 기기가 서로의 것을 제대로 바꿨는지 확인하는 유일한 수단**이다.
    /// 자기 QR 을 자기가 찍어도 화면상으로는 구분되지 않아서, 이 값이 없으면 「조용히 안 됨」의
    /// 원인을 가릴 수 없다. A 의 내 토큰 지문 == B 의 상대 토큰 지문이어야 정상이다.
    @State private var myFingerprint: String?
    @State private var peerFingerprint: String?
    /// 조율 계층의 마지막 실패 원문. 스트림에 에러 채널이 없어 폴링으로 끌어온다.
    @State private var lastError: String?

    // MARK: - Body

    var body: some View {
        Section {
            labeled("UWB 지원", "\(PeerRangingCoordinator.isSupported)")
            labeled("내 토큰", myFingerprint ?? "없음")
            labeled("상대 토큰", peerFingerprint ?? "없음")
            labeled("레인징", isRanging ? "실행 중" : "미시작")
            labeled("거리", distanceText)
            labeled("갱신 수신", updateCount == 0 ? "0회 (상대 미발견)" : "\(updateCount)회")
            if let lastError {
                labeled("마지막 오류", lastError)
            }

            Button("내 토큰 QR 만들기") { makeToken() }

            if let myTokenQR {
                HStack {
                    Spacer()
                    Image(decorative: myTokenQR, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Constants.qrSide, height: Constants.qrSide)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
            }

            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                Button(isScanning ? "스캔 중지" : "상대 토큰 QR 스캔") {
                    isScanning.toggle()
                }
                if isScanning {
                    QRScannerView { payload in
                        startRanging(with: payload)
                    }
                    .frame(height: Constants.scannerHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .listRowInsets(EdgeInsets())
                }
            } else {
                Text("카메라 스캔 미지원 기기 (시뮬레이터)")
                    .foregroundStyle(.secondary)
            }

            Button("세션 종료", role: .destructive) { stop() }

            ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption)
                    .monospaced()
            }
        } header: {
            Text("UWB — Nearby Interaction 거리")
        } footer: {
            Text("NI는 명함을 나르지 않는다 — 거리만 준다. 제품과 같은 PeerRangingCoordinator 를 "
                 + "돌리되 토큰만 QR로 나른다(제품은 MPC 채널). MPC 없이 UWB 만 떼어 보는 자리다.")
        }
    }

    // MARK: - Function

    private func makeToken() {
        // 다시 누르면 새 NISession이 만들어져 토큰이 바뀐다. 상대가 이미 스캔했다면
        // 그 토큰이 통째로 무효가 되고, 레인징은 조용히 성립하지 않는다.
        // 실기기 검증에서 실제로 이 함정에 걸렸다 — 재생성을 막는다.
        guard coordinator == nil else {
            append("이미 토큰이 있다. 다시 만들려면 「세션 종료」 후 시작해라")
            return
        }

        let coordinator = PeerRangingCoordinator()
        // `start(preview:)` 는 내부에서 stopAll() 을 부르며 스트림을 닫는다 —
        // 반드시 distances() 구독보다 먼저다.
        coordinator.start(preview: Self.harnessPreview)
        subscribeDistances(of: coordinator)
        self.coordinator = coordinator

        guard let handshake = coordinator.makeHandshake(forPeerID: Constants.peerID),
              let token = handshake.niToken else {
            append("토큰 생성 실패 (UWB 미지원 기기일 수 있다)")
            lastError = coordinator.lastError
            return
        }

        myFingerprint = Self.fingerprint(of: token)
        // 토큰은 바이너리라 QR에 싣기 위해 base64로 감싼다 (스파이크 실측 343B).
        myTokenQR = try? CoreImageQRCodeGenerator().generate(from: token.base64EncodedString())
        append("내 토큰 준비 (\(token.count)B, 지문 \(myFingerprint ?? "?"))")
    }

    private func startRanging(with scanned: String) {
        isScanning = false

        guard let coordinator else {
            append("내 토큰을 먼저 만들어야 한다")
            return
        }
        guard let token = Data(base64Encoded: scanned) else {
            append("토큰 QR이 아니다 (\(scanned.prefix(24))…)")
            return
        }

        let scannedFingerprint = Self.fingerprint(of: token)
        peerFingerprint = scannedFingerprint

        // 자기 QR 을 자기가 찍는 실수. NI 는 이걸 에러로 알려주지 않고 그냥 조용하다.
        guard scannedFingerprint != myFingerprint else {
            append("⚠️ 내 토큰을 스캔했다 — 상대 폰 화면을 찍어야 한다")
            return
        }

        coordinator.didReceiveHandshake(
            NearbyHandshake(preview: Self.harnessPreview, niToken: token),
            fromPeerID: Constants.peerID
        )
        isRanging = true
        lastError = coordinator.lastError
        append("레인징 시작 (상대 지문 \(scannedFingerprint))")
    }

    private func stop() {
        distanceTask?.cancel()
        distanceTask = nil
        coordinator?.stopAll()
        coordinator = nil
        myTokenQR = nil
        distanceText = "—"
        isRanging = false
        updateCount = 0
        myFingerprint = nil
        peerFingerprint = nil
        lastError = nil
        append("세션 종료")
    }

    /// 거리 스트림을 구독한다. 스트림 생성은 continuation 등록이 동기라 Task 밖에서 한다.
    private func subscribeDistances(of coordinator: PeerRangingCoordinator) {
        let stream = coordinator.distances()
        distanceTask = Task { @MainActor in
            for await distance in stream {
                guard !Task.isCancelled else { return }
                distanceText = distance.meters.map { String(format: "%.2f m", $0) } ?? "—"
                updateCount += 1
                lastError = coordinator.lastError
            }
        }
    }

    private func append(_ message: String) {
        log.insert(message, at: 0)
    }

    private func labeled(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }

    // MARK: - Private Static Property

    /// 핸드셰이크는 미리보기를 요구하지만 이 화면은 목록을 그리지 않는다 — 자리만 채운다.
    private static let harnessPreview = PeerPreview(
        name: "검증", nickname: "harness", part: "IOS", generation: "0", avatarURL: nil
    )

    // MARK: - Private Static Function

    /// 프로세스마다 달라지는 `hashValue` 는 쓸 수 없다 — 두 기기의 값을 맞대볼 수 없다.
    private static func fingerprint(of data: Data) -> String {
        SHA256.hash(data: data).prefix(Constants.fingerprintByteCount)
            .map { String(format: "%02X", $0) }
            .joined()
    }
}
#endif
