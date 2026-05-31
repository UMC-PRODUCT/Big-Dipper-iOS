//
//  NoticeEditorViewModel+AI.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import FoundationModels
import SwiftData
import UIKit

extension NoticeEditorViewModel {

    // MARK: - Types

    /// AI 토큰 사용량 스냅샷
    struct AITokenUsage: Equatable {
        /// 직전 1회 실행에서 소비한 토큰 수
        let lastRunTokens: Int
        /// 에디터가 열린 뒤 누적 사용량 (직전 실행 포함)
        let cumulativeUsed: Int
        /// 모델 컨텍스트 윈도우 크기
        let total: Int

        var remaining: Int { max(0, total - cumulativeUsed) }
        var progress: Double {
            guard total > 0 else { return 0 }
            return min(1, Double(cumulativeUsed) / Double(total))
        }
    }

    /// AI 요약 결과로 생성된 제목 + 본문 초안.
    /// 사용자가 수락 전까지 에디터 필드에 반영되지 않습니다.
    struct AISummaryDraft {
        /// 요약에 사용된 원본 텍스트 (재시도 지원용)
        let sourceText: String
        /// 생성된 제목 후보
        let title: String
        /// 생성된 본문 (markdown)
        let body: String
    }

    // MARK: - AI Content Improvement

    /// AI 개선 요청 진입점. availability 체크 후 확인 다이얼로그를 띄운다.
    /// 실제 실행은 다이얼로그의 "작성하기" 버튼 탭 시 startAIImprovement()로 이어짐.
    @MainActor
    func requestAIImprovement() {
        let plainText = richAttributedContent.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plainText.isEmpty else { return }
        guard !isAIProcessing else { return }

        guard case .available = SystemLanguageModel.default.availability else {
            alertPrompt = AlertPrompt(
                title: "AI 기능 사용 불가",
                message: "이 기기에서는 Apple Intelligence를 사용할 수 없습니다. 설정에서 Apple Intelligence를 활성화해주세요.",
                positiveBtnTitle: "확인"
            )
            return
        }

        if let contextSize = resolveContextSize() {
            aiTokenUsage = AITokenUsage(
                lastRunTokens: 0,
                cumulativeUsed: min(aiCumulativeUsedTokens, contextSize),
                total: contextSize
            )
        }
        showAIConfirmation = true
    }

    /// 확인 다이얼로그에서 "작성하기" 버튼 탭 시 호출된다.
    @MainActor
    func startAIImprovement() async {
        showAIConfirmation = false
        await improveContentWithAI()
    }

