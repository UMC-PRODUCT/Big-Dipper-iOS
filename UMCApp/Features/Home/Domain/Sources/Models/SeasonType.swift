/// 홈 시즌 카드가 표시하는 값의 종류.
///
/// 소속 기수가 없으면 누적 활동일(`days`), 있으면 소속 기수 목록(`gens`)을 표시한다.
public enum SeasonType: Equatable, Sendable {
    /// 누적 활동일 (기수 미배정 상태)
    case days(Int)
    /// 소속 기수 번호 목록 (서버 정수는 절대규칙 #2에 따라 `String`으로 유지)
    case gens([String])
}
