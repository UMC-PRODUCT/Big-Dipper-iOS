import SwiftUI

/// 워치 전용 레이아웃 상수. iOS `DefaultConstant` 는 탭바·44pt 터치 타깃 등
/// 폰 전제 값이라 워치에서 재사용하지 않는다.
public enum WatchLayout {

    /// 카드/리스트 행 모서리. `ConcentricRectangle(corners: .concentric(minimum:))` 에 넣어
    /// 워치 디스플레이 곡률과 동심으로 맞춘다.
    public static let cardCornerRadius: Edge.Corner.Style = 22

    /// 카드 보더 두께.
    public static let cardBorderWidth: CGFloat = 1
    /// 카드 내부 패딩. 화면이 좁아 iOS(16~24)보다 타이트하게 잡는다.
    public static let cardContentPadding: CGFloat = 12
    /// 화면 좌우 인셋. 카드가 디스플레이 곡률에 물리지 않을 최소값.
    public static let screenHorizontalPadding: CGFloat = 4
    /// 카드/섹션 사이 세로 간격.
    public static let stackSpacing: CGFloat = 8
    /// 라벨-값, 버튼-사유 캡션처럼 붙는 요소 사이 간격.
    public static let tightSpacing: CGFloat = 4
    /// 긴급 표시용 좌측 색바 두께 (#1208).
    public static let accentBarWidth: CGFloat = 3
}
