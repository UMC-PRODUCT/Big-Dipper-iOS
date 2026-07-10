#if DEBUG
/// 디버그 빌드 전용 — 실제 Firebase 콘솔 값과 무관하게 점검·강제 업데이트 오버레이를
/// 강제로 노출시키는 토글. QA/개발 중 오버레이 UI를 즉시 확인하고 싶을 때 사용한다.
///
/// - Note: 디버그 메뉴 등에서 임의 시점에 값을 바꿔 쓰는 용도라 `nonisolated(unsafe)`로
///   선언한다. 릴리스 빌드에는 포함되지 않는다(절대 규칙 #5).
public enum MaintenanceDebugOverride {
    nonisolated(unsafe) public static var isMaintenanceForced = false
    nonisolated(unsafe) public static var isForceUpdateForced = false
    nonisolated(unsafe) public static var forcedMinimumVersion = "9999.0.0"
}
#endif
