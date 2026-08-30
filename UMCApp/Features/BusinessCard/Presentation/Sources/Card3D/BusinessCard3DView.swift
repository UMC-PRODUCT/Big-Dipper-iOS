//
//  BusinessCard3DView.swift
//  BusinessCardPresentation
//

import BusinessCardDomain
import CoreDesignSystem
import OSLog
import RealityKit
import SwiftUI
import UMCFoundation

/// RealityKit 3D 명함 (#1247) — 드래그·자이로 회전과 탭 플립.
///
/// 시그니처를 ``BusinessCardFaceView`` 와 일치시켜 호출부 diff 가 식별자 하나로 끝난다.
/// 2D 폴백도 그 뷰 **그 자체**라 폴백 코드가 0 줄이다.
///
/// 회전은 SwiftUI 상태로 올라오지 않는다 — ``BusinessCard3DScene`` 이 엔티티 `transform`
/// 에 직접 기입한다(그 파일 헤더 참고). 여기서 `body` 를 돌리는 것은 준비 상태·뒤집힘·
/// 자이로 토글 셋뿐이고 전부 초당 몇 회 수준이다.
///
/// 뒷면은 이 시점에 **흰 QR 정사각과 자식 없는 링크 앵커**다. 온디바이스 합성(#1248)이
/// 그 위에 값을 얹는다 — 앵커 규약이 「주입에 실패해도 흰 정사각이 남아 빈 카드가 아니라
/// QR 없음으로 보인다」고 정해 둔 정상 중간 상태다.
public struct BusinessCard3DView: View {

    // MARK: - Property

    private let card: MyCard
    private let isFlipped: Bool
    private let qrImage: CGImage?
    private let onFlip: (() -> Void)?
    private let onExchange: (() -> Void)?
    private let onQR: (() -> Void)?
    private let makeEntity: @MainActor @Sendable (MyCard) async throws -> Entity

    @State private var scene = BusinessCard3DScene()
    @State private var phase: CardScenePhase = .loading

    @AppStorage(AppStorageKey.businessCardGyroEnabled) private var isGyroEnabled = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverRunning
    @Environment(\.scenePhase) private var appScenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Init

    /// - Parameter makeEntity: 카드 엔티티 생성 seam. 기본값은 베이스 템플릿 로드 한 줄이고,
    ///   온디바이스 합성(#1248)이 이 기본값만 합성기 호출로 바꾼다. 프리뷰·테스트도 여기로
    ///   주입한다 — 구현체가 하나뿐인 프로토콜을 만들지 않는다.
    public init(
        card: MyCard,
        isFlipped: Bool = false,
        qrImage: CGImage? = nil,
        onFlip: (() -> Void)? = nil,
        onExchange: (() -> Void)? = nil,
        onQR: (() -> Void)? = nil,
        makeEntity: @escaping @MainActor @Sendable (MyCard) async throws -> Entity = { _ in
            try await BusinessCardTemplate.load()
        }
    ) {
        self.card = card
        self.isFlipped = isFlipped
        self.qrImage = qrImage
        self.onFlip = onFlip
        self.onExchange = onExchange
        self.onQR = onQR
        self.makeEntity = makeEntity
    }

    // MARK: - Body

    public var body: some View {
        cardContent
            // 2D 폴백 → 3D 는 액션 버튼 모양·카드 높이가 함께 바뀌는 교체다. 하드컷이면
            // 화면이 한 번 다시 그려진 것처럼 읽히므로 크로스페이드로 잇는다.
            // Reduce Motion 이면 즉시 — 이 전환은 사용자가 만들지 않은 자율 모션이다.
            .animation(
                reduceMotion ? nil : .easeInOut(duration: Card3DMetrics.crossfadeDuration),
                value: renderMode
            )
            // 접근성 글자 크기로 넘어가면 3D 를 버리고 2D 로 가는데, 되돌아왔을 때 다시
            // 3D 가 되려면 로드를 한 번 더 시도할 수 있어야 한다.
            .task(id: dynamicTypeSize.isAccessibilitySize) { await loadSceneIfNeeded() }
            // 로드가 끝난 그 프레임의 **최신** 뒤집힘으로 첫 자세를 세운다. `.task` 안에서
            // 세우면 로드 시작 시점 값이 굳어 로드 중에 누른 플립이 되돌아간다.
            .onChange(of: phase) { _, newPhase in
                guard newPhase == .ready else { return }
                scene.setFlipped(isFlipped, duration: 0)
            }
            .onChange(of: isFlipped) { _, flipped in
                scene.setFlipped(
                    flipped,
                    duration: CardInteractionPolicy.flipDuration(reduceMotion: reduceMotion)
                )
            }
            // 이 두 줄이 화면 이탈·백그라운드 진입·토글·Reduce Motion·VoiceOver·
            // 하드웨어 부재를 전부 덮는다.
            .onChange(of: isGyroActive, initial: true) { _, isActive in
                scene.setMotionActive(isActive)
            }
            .onDisappear { scene.setMotionActive(false) }
    }

