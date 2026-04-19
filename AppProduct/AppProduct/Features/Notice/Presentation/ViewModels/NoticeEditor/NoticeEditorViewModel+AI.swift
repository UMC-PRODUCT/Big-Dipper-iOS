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

    struct AITokenUsage: Equatable {
        let lastRunTokens: Int
        let cumulativeUsed: Int
        let total: Int

        var remaining: Int { max(0, total - cumulativeUsed) }
        var progress: Double {
            guard total > 0 else { return 0 }
            return min(1, Double(cumulativeUsed) / Double(total))
        }
    }

    // MARK: - AI Content Improvement

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

    @MainActor
    func startAIImprovement() async {
        showAIConfirmation = false
        await improveContentWithAI()
    }

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

    @MainActor
    func dismissAICompletionSummary() {
        showAICompletionSummary = false
        aiStreamingText = ""
    }

    // MARK: - Token Usage

    private func resolveContextSize() -> Int? {
        #if compiler(>=6.3)
        guard #available(iOS 26.4, *) else { return nil }
        return SystemLanguageModel.default.contextSize
        #else
        return nil
        #endif
    }

    @MainActor
    private func updateTokenUsage(session: LanguageModelSession, contextSize: Int) async -> Int {
        #if compiler(>=6.3)
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
        #else
        return 0
        #endif
    }

    // MARK: - SwiftData Persistence

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
        } catch {}
    }

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
        } catch {}
    }
}
