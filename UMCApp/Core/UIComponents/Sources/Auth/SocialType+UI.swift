import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// `SocialType`의 UI 프로퍼티(로고 이미지, 브랜드 컬러, 버튼 문구).
///
/// `SocialType` 자체는 UMCFoundation(Domain에 가까운 순수 열거형)에 있고,
/// 이미지·색상 등 View 종속 프로퍼티만 CoreUIComponents에서 확장한다.
public extension SocialType {

    /// 로그인 버튼에 노출할 문구 ("카카오로 계속하기" 등).
    var loginButtonTitle: String {
        switch self {
        case .kakao:
            return "카카오로 계속하기"
        case .apple:
            return "Apple로 계속하기"
        case .google:
            return "Google로 계속하기"
        }
    }

    /// 마이페이지 연동 섹션 등에서 사용하는 표시용 서비스 이름.
    var displayName: String {
        switch self {
        case .kakao:
            return "카카오"
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        }
    }

    /// 소셜 타입에 해당하는 로고 이미지.
    var image: Image {
        switch self {
        case .kakao:
            return Image("kakaoIcon", bundle: .module)
        case .apple:
            return Image("appleIcon", bundle: .module)
        case .google:
            return Image("google", bundle: .module)
        }
    }

    /// 소셜 타입별 브랜드 배경 색상.
    var color: Color {
        switch self {
        case .kakao:
            return .kakao
        case .apple:
            return .black
        case .google:
            return .clear // 아웃라인 스타일 — 회색 테두리는 LoginActionStack에서 처리
        }
    }

    /// 소셜 버튼 위 텍스트/아이콘 색상.
    var fontColor: Color {
        switch self {
        case .kakao:
            return .black
        case .apple:
            return .white
        case .google:
            return .black
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .kakao:
            return 20
        case .apple, .google:
            return 24
        }
    }
}