    // MARK: - View Component

    @ViewBuilder
    private var cardContent: some View {
        switch renderMode {
        case .twoDimensional:
            BusinessCardFaceView(
                card: card,
                isFlipped: isFlipped,
                qrImage: qrImage,
                onFlip: onFlip,
                onExchange: onExchange,
                onQR: onQR
            )

        case .threeDimensional:
            VStack(spacing: Card3DMetrics.blockSpacing) {
                cardSurface
                if hasActions { actionRow }
            }
        }
    }

    private var cardSurface: some View {
        ZStack(alignment: .topTrailing) {
            RealityView { content in
                scene.attach(to: &content)
            }
            .aspectRatio(Card3DMetrics.cardAspectRatio, contentMode: .fit)
            // `.simultaneousGesture` 가 아니다 — 스크롤과 함께 인식되면 스크롤할 때마다
            // 카드가 요동친다. 카드 위가 스크롤 데드존이 되는 것을 알고 감수한다(지도·페이저와
            // 같은 취급). `minimumDistance` 를 지정하지 않아 10pt 미만 터치는 탭으로 간다.
            .gesture(dragGesture)
            .onTapGesture { onFlip?() }
            // RealityView 는 VoiceOver 에 아무것도 주지 않는다 — 하나의 요소로 합쳐 명시한다.
            // 「끌어서 기울일 수 있어요」 힌트는 넣지 않는다: 힌트를 듣는 사람에게는
            // VoiceOver 가 제스처를 가로채 드래그가 동작하지 않아 잘못된 안내가 된다.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(faceLabel)
            .accessibilityAddTraits(onFlip == nil ? [] : .isButton)
            .accessibilityActions {
                if let onFlip {
                    Button(Constants.flipAction, action: onFlip)
                }
            }

            // 오버레이는 ZStack 형제로 둔다 — realityLayer 안에 넣으면
            // `children: .ignore` 가 버튼을 삼킨다.
            controlOverlay
        }
    }

    /// 인접한 글래스 둘은 `GlassEffectContainer` 로 묶는다 — 레포 규약이자
    /// 오프스크린 렌더링을 줄이는 장치다 (`docs/claude/design-system.md`).
    private var controlOverlay: some View {
        GlassEffectContainer(spacing: Card3DMetrics.controlSpacing) {
            HStack(spacing: Card3DMetrics.controlSpacing) {
                if isGyroControlVisible { gyroButton }
                if onFlip != nil { flipButton }
            }
        }
        .padding(Card3DMetrics.controlMargin)
    }

    /// 2D 카드 플립 버튼과 같은 물건이다 — 두 경로에서 버튼이 다르면 로드 타이밍에 따라
    /// UI 가 바뀐 것처럼 읽힌다.
    private var flipButton: some View {
        CardGlassCircleButton(
            systemName: Constants.flipIcon,
            label: isFlipped ? Constants.flipToFront : Constants.flipToBack
        ) {
            onFlip?()
        }
    }

    /// VoiceOver 구동 중에도 버튼은 남긴다 — 자이로 토글은 기기 단위 설정이라
    /// VoiceOver 를 끈 뒤에 적용된다. 지금 효과가 없다고 설정 자체를 숨기면
    /// 스크린리더 사용자만 이 설정에 접근할 수 없게 된다.
    private var gyroButton: some View {
        CardGlassCircleButton(
            systemName: Constants.gyroIcon,
            label: isGyroEnabled ? Constants.gyroDisable : Constants.gyroEnable,
            isOn: isGyroEnabled
        ) {
            isGyroEnabled.toggle()
        }
    }

