//
//  ScheduleRegistrationViewModel+AI.swift
//  AppProduct
//
//  Created by euijjang97 on 5/31/26.
//

import Foundation
import FoundationModels
import SwiftData

extension ScheduleRegistrationViewModel {

    // MARK: - Function

    /// 온디바이스 AI로 자연어 일정 설명을 분석해 폼 필드를 자동으로 채웁니다.
    ///
    /// - 장소 좌표는 절대 AI로 채우지 않습니다. `placeName` 만 제안 텍스트로 반영하며,
    ///   실제 좌표 확정은 기존 장소 검색 플로우에서 사용자가 수행합니다.
    /// - 참여자(`participatn`) 및 출석 정책은 건드리지 않습니다.
    /// - AI 미지원 기기에서는 상태를 `.failed` 로 설정하고 조기 반환합니다.
    @MainActor
    func requestAIAutofill() async {
        let rawText = aiRawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else { return }
        if case .loading = aiAutofillState { return }

        guard case .available = SystemLanguageModel.default.availability else {
            aiAutofillState = .failed(
                .unknown(message: "이 기기에서는 Apple Intelligence를 사용할 수 없습니다.")
            )
            return
        }

        aiAutofillState = .loading

        do {
            let session = LanguageModelSession {
                """
                당신은 한국 대학 동아리 일정 등록을 돕는 보조 시스템입니다.
                사용자가 입력한 자연어 일정 설명에서 필요한 정보를 추출하세요.
                날짜/시간이 명확하지 않으면 합리적인 기본값을 사용하세요.
                장소는 이름만 추출하고 좌표나 주소는 절대 생성하지 마세요.
                오늘 날짜는 현재 시스템 날짜를 기준으로 합니다.
                """
            }

            let response = try await session.respond(to: rawText, generating: ScheduleDraft.self)
            applyDraft(response.content)
            await persistDailyTokenUsage(session: session)
            aiAutofillState = .loaded(true)
        } catch {
            aiAutofillState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// AI 자동완성 상태를 초기로 되돌립니다.
    @MainActor
    func resetAIAutofillState() {
        aiAutofillState = .idle
    }

    // MARK: - Private Function

    /// `ScheduleDraft` 결과를 ViewModel 폼 필드에 반영합니다.
    ///
    /// - ISO 8601 날짜 파싱에 실패하면 해당 필드는 기존 값을 유지합니다.
    /// - placeName 이 비어있지 않으면 place 이름만 덮어쓰고 좌표는 0,0 으로 유지합니다.
    ///   사용자가 이후 장소 검색 플로우를 통해 좌표를 확정해야 합니다.
    @MainActor
    private func applyDraft(_ draft: ScheduleDraft) {
        if !draft.title.isEmpty {
            title = draft.title
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterNoFraction = ISO8601DateFormatter()
        formatterNoFraction.formatOptions = [.withInternetDateTime]

        func parseISO(_ string: String) -> Date? {
            formatter.date(from: string) ?? formatterNoFraction.date(from: string)
        }

        if let start = parseISO(draft.startDateISO) {
            let end: Date
            if let parsedEnd = parseISO(draft.endDateISO), parsedEnd > start {
                end = parsedEnd
            } else {
                end = start.addingTimeInterval(3600)
            }
            dataRange = DateRange(startDate: start, endDate: end)
        }

        isAllDay = draft.isAllDay

        if let category = ScheduleIconCategory(rawValue: draft.tag), !category.isDeprecated {
            tag = [category]
            isTagManuallyOverridden = true
        }

        if !draft.memo.isEmpty {
            memo = draft.memo
        }

        if !draft.placeName.isEmpty {
            place = PlaceSearchInfo(
                name: draft.placeName,
                address: "",
                coordinate: Coordinate(latitude: 0.0, longitude: 0.0)
            )
        }
    }

    /// AI 실행 후 당일 토큰 사용량을 SwiftData 에 기록합니다.
    ///
    /// SwiftData 컨텍스트가 없거나 저장에 실패해도 AI 결과에는 영향이 없습니다.
    @MainActor
    private func persistDailyTokenUsage(session: LanguageModelSession) async {
        guard let modelContext else { return }
        guard #available(iOS 26.4, *) else { return }

        let used: Int
        do {
            used = try await SystemLanguageModel.default.tokenCount(for: session.transcript)
        } catch {
            return
        }
        guard used > 0 else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let currentMemberId = AppStorageKey.legacyMemberIdInt()

        do {
            let descriptor = FetchDescriptor<AITokenDailyUsageRecord>()
            let records = try modelContext.fetch(descriptor)

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
        } catch {
            // 저장 실패해도 AI 실행 결과에 영향 없음
        }
    }
}
