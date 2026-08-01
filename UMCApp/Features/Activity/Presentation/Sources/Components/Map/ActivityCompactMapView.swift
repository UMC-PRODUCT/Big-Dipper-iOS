//
//  ActivityCompactMapView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/30/26.
//

import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UIKit

/// 활동 상세 화면에서 사용하는 컴팩트 지도 뷰
///
/// 지오펜싱 기반 출석 체크 상태와 세션 위치를 표시합니다.
/// - 지도 인터랙션 비활성화 (`disabled`)
/// - 하단 상태바: 위치 인증 상태, 주소 표시
///
/// - Note: 표시 대상 세션은 `mapViewModel` 이 이미 보유하므로 별도로 받지 않습니다.
///   세션을 중복으로 받으면 ViewModel 이 등록한 지오펜스와 화면이 그리는 세션이
///   어긋날 수 있어, 정체성 출처를 ViewModel 하나로 고정합니다.
struct ActivityCompactMapView: View {

    // MARK: - Property

    // `$` 투영이 필요한 건 카메라를 바인딩하는 `BaseMapComponent` 뿐이라 여기선 일반 참조로 둔다.
    // `@Observable` 이므로 이대로도 body 의 프로퍼티 읽기가 관찰 대상이 된다.
    private let mapViewModel: BaseMapViewModel

    fileprivate enum Constants {
        static let mapComponentHeight: CGFloat = 200
        static let mapCornerRadius: Edge.Corner.Style = 24
    }

    // MARK: - Init

    init(mapViewModel: BaseMapViewModel) {
        self.mapViewModel = mapViewModel
    }

    // MARK: - Body

    var body: some View {
        BaseMapComponent(viewModel: mapViewModel)
            .equatable()
            .frame(height: Constants.mapComponentHeight)
            .disabled(true)
            .overlay(alignment: .bottomTrailing) {
                LocationStatusBarView(mapViewModel: mapViewModel)
            }
            .clipShape(ConcentricRectangle(
                corners: .concentric(minimum: Constants.mapCornerRadius),
                isUniform: true
            ))
            .task {
                // 위치 갱신을 가장 먼저 시작한다. 지오펜스 판정이 현재 위치에 의존하므로,
                // 역지오코딩(네트워크 왕복) 뒤로 밀리면 그동안 "위치 미인증"으로 잘못 보인다.
                mapViewModel.startLocationUpdate()
                await mapViewModel.startGeofenceForAttendance()
                await mapViewModel.updateAddressForSession()
            }
            .onDisappear {
                mapViewModel.stopLocationUpdate()
            }
    }
}

// MARK: - LocationStatusBarView

/// 지도 하단의 위치 상태 표시바
private struct LocationStatusBarView: View {

    // MARK: - Property

    let mapViewModel: BaseMapViewModel

    fileprivate enum Constants {
        static let statusBarSpacing: CGFloat = 4
        static let contextMenuIconSize: CGFloat = 12
        static let addressVerticalPadding: CGFloat = 4
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Constants.statusBarSpacing) {
            LocationVerificationLabel(isUserInsideGeofence: mapViewModel.isUserInsideGeofence)
            address
        }
        .padding(DefaultConstant.defaultBtnPadding)
        // 지도(미디어) 위에 얹히므로 `.regular` 가 아니라 `.clear` 를 쓴다 (디자인 시스템 규칙).
        // 레거시는 기본값(`.regular`)이었으나 미디어 위 `.regular` 는 금지 항목이라 교정한다.
        .glassEffect(.clear)
        .safeAreaPadding(DefaultConstant.defaultSafeHorizon)
        .contentShape(Rectangle())
        .contextMenu {
            Button("클립보드로 복사", systemImage: "doc.on.doc") {
                copyAddress()
            }

            Button("애플 지도로 검색", systemImage: "map") {
                mapViewModel.openSessionLocationInMaps()
            }
        } preview: {
            LocationStatusBarContextPreview(
                isUserInsideGeofence: mapViewModel.isUserInsideGeofence,
                sessionAddress: mapViewModel.sessionAddress ?? LocationStatusText.unknownAddress
            )
        }
    }

    // MARK: - View Component

    /// 세션 위치의 주소 (역지오코딩 결과)
    private var address: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            MarqueeText(text: mapViewModel.sessionAddress ?? LocationStatusText.unknownAddress)
                .frame(maxWidth: .infinity)

            Image(systemName: "ellipsis.circle")
                .font(.system(size: Constants.contextMenuIconSize))
                .foregroundStyle(Color.grey500)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, Constants.addressVerticalPadding)
        .padding(.leading, DefaultSpacing.spacing8)
        .accessibilityHint("길게 눌러 주소 관련 메뉴를 엽니다")
    }

    // MARK: - Function

    private func copyAddress() {
        let trimmed = mapViewModel.sessionAddress?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return }

        UIPasteboard.general.string = trimmed
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - LocationVerificationLabel

/// 위치 인증 여부를 아이콘 + 문구로 표시하는 라벨
///
/// 상태바와 컨텍스트 메뉴 프리뷰가 같은 표현을 쓰므로 한 곳에 모았습니다.
private struct LocationVerificationLabel: View {

    // MARK: - Property

    let isUserInsideGeofence: Bool

    fileprivate enum Constants {
        static let iconSize: CGFloat = 12
        static let spacing: CGFloat = 4
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Constants.spacing) {
            icon
                .frame(width: Constants.iconSize, height: Constants.iconSize)

            Text(isUserInsideGeofence
                 ? LocationStatusText.verified
                 : LocationStatusText.unverified)
                .appFont(.caption1, color: isUserInsideGeofence ? Color.indigo500 : Color.red500)
        }
    }

    // MARK: - View Component

    @ViewBuilder
    private var icon: some View {
        if isUserInsideGeofence {
            Image.umcVerifyLocation
                .resizable()
        } else {
            Image(systemName: "location.slash.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.red500)
        }
    }
}

