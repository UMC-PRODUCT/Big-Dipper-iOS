//
//  NearbyRangingSection.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import SwiftUI
import VisionKit
import BusinessCardData

/// UWB(Nearby Interaction) 거리·방향 검증 섹션.
///
/// 토큰 교환을 QR로 한다 — 스파이크는 Wi-Fi Aware 연결로 교환했지만, 그러려면 페어링과
/// entitlement capability가 먼저 갖춰져야 한다. QR로 바꾸면 그 둘 없이도 UWB 자체를
/// 검증할 수 있다. 제품에서는 Wi-Fi Aware 채널로 교환하는 게 맞다.
///
/// **두 기기 절차**: 양쪽 다 「내 토큰 QR 만들기」 → 서로 상대 QR을 스캔 → 거리·방향 표시.
struct NearbyRangingSection: View {

    // MARK: - Property

    @State private var controller: NearbyRangingController?
    @State private var myTokenQR: CGImage?
    @State private var distanceText = "—"
    @State private var angleText = "—"
    @State private var isScanning = false
    @State private var log: [String] = []
    /// 레인징을 시작했는지. 「거리 —」가 세션 미시작인지 상대 미발견인지 가른다.
    @State private var isRanging = false
    /// 마지막 delegate 갱신 시각. 값이 흐르고 있는지 눈으로 확인하는 용도.
    @State private var lastUpdateAt: Date?
    @State private var updateCount = 0
    /// 토큰 지문. `controller` 안의 값을 그대로 읽으면 화면이 갱신되지 않아 여기로 옮겨 둔다.
    @State private var myFingerprint: String?
    @State private var peerFingerprint: String?

    // MARK: - Body

    var body: some View {
        Section {
            labeled("UWB 지원", "\(NearbyRangingController.isSupported)")
            // 두 기기를 맞대보는 값. **A의 「내 토큰」 == B의 「상대 토큰」** 이어야 정상이다.
            // controller 는 @Observable 이 아니라 그 안의 값을 직접 읽으면 화면이 갱신되지
            // 않는다 — 값을 @State 로 끌어와 둔다.
            labeled("내 토큰", myFingerprint ?? "없음")
            labeled("상대 토큰", peerFingerprint ?? "없음")
            labeled("레인징", isRanging ? "실행 중" : "미시작")
            labeled("거리", distanceText)
            labeled("수평각", angleText)
            labeled("갱신 수신", updateCount == 0 ? "0회 (상대 미발견)" : "\(updateCount)회")

            Button("내 토큰 QR 만들기") { makeToken() }

            if let myTokenQR {
                HStack {
                    Spacer()
                    Image(decorative: myTokenQR, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
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
                    .frame(height: 240)
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
            Text("UWB — Nearby Interaction 거리·방향")
        } footer: {
            Text("NI는 명함을 나르지 않는다 — 거리·방향만 준다. 여기서는 토큰을 QR로 교환해 페어링 없이 검증한다. 제품에서는 Wi-Fi Aware 채널로 교환한다.")
        }
    }

    // MARK: - Function

    private func makeToken() {
        // 다시 누르면 새 NISession이 만들어져 토큰이 바뀐다. 상대가 이미 스캔했다면
        // 그 토큰이 통째로 무효가 되고, 레인징은 조용히 성립하지 않는다.
        // 실기기 검증에서 실제로 이 함정에 걸렸다 — 재생성을 막는다.
        guard controller == nil else {
            log.insert("이미 토큰이 있다. 다시 만들려면 「세션 종료」 후 시작해라", at: 0)
            return
        }

        let controller = NearbyRangingController(
            onUpdate: { update in
                distanceText = update.distanceMeters.map { String(format: "%.2f m", $0) } ?? "—"
                angleText = update.horizontalAngleDegrees.map { String(format: "%.0f°", $0) } ?? "—"
                lastUpdateAt = Date()
                updateCount += 1
            },
            onEvent: { message in
                log.insert(message, at: 0)
            }
        )
        self.controller = controller

        guard let data = controller.makeTokenData() else {
            log.insert("토큰 생성 실패 (UWB 미지원 기기일 수 있다)", at: 0)
            return
        }
        // 토큰은 바이너리라 QR에 싣기 위해 base64로 감싼다 (스파이크 실측 343B).
        let encoded = data.base64EncodedString()
        myTokenQR = try? CoreImageQRCodeGenerator().generate(from: encoded)
        myFingerprint = controller.myTokenFingerprint
    }

    private func startRanging(with scanned: String) {
        guard let data = Data(base64Encoded: scanned) else {
            log.insert("토큰 QR이 아니다 (\(scanned.prefix(24))…)", at: 0)
            return
        }
        let started = controller?.startRanging(withPeerTokenData: data) ?? false
        peerFingerprint = controller?.peerTokenFingerprint
        isRanging = started
        isScanning = false
    }

    private func stop() {
        controller?.stop()
        controller = nil
        myTokenQR = nil
        distanceText = "—"
        angleText = "—"
        isRanging = false
        lastUpdateAt = nil
        updateCount = 0
        myFingerprint = nil
        peerFingerprint = nil
        log.insert("세션 종료", at: 0)
    }

    private func labeled(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }
}
#endif