    /// Foundation Model을 사용해 공지 본문을 개선합니다.
    ///
    /// 현재 본문 텍스트를 온디바이스 언어 모델로 개선하여 재작성합니다.
    /// 처리 중에는 `isAIProcessing`이 true가 되며, 스트리밍 진행 상황은 `aiStreamingText`에 반영됩니다.
    /// iOS 26.4 이상에서는 `aiTokenUsage`에 에디터 세션 누적 기준 토큰 사용량이 반영되며,
    /// 정상 완료 후에는 `showAICompletionSummary`가 true가 되어 사용자가 확인 버튼을 누를 때까지 오버레이가 유지됩니다.
    @MainActor
    func improveContentWithAI() async {
        let plainText = richAttributedContent.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plainText.isEmpty else { return }

        guard case .available = SystemLanguageModel.default.availability else {
            alertPrompt = AlertPrompt(
                title: "AI 기능 사용 불가",
                message: "이 기기에서는 Apple Intelligence를 사용할 수 없습니다. 설정에서 Apple Intelligence를 활성화해주세요.",
                positiveBtnTitle: "확인"
            )
            return
        }

        isAIProcessing = true
        aiStreamingText = ""
        showAICompletionSummary = false

        do {
            let session = LanguageModelSession {
                """
                당신은 동아리 공지사항 작성 전문가입니다.
                주어진 글의 핵심 내용과 의도는 그대로 유지하면서, 더 명확하고 자연스럽게 개선하여 다시 작성해주세요.
                별도의 설명이나 메타 텍스트 없이 개선된 글만 출력하세요.
                """
            }

            let contextSize = resolveContextSize()
            if let contextSize {
                aiTokenUsage = AITokenUsage(
                    lastRunTokens: 0,
                    cumulativeUsed: min(aiCumulativeUsedTokens, contextSize),
                    total: contextSize
                )
            }

            let stream = session.streamResponse(to: plainText)
            var fullText = ""
            var chunkIndex = 0
            var lastRunTokens = 0
            for try await partial in stream {
                fullText = partial.content
                aiStreamingText = fullText
                chunkIndex += 1
                if let contextSize, chunkIndex.isMultiple(of: 5) {
                    lastRunTokens = await updateTokenUsage(session: session, contextSize: contextSize)
                }
            }
            if let contextSize {
                lastRunTokens = await updateTokenUsage(session: session, contextSize: contextSize)
            }

            if !fullText.isEmpty {
                let baseFont = UIFont(name: "Pretendard-Regular", size: 16)
                    ?? UIFont.preferredFont(forTextStyle: .body)
                richAttributedContent = MarkdownSerializer.deserialize(fullText, baseFont: baseFont)
                content = MarkdownSerializer.serialize(richAttributedContent)
            }

            if let contextSize {
                aiCumulativeUsedTokens = min(aiCumulativeUsedTokens + lastRunTokens, contextSize)
                aiTokenUsage = AITokenUsage(
                    lastRunTokens: lastRunTokens,
                    cumulativeUsed: aiCumulativeUsedTokens,
                    total: contextSize
                )
            }

            persistDailyTokenUsage(lastRunTokens: lastRunTokens)

            isAIProcessing = false
            showAICompletionSummary = true
        } catch {
            isAIProcessing = false
            aiStreamingText = ""
            showAICompletionSummary = false
            errorHandler?.handle(
                error,
                context: ErrorContext(
                    feature: "Notice",
                    action: "improveContentWithAI"
                )
            )
        }
    }

    /// 완료 요약 오버레이를 닫습니다. 확인 버튼 핸들러에서 호출됩니다.
    @MainActor
    func dismissAICompletionSummary() {
        showAICompletionSummary = false
        aiStreamingText = ""
    }

    // MARK: - Token Usage

    /// 모델의 컨텍스트 윈도우 크기를 조회합니다. (iOS 26.4+)
    private func resolveContextSize() -> Int? {
        guard #available(iOS 26.4, *) else { return nil }
        return SystemLanguageModel.default.contextSize
    }

    /// 현재 세션 트랜스크립트 기준 이번 실행 토큰 사용량을 갱신하고, 누적값을 반영한 스냅샷을 `aiTokenUsage`에 세팅합니다.
    /// - Returns: 이번 실행에서 소비된 토큰 수 (실패 시 0)
    @MainActor
    private func updateTokenUsage(session: LanguageModelSession, contextSize: Int) async -> Int {
        guard #available(iOS 26.4, *) else { return 0 }
        do {
            let used = try await SystemLanguageModel.default.tokenCount(for: session.transcript)
            let cumulative = min(aiCumulativeUsedTokens + used, contextSize)
            aiTokenUsage = AITokenUsage(
                lastRunTokens: used,
                cumulativeUsed: cumulative,
                total: contextSize
            )
            return used
        } catch {
            return 0
        }
    }

    // MARK: - AI Summary (External Text → Title + Body Draft)

    /// 외부 텍스트 붙여넣기 시트를 엽니다. availability를 확인한 뒤 시트를 노출합니다.
    @MainActor
    func openAISummaryInput() {
        guard !isAISummaryProcessing else { return }

        guard case .available = SystemLanguageModel.default.availability else {
            alertPrompt = AlertPrompt(
                title: "AI 기능 사용 불가",
                message: "이 기기에서는 Apple Intelligence를 사용할 수 없습니다. 설정에서 Apple Intelligence를 활성화해주세요.",
                positiveBtnTitle: "확인"
            )
            return
        }

        summarySourceText = ""
        showAISummaryInput = true
    }

