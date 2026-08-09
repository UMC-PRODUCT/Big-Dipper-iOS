//
//  ScheduleRegistrationViewModel+AI.swift
//  HomePresentation
//
//  Created by euijjang97 on 5/31/26.
//

import Foundation
import FoundationModels
import NoticeDomain
import SwiftData
import UMCFoundation

fileprivate enum Constants {
    static let fallbackDuration: TimeInterval = 3_600
    static let instructions = """
    당신은 한국 대학 동아리 일정 등록을 돕는 보조 시스템입니다.
    사용자가 입력한 자연어 일정 설명에서 필요한 정보를 추출하세요.
    날짜/시간이 명확하지 않으면 합리적인 기본값을 사용하세요.
    장소는 이름만 추출하고 좌표나 주소는 절대 생성하지 마세요.
    오늘 날짜는 현재 시스템 날짜를 기준으로 합니다.
    """
}

extension ScheduleRegistrationViewModel {

    // MARK: - Function

    /// 온디바이스 AI로 자연어 일정 설명을 분석해 폼 필드를 자동으로 채운다.
    ///
    /// 장소 좌표는 절대 AI 로 채우지 않는다. `placeName` 만 제안으로 반영하고 좌표는 (0, 0) 으로
    /// 남겨, 사용자가 지도에서 장소를 확정하기 전까지는 제출이 열리지 않게 한다. 참여자와 출석
    /// 정책도 건드리지 않는다.
    func requestAIAutofill() async {
        let rawText = aiRawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty, !aiAutofillState.isLoading else { return }
        // 툴바 진입 버튼이 이미 가용성으로 가려져 있어 보통은 여기까지 오지 않는다. 시트를 연 뒤
        // 설정에서 Apple Intelligence 가 꺼질 수 있어 마지막 방어선으로 남긴다.
        guard case .available = SystemLanguageModel.default.availability else {
            aiAutofillState = .failed(
                .unknown(message: "이 기기에서는 Apple Intelligence를 사용할 수 없습니다.")
            )
            return
        }

        aiAutofillState = .loading

        do {
            let session = LanguageModelSession { Constants.instructions }
            let response = try await session.respond(to: rawText, generating: ScheduleDraft.self)
            applyDraft(response.content)
            await persistDailyTokenUsage(session: session)
            aiAutofillState = .loaded(true)
        } catch {
            // 시트를 띄운 채 문장을 고쳐 바로 재시도할 수 있도록 전역 Alert 대신 인라인으로 알린다.
            aiAutofillState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// AI 자동완성 상태를 초기로 되돌린다. (시트를 닫을 때 호출)
    func resetAIAutofillState() {
        aiAutofillState = .idle
    }

    /// 화면 진입 시 당일 누적 토큰 사용량을 복원한다.
    ///
    /// 복원에 실패해도 0 을 유지하며 등록 흐름에는 영향이 없다.
    func restoreDailyTokenUsage() {
        guard let modelContext, let currentMemberId = AppStorageKey.memberIdString() else {
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        do {
            let records = try modelContext.fetch(FetchDescriptor<AITokenDailyUsageRecord>())
            if let record = records.first(where: {
                $0.memberId == currentMemberId && $0.date == today
            }) {
                aiCumulativeUsedTokens = record.usedTokens
            }
        } catch {
            // 복원 실패해도 일정 등록 동작에 영향 없음
        }
    }

    // MARK: - Private Function

    /// ``ScheduleDraft`` 결과를 폼 필드에 반영한다.
    ///
    /// ISO 8601 파싱에 실패한 필드는 기존 값을 유지한다.
    private func applyDraft(_ draft: ScheduleDraft) {
        if !draft.title.isEmpty {
            title = draft.title
        }

        if let start = Self.parseISODate(draft.startDateISO) {
            startDate = start
            if let parsedEnd = Self.parseISODate(draft.endDateISO), parsedEnd > start {
                endDate = parsedEnd
            } else {
                endDate = start.addingTimeInterval(Constants.fallbackDuration)
            }
        }

        isAllDay = draft.isAllDay

        if let category = ScheduleIconCategory(rawValue: draft.tag), !category.isDeprecated {
            updateTagsFromUser([category])
        }

        if !draft.memo.isEmpty {
            memo = draft.memo
        }

        // 좌표 없이 이름만 채우므로 hasValidPlace 가 거짓으로 남아 제출이 막힌다. 사용자가 지도에서
        // 장소를 확정해야 (0, 0) 기준 지오펜스가 만들어지지 않는다.
        if !draft.placeName.isEmpty {
            placeSelectionChanged(name: draft.placeName, address: "", latitude: 0, longitude: 0)
        }

        prefillAttendancePolicyIfNeeded()
    }

    /// 소수점 초 유무를 모두 허용해 ISO 8601 문자열을 파싱한다.
    ///
    /// 온디바이스 모델이 두 형식을 오가며 내놓기 때문에 한 포맷터만으로는 파싱이 자주 실패한다.
    private static func parseISODate(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]
        return withFraction.date(from: string) ?? withoutFraction.date(from: string)
    }

    /// AI 실행 후 당일 토큰 사용량을 SwiftData 에 누적 기록한다.
    ///
    /// 컨텍스트가 없거나 저장에 실패해도 AI 결과에는 영향이 없다.
    private func persistDailyTokenUsage(session: LanguageModelSession) async {
        guard #available(iOS 26.4, *) else { return }
        guard let modelContext, let currentMemberId = AppStorageKey.memberIdString() else {
            return
        }

        let used: Int
        do {
            used = try await SystemLanguageModel.default.tokenCount(for: session.transcript)
        } catch {
            return
        }
        guard used > 0 else { return }

        let today = Calendar.current.startOfDay(for: Date())
        do {
            let records = try modelContext.fetch(FetchDescriptor<AITokenDailyUsageRecord>())
            if let record = records.first(where: {
                $0.memberId == currentMemberId && $0.date == today
            }) {
                record.usedTokens += used
            } else {
                modelContext.insert(AITokenDailyUsageRecord(
                    memberId: currentMemberId,
                    date: today,
                    usedTokens: used
                ))
            }
            try modelContext.save()
            aiCumulativeUsedTokens += used
        } catch {
            // 저장 실패해도 AI 실행 결과에 영향 없음
        }
    }
}
