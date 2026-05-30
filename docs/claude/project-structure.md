# 프로젝트 구조 (AppProduct)

> 레거시 `AppProduct/` 디렉터리 구조 레퍼런스. (Tuist `UMCApp/` 구조는 `docs/claude/build-and-modules.md` 참고)
> 핵심 요약은 `CLAUDE.md` 참고.

```
AppProduct/AppProduct/
├── Core/
│   ├── Alert/              # AlertPrompt 등 확인 다이얼로그
│   ├── Common/
│   │   ├── DesignSystem/   # 디자인 토큰, 스타일
│   │   ├── Enum/           # DefaultConstant, DefaultSpacing 등
│   │   ├── Error/          # Loadable, ErrorHandler, AppError 등
│   │   └── UIComponents/   # 공용 UI 컴포넌트
│   ├── DIContainer/        # 의존성 주입 컨테이너
│   ├── Manager/            # 인증, 위치 등 시스템 매니저
│   ├── Mock/               # 테스트용 Mock View (개발 전용)
│   ├── Navigation/         # 네비게이션 라우팅
│   ├── NetworkAdapter/     # Moya 기반 네트워크 클라이언트
│   └── Secret/             # API 키 등 민감 정보
├── Utilities/
│   ├── Extensions/         # Swift/SwiftUI 확장
│   ├── Keychain/           # 키체인 유틸리티
│   ├── Modifier/           # 커스텀 ViewModifier
│   ├── RemoteImage/        # 원격 이미지 로딩
│   ├── Shadow/             # 그림자 유틸리티
│   └── ToolBar/            # 툴바 헬퍼
└── Features/
    ├── Activity/           # 출석, 스터디 관리
    ├── Auth/               # 로그인, 회원가입
    ├── Community/          # 커뮤니티, 명예의전당
    ├── Home/               # 홈 대시보드, 일정 관리
    ├── MyPage/             # 마이페이지, 프로필
    ├── Notice/             # 공지사항
    ├── Splash/             # 스플래시 화면
    └── Tab/                # 탭 네비게이션
```