// MARK: - LocationStatusBarContextPreview

/// 컨텍스트 메뉴 프리뷰 — 주소를 줄바꿈까지 허용해 전부 보여준다
private struct LocationStatusBarContextPreview: View {

    // MARK: - Property

    let isUserInsideGeofence: Bool
    let sessionAddress: String

    fileprivate enum Constants {
        static let spacing: CGFloat = 4
        static let rowSpacing: CGFloat = 8
        static let previewWidth: CGFloat = 320
    }

    // MARK: - Body

    var body: some View {
        // 상태 행(위) + 전체폭 주소 행(아래). 주소는 줄바꿈을 허용해 긴 주소도 전부 보인다.
        VStack(alignment: .leading, spacing: Constants.rowSpacing) {
            HStack(spacing: Constants.spacing) {
                LocationVerificationLabel(isUserInsideGeofence: isUserInsideGeofence)

                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: Constants.spacing) {
                Text(sessionAddress)
                    .appFont(.caption1, color: .grey600)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Color.grey500)
            }
        }
        .padding(DefaultConstant.defaultBtnPadding)
        .frame(width: Constants.previewWidth)
        .glassEffect()
    }
}

// MARK: - LocationStatusText

/// 위치 상태바에 노출되는 문구
private enum LocationStatusText {
    static let verified = "위치 인증됨"
    static let unverified = "위치 미인증"
    static let unknownAddress = "주소를 알 수 없습니다."
}

// MARK: - MarqueeText

/// 컨테이너 너비를 넘는 텍스트를 끊김 없이 좌측으로 흐르게 반복 스크롤하는 마퀴 텍스트.
///
/// 동일 텍스트 2벌을 `spacing` 간격으로 이어 붙인 뒤 "한 벌 너비 + 간격"만큼 이동시킵니다.
/// 2벌째가 1벌째의 시작 위치에 정확히 도달하는 순간 오프셋이 0으로 리셋되므로
/// 시각적으로 이음매(깜빡임)가 없습니다. 텍스트가 컨테이너 안에 들어가면 스크롤하지 않고
/// 우측 정렬로 고정 표시합니다.
///
/// - Note: 크기 기준은 `fixedSize` 없는 '고스트 텍스트'(한 줄 높이 + 부모 폭)로 고정하고,
///   보이는 마퀴는 그 위 overlay 의 `GeometryReader` 가 준 폭으로만 그립니다. 덕분에 콘텐츠의
///   intrinsic 폭이 부모 HStack 으로 새어 좌측 위치 상태를 밀어내는 일이 없습니다.
private struct MarqueeText: View {

    // MARK: - Property

    let text: String
    var color: Color = .grey600
    /// 초당 이동 거리(pt)
    var velocity: CGFloat = 30
    /// 반복되는 두 벌 사이의 간격(pt)
    var spacing: CGFloat = 48

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var needsScroll: Bool {
        textWidth > 0 && containerWidth > 0 && textWidth > containerWidth + 1
    }

    // MARK: - Body

    var body: some View {
        // 크기 기준 '고스트': lineLimit(1) 한 줄 높이 + 부모 폭(maxWidth:.infinity).
        // fixedSize 를 쓰지 않으므로 거대한 intrinsic 폭이 부모로 새어 위치 상태를
        // 화면 밖으로 밀어내는 일이 없다. 보이는 마퀴는 그 위 overlay 로만 그린다.
        Text(text)
            .appFont(.caption1, color: color)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .hidden()
            .overlay {
                GeometryReader { geo in
                    visibleMarquee(width: geo.size.width)
                        .onAppear { updateContainer(geo.size.width) }
                        .onChange(of: geo.size.width) { _, newWidth in
                            updateContainer(newWidth)
                        }
                }
            }
            .background(widthProbe)
    }

    // MARK: - View Component

    /// 실제로 보이는 마퀴. `width` 는 GeometryReader 가 준 확정 컨테이너 폭이라 순환 의존이 없다.
    @ViewBuilder
    private func visibleMarquee(width: CGFloat) -> some View {
        if needsScroll {
            HStack(spacing: spacing) {
                singleLine
                singleLine
            }
            .fixedSize()
            .offset(x: offset)
            .frame(width: width, alignment: .leading)
            .clipped()
        } else {
            singleLine
                .frame(width: width, alignment: .trailing)
        }
    }

    private var singleLine: some View {
        Text(text)
            .appFont(.caption1, color: color)
            .lineLimit(1)
            .fixedSize()
    }

    /// 텍스트 자연 폭 측정용 — background 라 부모 레이아웃에 영향이 없다.
    private var widthProbe: some View {
        Text(text)
            .appFont(.caption1, color: color)
            .lineLimit(1)
            .fixedSize()
            .hidden()
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: MarqueeSizeKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(MarqueeSizeKey.self) { width in
                guard width > 0, abs(width - textWidth) > 0.5 else { return }
                textWidth = width
                restartScrolling()
            }
    }

    // MARK: - Function

    private func updateContainer(_ width: CGFloat) {
        guard width > 0, abs(width - containerWidth) > 0.5 else { return }
        containerWidth = width
        restartScrolling()
    }

    private func restartScrolling() {
        offset = 0
        guard needsScroll else { return }
        let distance = textWidth + spacing
        withAnimation(
            .linear(duration: Double(distance / velocity))
                .repeatForever(autoreverses: false)
        ) {
            offset = -distance
        }
    }
}

private struct MarqueeSizeKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
