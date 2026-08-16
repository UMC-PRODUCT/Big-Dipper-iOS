//
//  DebugQRCodeView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import SwiftUI

/// 명함 카드의 「QR 코드」 버튼이 여는 화면 (시안 MP-F04 자리).
///
/// 제품 QR과 검증 QR을 나눠 보여준다 — 제품 QR은 딥링크만 싣고 수신 측이 프로필 API로
/// 명함을 복원하는 설계인데 그 조회 경로가 아직 없다. 그래서 교환 왕복을 눈으로 보려면
/// 명함 전체를 실은 검증 QR이 따로 필요하다.
struct DebugQRCodeView: View {

    // MARK: - Property

    let viewModel: BusinessCardDebugViewModel

    @State private var mode: Mode = .deepLink

    enum Mode: Hashable {
        case deepLink
        case payload
    }

    // MARK: - Body

    var body: some View {
        List {
            Section {
                Picker("QR 종류", selection: $mode) {
                    Text("제품(딥링크)").tag(Mode.deepLink)
                    Text("검증(페이로드)").tag(Mode.payload)
                }
                .pickerStyle(.segmented)

                if let image = mode == .deepLink ? viewModel.qrImage : viewModel.qrPayloadImage {
                    HStack {
                        Spacer()
                        Image(decorative: image, scale: 1)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Spacer()
                    }
                } else {
                    Text("QR 미생성").foregroundStyle(.secondary)
                }

                Text(mode == .deepLink
                     ? viewModel.qrPayload
                     : "ExchangePayload JSON (명함 전체)")
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(.secondary)
            } footer: {
                Text("상대가 「검증(페이로드)」 QR을 스캔하면 실제로 명함첩에 저장된다. 딥링크 QR은 memberId 파싱까지만 확인된다.")
            }
        }
        .navigationTitle("QR 코드")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