    /// 붙여넣기 시트를 취소/닫을 때 입력 버퍼를 초기화합니다.
    @MainActor
    func closeSummaryInput() {
        showAISummaryInput = false
        summarySourceText = ""
    }

    /// 붙여넣기 시트에서 "AI 요약" 버튼 탭 시 호출됩니다.
    /// sourceText가 비어 있으면 무시합니다.
    @MainActor
    func requestAISummary(from sourceText: String) {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isAISummaryProcessing else { return }

        guard case .available = SystemLanguageModel.default.availability else {
            alertPrompt = AlertPrompt(
                title: "AI 기능 사용 불가",
                message: "이 기기에서는 Apple Intelligence를 사용할 수 없습니다. 설정에서 Apple Intelligence를 활성화해주세요.",
                positiveBtnTitle: "확인"
            )
            return
        }

        if let contextSize = resolveContextSize() {
            aiTokenUsage = AITokenUsage(
                lastRunTokens: 0,
                cumulativeUsed: min(aiCumulativeUsedTokens, contextSize),
                total: contextSize
            )
        }

        showAISummaryInput = false
        showAISummaryConfirmation = true
        pendingSummaryDraft = AISummaryDraft(sourceText: trimmed, title: "", body: "")
    }

    /// 요약 확인 다이얼로그에서 "요약하기" 버튼 탭 시 호출됩니다.
    @MainActor
    func startAISummary() async {
        guard let draft = pendingSummaryDraft else { return }
        showAISummaryConfirmation = false
        await summarizeWithAI(sourceText: draft.sourceText)
    }

    /// Foundation Model을 사용해 외부 텍스트에서 공지 제목과 본문 초안을 생성합니다.
    ///
    /// 생성된 초안은 `pendingSummaryDraft`에 저장되며, `showAISummaryDraftReview`가 true가 됩니다.
    /// 사용자가 초안을 수락하기 전까지 title/content/richAttributedContent에 반영되지 않습니다.
    @MainActor
    func summarizeWithAI(sourceText: String) async {
        guard case .available = SystemLanguageModel.default.availability else { return }

        isAISummaryProcessing = true
        aiSummaryStreamingText = ""
        showAISummaryDraftReview = false

        do {
            let session = LanguageModelSession {
                """
                당신은 동아리 공지사항 작성 전문가입니다.
                주어진 외부 텍스트(디스코드 메시지, 이메일, 메모 등)를 분석해 동아리 공지사항 초안을 작성해주세요.
                반드시 아래 형식 그대로 출력하세요. 다른 설명이나 메타 텍스트는 절대 포함하지 마세요.

                TITLE: <한 줄 제목>
                BODY:
                <본문 (마크다운 허용)>
                """
            }

            let contextSize = resolveContextSize()
            if let contextSize {
                aiTokenUsage = AITokenUsage(
                    lastRunTokens: 0,
                    cumulativeUsed: min(aiCumulativeUsedTokens, contextSize),
                    total: contextSize
                )
            }

            let stream = session.streamResponse(to: sourceText)
            var fullText = ""
            var chunkIndex = 0
            var lastRunTokens = 0

            for try await partial in stream {
                fullText = partial.content
                aiSummaryStreamingText = fullText
                chunkIndex += 1
                if let contextSize, chunkIndex.isMultiple(of: 5) {
                    lastRunTokens = await updateTokenUsage(session: session, contextSize: contextSize)
                }
            }

            if let contextSize {
                lastRunTokens = await updateTokenUsage(session: session, contextSize: contextSize)
            }

            let parsed = parseSummaryOutput(fullText)
            pendingSummaryDraft = AISummaryDraft(
                sourceText: sourceText,
                title: parsed.title,
                body: parsed.body
            )

            if let contextSize {
                aiCumulativeUsedTokens = min(aiCumulativeUsedTokens + lastRunTokens, contextSize)
                aiTokenUsage = AITokenUsage(
                    lastRunTokens: lastRunTokens,
                    cumulativeUsed: aiCumulativeUsedTokens,
                    total: contextSize
                )
            }

            persistDailyTokenUsage(lastRunTokens: lastRunTokens)

            isAISummaryProcessing = false
            showAISummaryDraftReview = true
        } catch {
            isAISummaryProcessing = false
            aiSummaryStreamingText = ""
            showAISummaryDraftReview = false
            pendingSummaryDraft = nil
            errorHandler?.handle(
                error,
                context: ErrorContext(
                    feature: "Notice",
                    action: "summarizeWithAI"
                )
            )
        }
    }

