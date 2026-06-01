//
//  ActivityCompactMapView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/14/26.
//

import SwiftUI
import UIKit

/// 활동 상세 화면에서 사용하는 컴팩트 지도 뷰
///
/// 지오펜싱 기반 출석 체크 상태와 세션 위치를 표시합니다.
/// - 지도 인터랙션 비활성화 (disabled)
/// - 하단 상태바: 위치 인증 상태, 주소 표시
struct ActivityCompactMapView: View {
    @Bindable private var mapViewModel: BaseMapViewModel
    private var info: SessionInfo

    init(
        mapViewModel: BaseMapViewModel,
        info: SessionInfo
    ) {
        self.mapViewModel = mapViewModel
        self.info = info
    }
    
    private enum Constants {
        static let mapComponentHeight: CGFloat = 200
        static let mapCornerRadius: Edge.Corner.Style = 24
    }
    
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
                isUniform: true))
            .task {
                await mapViewModel.startGeofenceForAttendance(info: info)
                await mapViewModel.updateAddressForSession(info: info)
                mapViewModel.startLocationUpdate()
            }
            .onDisappear {
                mapViewModel.stopLocationUpdate()
            }
    }
}

/// 지도 하단의 위치 상태 표시바
fileprivate struct LocationStatusBarView: View {
    @Bindable private var mapViewModel: BaseMapViewModel

    init(mapViewModel: BaseMapViewModel) {
        self.mapViewModel = mapViewModel
    }

    private enum Constants {
        static let statusBarPadding: CGFloat = 16
        static let verifyIconSize: CGFloat = 12
        static let statusBarSpacing: CGFloat = 4
        static let contextMenuIconSize: CGFloat = 12
        static let addressVerticalPadding: CGFloat = 4
    }
    
    var body: some View {
        HStack(spacing: Constants.statusBarSpacing) {
            verifyLocationStatus
            address
        }
        .padding(DefaultConstant.defaultBtnPadding)
        .glassEffect()
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
                sessionAddress: mapViewModel.sessionAddress ?? "주소를 알 수 없습니다."
            )
        }
    }
    
    /// 지오펜스 내 위치 인증 상태 표시
    private var verifyLocationStatus: some View {
        HStack(spacing: Constants.statusBarSpacing) {
            if mapViewModel.isUserInsideGeofence {
                Image(.Map.verifyLocation)
                    .resizable()
                    .frame(
                        width: Constants.verifyIconSize,
                        height: Constants.verifyIconSize)
            } else {
                Image(systemName: "location.slash.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: Constants.verifyIconSize,
                        height: Constants.verifyIconSize)
                    .foregroundStyle(.red)
            }

            Text(mapViewModel.isUserInsideGeofence
                 ? "위치 인증됨" : "위치 미인증")
                .appFont(.caption1,
                    color: mapViewModel.isUserInsideGeofence
                         ? .indigo500 : .red)
        }
    }
    
    /// 세션 위치의 주소 (역지오코딩 결과)
    private var address: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            MarqueeText(text: mapViewModel.sessionAddress ?? "주소를 알 수 없습니다.")
                .frame(maxWidth: .infinity)

            Image(systemName: "ellipsis.circle")
                .font(.system(size: Constants.contextMenuIconSize))
                .foregroundStyle(.grey500)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, Constants.addressVerticalPadding)
        .padding(.leading, DefaultSpacing.spacing8)
        .accessibilityHint("길게 눌러 주소 관련 메뉴를 엽니다")
    }

    private func copyAddress() {
        guard let address = mapViewModel.sessionAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty else { return }

        UIPasteboard.general.string = address
        triggerCopyHaptic()
    }

    private func triggerCopyHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

private struct LocationStatusBarContextPreview: View {
    let isUserInsideGeofence: Bool
    let sessionAddress: String

    private enum Constants {
        static let verifyIconSize: CGFloat = 12
        static let spacing: CGFloat = 4
        static let previewWidth: CGFloat = 320
    }

    var body: some View {
        HStack(spacing: Constants.spacing) {
            HStack(spacing: Constants.spacing) {
                if isUserInsideGeofence {
                    Image(.Map.verifyLocation)
                        .resizable()
                        .frame(width: Constants.verifyIconSize, height: Constants.verifyIconSize)
                } else {
                    Image(systemName: "location.slash.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: Constants.verifyIconSize, height: Constants.verifyIconSize)
                        .foregroundStyle(.red)
                }

                Text(isUserInsideGeofence ? "위치 인증됨" : "위치 미인증")
                    .appFont(.caption1, color: isUserInsideGeofence ? .indigo500 : .red)
            }

            Spacer(minLength: 0)

            Text(sessionAddress)
                .appFont(.caption1, color: .grey600)
                .lineLimit(1)

            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.grey500)
        }
        .padding(DefaultConstant.defaultBtnPadding)
        .frame(width: Constants.previewWidth)
        .glassEffect()
    }
}

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
fileprivate struct MarqueeText: View {

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

#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    ActivityCompactMapView(
        mapViewModel: BaseMapViewModel(
            container: AttendancePreviewData.container,
            info: AttendancePreviewData.sessionInfo,
            errorHandler: AttendancePreviewData.errorHandler
        ),
        info: AttendancePreviewData.sessionInfo
    )
    .padding(.horizontal)
    .task {
        LocationManager.shared.requestAuthorization()
    }
}
#endif
