import Foundation
import UMCFoundation

/// 홈 일정 캘린더가 표시하는 일정 상세 모델.
///
/// 서버 V2 스키마는 목록/상세 응답이 동일한 형태이므로 단일 모델로 양쪽을 지원한다.
/// 슬라이스 2(#914) 범위는 캘린더 표시에 필요한 필드만 다루며, 장소/참여자/출석 정책 등은
/// 출석·등록 기능 이식 시 별도로 확장한다.
public struct ScheduleDetailData: Equatable, Identifiable, Sendable {

    // MARK: - Property

    public var id: String { scheduleId }

    public let scheduleId: String
    public let name: String
    public let description: String
    public let tags: [String]
    public let startsAt: Date
    public let endsAt: Date
    public let isParticipant: Bool

    // MARK: - Init

    public init(
        scheduleId: String,
        name: String,
        description: String,
        tags: [String],
        startsAt: Date,
        endsAt: Date,
        isParticipant: Bool
    ) {
        self.scheduleId = scheduleId
        self.name = name
        self.description = description
        self.tags = tags
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isParticipant = isParticipant
    }

    // MARK: - Computed

    /// KST 기준 오늘 자정과 일정 시작 자정의 일수 차. 양수는 미래, 음수는 과거, 0은 오늘.
    public var dDay: Int {
        let calendar = Calendar.kstGregorian
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: startsAt)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    /// `dDay` 부호 규칙에 맞춘 화면 표시용 문자열 (미래: `D-N`, 과거: `D+N`, 오늘: `D-Day`).
    public var dDayText: String {
        if dDay > 0 {
            return "D-\(dDay)"
        }
        if dDay < 0 {
            return "D+\(abs(dDay))"
        }
        return "D-Day"
    }

    /// 종료/참여 여부 기반 표시 텍스트. 종료된 일정이면 `"종료됨"`, 그 외에는 참여 여부를 표시한다.
    public var participationStatusText: String {
        if Date() > endsAt {
            return "종료됨"
        }
        return isParticipant ? "참여 예정" : "참여 안 함"
    }
}