    /// 초안을 수락하고 에디터 필드에 반영합니다.
    /// selectedCategory / subCategorySelection / allowAlert / targetInfo는 절대 자동 변경하지 않습니다.
    @MainActor
    func applySummaryDraft() {
        guard let draft = pendingSummaryDraft, !draft.body.isEmpty else {
            dismissAISummaryDraft()
            return
        }

        title = draft.title.isEmpty ? title : draft.title

        let baseFont = UIFont(name: "Pretendard-Regular", size: 16)
            ?? UIFont.preferredFont(forTextStyle: .body)
        richAttributedContent = MarkdownSerializer.deserialize(draft.body, baseFont: baseFont)
        content = MarkdownSerializer.serialize(richAttributedContent)

        dismissAISummaryDraft()
    }

    /// 초안을 기각하고 요약 흐름을 종료합니다.
    @MainActor
    func dismissAISummaryDraft() {
        showAISummaryDraftReview = false
        aiSummaryStreamingText = ""
        pendingSummaryDraft = nil
    }

    // MARK: - Summary Output Parsing

    /// 모델 출력에서 TITLE: / BODY: 섹션을 파싱합니다.
    private func parseSummaryOutput(_ raw: String) -> (title: String, body: String) {
        var title = ""
        var body = ""

        let lines = raw.components(separatedBy: "\n")
        var isInBody = false
        var bodyLines: [String] = []

        for line in lines {
            if !isInBody, line.hasPrefix("TITLE:") {
                title = line.dropFirst("TITLE:".count).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("BODY:") {
                isInBody = true
            } else if isInBody {
                bodyLines.append(line)
            }
        }

        body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        if body.isEmpty {
            body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (title, body)
    }

    // MARK: - SwiftData Persistence

    /// 에디터 진입 시 당일 토큰 사용량을 복원합니다.
    ///
    /// 당일 레코드가 존재하면 `aiCumulativeUsedTokens`를 복원하고, 없으면 0을 유지합니다.
    @MainActor
    func restoreDailyTokenUsage() {
        guard let modelContext else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let currentMemberId = memberId

        do {
            let descriptor = FetchDescriptor<AITokenDailyUsageRecord>()
            let records = try modelContext.fetch(descriptor)
            if let record = records.first(where: { $0.memberId == currentMemberId && $0.date == today }) {
                aiCumulativeUsedTokens = record.usedTokens
            }
        } catch {
            // 복원 실패해도 에디터 동작에 영향 없이 0으로 유지
        }
    }

    /// AI 개선 성공 완료 시 당일 누적 토큰 사용량을 SwiftData에 저장합니다.
    ///
    /// 저장 실패 시 AI 결과(본문 교체)에는 영향을 주지 않습니다.
    @MainActor
    private func persistDailyTokenUsage(lastRunTokens: Int) {
        guard let modelContext, lastRunTokens > 0 else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let currentMemberId = memberId

        do {
            let descriptor = FetchDescriptor<AITokenDailyUsageRecord>()
            let records = try modelContext.fetch(descriptor)

            if let record = records.first(where: { $0.memberId == currentMemberId && $0.date == today }) {
                record.usedTokens += lastRunTokens
            } else {
                modelContext.insert(AITokenDailyUsageRecord(
                    memberId: currentMemberId,
                    date: today,
                    usedTokens: lastRunTokens
                ))
            }

            try modelContext.save()
        } catch {
            // 저장 실패해도 AI 실행 결과에 영향 없음
        }
    }
}
