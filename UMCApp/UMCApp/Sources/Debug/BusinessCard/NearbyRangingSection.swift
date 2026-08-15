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

    // MARK: - Body

    var body: some View {
        Section {
            labeled("UWB 지원", "\(NearbyRangingController.isSupported)")
            labeled("거리", distanceText)
            labeled("수평각", angleText)

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
        let controller = NearbyRangingController(
            onUpdate: { update in
                distanceText = update.distanceMeters.map { String(format: "%.2f m", $0) } ?? "—"
                angleText = update.horizontalAngleDegrees.map { String(format: "%.0f°", $0) } ?? "—"
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
        log.insert("내 토큰 준비 완료 (\(data.count)B)", at: 0)
    }

    private func startRanging(with scanned: String) {
        guard let data = Data(base64Encoded: scanned) else {
            log.insert("토큰 QR이 아니다", at: 0)
            return
        }
        controller?.startRanging(withPeerTokenData: data)
        isScanning = false
    }

    private func stop() {
        controller?.stop()
        controller = nil
        myTokenQR = nil
        distanceText = "—"
        angleText = "—"
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