    /// 3D 카드는 메시라 SwiftUI 버튼을 표면에 올릴 수 없다. 설계서 §5.1 이 정한 대로
    /// 히어로 **아래** 독립 행으로 뺀다.
    ///
    /// 2D 카드의 흰 캡슐을 그대로 못 쓴다 — 그 캡슐은 인디고 배경 위라서 성립한다.
    /// 카드 밖은 페이지 배경이라 흰 캡슐이면 대비가 무너진다. `CardActionButton` 은
    /// 중립 배경 위에 쓰라고 만든 물건이라 새 스타일을 만들 필요가 없다.
    private var actionRow: some View {
        HStack(spacing: Card3DMetrics.actionSpacing) {
            if let onExchange {
                CardActionButton(
                    title: Constants.exchangeTitle,
                    role: .primary,
                    action: onExchange
                )
            }
            if let onQR {
                CardActionButton(title: Constants.qrTitle, role: .secondary, action: onQR)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { scene.drag(by: $0.translation) }
            .onEnded { _ in scene.endDrag() }
    }

    // MARK: - Function

    private var renderMode: CardRenderMode {
        CardInteractionPolicy.renderMode(phase: phase, dynamicTypeSize: dynamicTypeSize)
    }

    /// 2D 를 그리는 동안에는 센서를 켜지 않는다 — 화면에 없는 회전에 배터리를 쓸 이유가 없다.
    private var isGyroActive: Bool {
        renderMode == .threeDimensional
            && CardInteractionPolicy.shouldRunGyro(
                isEnabled: isGyroEnabled,
                reduceMotion: reduceMotion,
                isVoiceOverRunning: isVoiceOverRunning,
                scenePhase: appScenePhase,
                isHardwareAvailable: scene.isDeviceMotionAvailable
            )
    }

    /// 눌러도 아무 일 없는 컨트롤을 남기느니 숨긴다. 시뮬레이터에는 자이로가 없어
    /// 플립 버튼만 보인다.
    private var isGyroControlVisible: Bool {
        !reduceMotion && scene.isDeviceMotionAvailable
    }

    private var hasActions: Bool {
        onExchange != nil || onQR != nil
    }

    /// 라벨이 바뀌면 VoiceOver 가 포커스된 요소를 다시 읽으므로 별도 알림을 넣지 않는다.
    private var faceLabel: String {
        isFlipped ? card.backFaceAccessibilityLabel : card.frontFaceAccessibilityLabel
    }

    /// 실패해도 사용자에게 알리지 않는다 — 동작하는 2D 카드가 그대로 있고,
    /// 「3D 로 못 그렸다」는 사용자가 할 수 있는 일이 없는 정보다. 대신 로그로 남긴다.
    private func loadSceneIfNeeded() async {
        guard !dynamicTypeSize.isAccessibilitySize, phase == .loading else { return }

        let startedAt = Date()
        do {
            try await scene.load(card: card, makeEntity: makeEntity)
            phase = .ready
            let elapsed = Int(Date().timeIntervalSince(startedAt) * 1_000)
            logger.info("3D 카드 로드 \(elapsed)ms")
        } catch {
            logger.error("3D 카드 로드 실패, 2D 로 폴백: \(error.localizedDescription)")
            phase = .failed
        }
    }
}

// MARK: - Constants

private enum Constants {
    static let flipIcon = "arrow.2.squarepath"
    static let gyroIcon = "gyroscope"
    static let flipToBack = "명함 뒷면 보기"
    static let flipToFront = "명함 앞면 보기"
    static let flipAction = "명함 뒤집기"
    static let gyroEnable = "자이로 회전 켜기"
    static let gyroDisable = "자이로 회전 끄기"
    static let exchangeTitle = "명함 교환"
    static let qrTitle = "QR 코드"
}

/// 실기기 첫 로드 지연은 Console.app 에서 이 한 줄로 읽는다 — `OSSignposter` 계측
/// 하네스를 따로 만들지 않는다(회전 fps·배터리는 Instruments·Organizer 가 이미 준다).
private let logger = Logger(
    subsystem: "dev.umc.feature.businesscard",
    category: "BusinessCard3D"
)

// MARK: - Preview

#if DEBUG
#Preview("3D 앞면") {
    BusinessCard3DView(
        card: BusinessCardPreviewData.myCard,
        onFlip: {},
        onExchange: {},
        onQR: {}
    )
    .padding(.horizontal, 14)
    .frame(maxHeight: .infinity)
    .background(Color.grey100)
}

#Preview("3D 뒷면") {
    BusinessCard3DView(
        card: BusinessCardPreviewData.myCard,
        isFlipped: true,
        onFlip: {}
    )
    .padding(.horizontal, 14)
    .frame(maxHeight: .infinity)
    .background(Color.grey100)
}

#Preview("합성 실패 폴백") {
    BusinessCard3DView(
        card: BusinessCardPreviewData.myCard,
        onFlip: {},
        onExchange: {},
        onQR: {},
        makeEntity: { _ in
            throw BusinessCardTemplate.TemplateError.assetMissing("BusinessCardTemplate")
        }
    )
    .padding(.horizontal, 14)
    .frame(maxHeight: .infinity)
    .background(Color.grey100)
}
#endif
