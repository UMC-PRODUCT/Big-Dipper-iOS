//
//  DebugQRCodeView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import BusinessCardDomain
import Photos
import SwiftUI
import UIKit

/// 명함 카드의 「QR 코드」 버튼이 여는 화면 (시안 12639:33027).
///
/// **배치는 시안을 따른다** — 축소 명함(명함_m) · 272pt QR 프레임 · 캡션 · 버튼 2단.
/// 색·타이포는 시안 토큰이 아니라 시스템 값이다. 맞추는 것은 배치다.
///
/// 시안에 없는 **검증 토글은 맨 아래로 격리**했다. 제품 QR(딥링크)과 검증 QR(페이로드)을
/// 같은 프레임에 번갈아 넣어 실기기에서 어느 쪽이 읽히는지 비교하는 게 이 화면의 목적이다.
///
/// - Note: 시안의 QR은 21×21 모듈(version 1)로 그려져 있다. 이는 딥링크(17바이트) 크기이며,
///   페이로드 QR은 모듈 수가 훨씬 많아 같은 272pt 안에서 모듈이 잘아진다. 아래 검증 영역이
///   실제 격자 크기를 표시하므로 두 QR을 직접 비교할 수 있다.
struct DebugQRCodeView: View {

    // MARK: - Property

    let viewModel: BusinessCardDebugViewModel

    @State private var mode: Mode = .deepLink
    @State private var saveResult: SaveResult?

    private enum Constants {
        static let contentSpacing: CGFloat = 40
        static let qrBlockSpacing: CGFloat = 16
        static let buttonSpacing: CGFloat = 10
        static let horizontalPadding: CGFloat = 16

        static let cardHeight: CGFloat = 112
        static let cardRadius: CGFloat = 34
        static let cardPadding: CGFloat = 16
        static let avatarSize: CGFloat = 80
        static let chipMinWidth: CGFloat = 39
        static let chipHeight: CGFloat = 24

        static let qrFrameSize: CGFloat = 272
        static let qrFrameRadius: CGFloat = 24
        /// 시안의 QR 여백 — 프레임 272 안에서 코드가 차지하는 영역은 206pt다.
        static let qrInset: CGFloat = 33

        /// `CoreImageQRCodeGenerator` 의 업스케일 배율. 격자 크기를 되짚는 데 쓴다.
        static let generatorUpscale = 12
    }

    enum Mode: Hashable {
        case deepLink
        case payload

        var title: String {
            switch self {
            case .deepLink: return "제품(딥링크)"
            case .payload:  return "검증(페이로드)"
            }
        }
    }

