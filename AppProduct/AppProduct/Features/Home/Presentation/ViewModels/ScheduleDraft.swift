//
//  ScheduleDraft.swift
//  AppProduct
//
//  Created by euijjang97 on 5/31/26.
//

import Foundation
import FoundationModels

/// 온디바이스 LLM이 자연어 입력으로부터 추출하는 일정 초안 구조체.
///
/// 장소 좌표는 환각 위험이 높아 절대 포함하지 않습니다.
/// 장소 이름만 제안하며, 실제 좌표 확정은 사용자가 장소 검색 플로우에서 수행합니다.
/// 참여자 목록 및 출석 정책은 AI 가 건드리지 않습니다.
///
/// `startDateISO` / `endDateISO` 는 LLM 이 반환한 ISO 8601 문자열입니다.
/// `applyDraft(_:)` 에서 `ISO8601DateFormatter` 로 파싱한 뒤 ViewModel 필드에 매핑합니다.
@Generable(description: "자연어 일정 설명에서 추출한 일정 초안")
struct ScheduleDraft {

    // MARK: - Property

    @Guide(description: "일정 제목. 자연어에서 핵심 이름을 추출합니다. 예: '다음주 화요일 스터디 모임' → '스터디 모임'")
    var title: String

    @Guide(description: """
    일정 시작 시각 (ISO 8601 형식). 자연어 날짜/시간 표현을 파싱합니다.
    예: '다음주 화요일 오후 2시' → '2026-06-09T14:00:00+09:00'
    '내일 저녁 7시' → 내일 날짜로 계산.
    시각이 명시되지 않으면 해당 날짜의 09:00:00+09:00 로 기본 설정합니다.
    """)
    var startDateISO: String

    @Guide(description: """
    일정 종료 시각 (ISO 8601 형식). 명시되지 않은 경우 startDateISO + 1시간으로 추정합니다.
    """)
    var endDateISO: String

    @Guide(description: "하루 종일 일정 여부. '하루종일', '종일', '전일' 같은 표현이 있거나 시각이 명시되지 않으면 true.")
    var isAllDay: Bool

    @Guide(description: """
    일정 카테고리. 다음 rawValue 중 하나를 정확히 반환하세요:
    LEADERSHIP, DUES, MEETING, NETWORKING, HACKATHON, PROJECT,
    PRESENTATION, WORKSHOP, RETROSPECTIVE, AFTER_PARTY, ORIENTATION, GENERAL.
    입력에 가장 잘 맞는 카테고리를 선택하세요.
    """)
    var tag: String

    @Guide(description: "일정에 대한 추가 메모나 설명. 자연어 입력에서 부가 내용을 추출합니다. 없으면 빈 문자열.")
    var memo: String

    @Guide(description: "장소 이름만 추출합니다. 좌표나 주소는 절대 포함하지 않습니다. 장소 언급이 없으면 빈 문자열.")
    var placeName: String
}