    /// 사진 저장 결과. Alert 하나로 성공·실패를 모두 알린다.
    struct SaveResult: Identifiable {
        let id = UUID()
        let message: String
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Constants.contentSpacing) {
                miniCard

                VStack(spacing: Constants.qrBlockSpacing) {
                    qrFrame

                    Text("QR을 스캔하면 내 명함이 저장돼요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                actionButtons

                verificationSection
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.qrBlockSpacing)
        }
        .background(Color(.systemBackground))
        .navigationTitle("QR 코드")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $saveResult) { result in
            Alert(title: Text("이미지 저장"), message: Text(result.message))
        }
    }

    // MARK: - View Component

    /// 시안 `명함_m` — 축소 명함. 하단 버튼도 로고 헤더도 없다.
    @ViewBuilder
    private var miniCard: some View {
        Group {
            if let card = viewModel.myCard.value {
                HStack(spacing: Constants.cardPadding) {
                    avatar(card)

                    VStack(alignment: .leading, spacing: Constants.cardPadding) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(card.name)/\(card.nickname)")
                                .font(.title2.bold())

                            Text(card.university)
                                .font(.subheadline)
                        }

                        HStack(spacing: 5) {
                            chip(card.part.name)
                            chip("\(card.generation)기")
                        }
                    }

                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Constants.cardPadding)
        .frame(height: Constants.cardHeight)
        .frame(maxWidth: .infinity)
        .background(cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cardRadius))
    }

    private var qrFrame: some View {
        Group {
            if let image = currentImage {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(Constants.qrInset)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)

                    Text("QR 미생성")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: Constants.qrFrameSize, height: Constants.qrFrameSize)
        .background(.white, in: RoundedRectangle(cornerRadius: Constants.qrFrameRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Constants.qrFrameRadius)
                .stroke(Color(red: 229 / 255, green: 232 / 255, blue: 237 / 255))
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .accessibilityLabel("내 명함 QR 코드 (\(mode.title))")
    }

    private var actionButtons: some View {
        VStack(spacing: Constants.buttonSpacing) {
            if let image = currentImage {
                ShareLink(
                    item: Image(decorative: image, scale: 1),
                    preview: SharePreview(
                        "내 명함 QR",
                        image: Image(decorative: image, scale: 1)
                    )
                ) {
                    Text("공유하기").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)

                // 라벨 안쪽에 폭을 줘야 유리 배경이 함께 늘어난다.
                // 버튼 바깥에 .frame 을 걸면 배경은 글자 크기로 남고 자리만 넓어진다.
                Button {
                    Task { await saveToPhotos(image) }
                } label: {
                    Text("이미지 저장").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            } else {
                Text("QR이 생성되면 공유·저장할 수 있어요")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .controlSize(.large)
    }

    /// 시안에 없는 검증 영역. 두 QR을 같은 프레임에 번갈아 넣어 비교한다.
    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("검증 도구 (시안에 없음)")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("QR 종류", selection: $mode) {
                Text(Mode.deepLink.title).tag(Mode.deepLink)
                Text(Mode.payload.title).tag(Mode.payload)
            }
            .pickerStyle(.segmented)

            LabeledContent("격자(여백 포함)") {
                Text(gridDescription)
                    .font(.caption)
                    .monospaced()
            }

            LabeledContent("문자열 바이트") {
                Text("\(currentPayloadByteCount)B")
                    .font(.caption)
                    .monospaced()
            }

            Text(currentPayloadPreview)
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("""
            시안의 QR은 21×21 모듈(딥링크 크기)로 그려져 있다. 페이로드 QR은 격자가 훨씬 \
            촘촘해져 같은 272pt 안에서 모듈이 잘아진다. 두 모드를 번갈아 두고 상대 기기로 \
            20cm · 50cm · 1m 에서 스캔해 어디까지 읽히는지 본다.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Function

    private func avatar(_ card: MyCard) -> some View {
        Group {
            if let avatarURL = card.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.white.opacity(0.25)
                }
            } else {
                Color.black.opacity(0.7)
                    .overlay {
                        Text("UMC").font(.caption2.bold()).foregroundStyle(.white)
                    }
            }
        }
        .frame(width: Constants.avatarSize, height: Constants.avatarSize)
        .clipShape(.circle)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 8)
            .frame(minWidth: Constants.chipMinWidth, minHeight: Constants.chipHeight)
            .background(Color.white.opacity(0.25), in: .capsule)
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 114 / 255, green: 142 / 255, blue: 253 / 255).opacity(0.9),
                Color(red: 84 / 255, green: 104 / 255, blue: 252 / 255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var currentImage: CGImage? {
        mode == .deepLink ? viewModel.qrImage : viewModel.qrPayloadImage
    }

    /// 생성 이미지 픽셀 폭을 업스케일 배율로 되나눠 실제 격자 크기를 보여준다.
    private var gridDescription: String {
        guard let image = currentImage else { return "—" }
        let modules = image.width / Constants.generatorUpscale
        return "\(modules)×\(modules)"
    }

    private var currentPayloadByteCount: Int {
        switch mode {
        case .deepLink:
            return viewModel.qrPayload.utf8.count
        case .payload:
            return viewModel.qrPayloadByteCount
        }
    }

    private var currentPayloadPreview: String {
        switch mode {
        case .deepLink:
            return viewModel.qrPayload
        case .payload:
            return viewModel.qrPayloadJSON ?? "페이로드 생성 실패"
        }
    }

    /// 사진 앱에 저장한다. 추가 전용 권한이라 사진 선택기 없이 프롬프트만 뜬다.
    private func saveToPhotos(_ image: CGImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveResult = SaveResult(message: "사진 접근 권한이 없어 저장하지 못했어요.")
            return
        }

        do {
            let uiImage = UIImage(cgImage: image)
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }
            saveResult = SaveResult(message: "사진 앱에 저장했어요.")
        } catch {
            saveResult = SaveResult(message: "저장 실패: \(error.localizedDescription)")
        }
    }
}
#endif
