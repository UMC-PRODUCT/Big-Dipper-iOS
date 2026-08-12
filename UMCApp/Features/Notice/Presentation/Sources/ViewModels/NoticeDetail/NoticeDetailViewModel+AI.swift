//
//  NoticeDetailViewModel+AI.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/14/26.
//

import Foundation
import FoundationModels
import SwiftData
import UMCFoundation
import NoticeDomain

extension NoticeDetailViewModel {

    // MARK: - Types

    /// AI 읽기 요약 진행 단계
    enum ReadingSummaryPhase: Equatable {
        case idle
        case streaming
        case completed
        case failed(String)
    }

    // MARK: - AI Reading Summary

    /// 온디바이스 AI 요약 기능이 이 기기에서 사용 가능한지 여부
    var isAIReadingSummaryAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// 공지 본문을 온디바이스 AI로 요약합니다. availability 체크 후 스트리밍을 시작합니다.
    @MainActor
    func requestReadingSummary(content: String, modelContext: ModelContext?) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard readingSummaryPhase != .streaming else { return }

        guard case .available = SystemLanguageModel.default.availability else {
            readingSummaryPhase = .failed("이 기기에서는 Apple Intelligence를 사용할 수 없습니다.")
            return
        }

        readingSummaryStreamingText = ""
        readingSummaryPhase = .streaming
        readingSummaryModelContext = modelContext

        Task { @MainActor in
            await performReadingSummary(content: trimmed)
        }
    }

    /// Foundation Model을 사용해 공지 본문을 스트리밍 요약합니다.
    @MainActor
    private func performReadingSummary(content: String) async {
        guard case .available = SystemLanguageModel.default.availability else {
            readingSummaryPhase = .failed("Apple Intelligence를 사용할 수 없습니다.")
            return
        }

        do {
            let session = LanguageModelSession {
                """
                당신은 동아리 공지사항 읽기 보조 도구입니다.
                주어진 공지 본문을 읽는 사람이 핵심 내용을 빠르게 파악할 수 있도록,
                불필요한 서술 없이 핵심 사항만 간결하게 요약해 주세요.
                별도의 설명이나 메타 텍스트 없이 요약된 내용만 출력하세요.
                """
            }

            let contextSize = resolveContextSize()

            let stream = session.streamResponse(to: content)
            var fullText = ""
            var chunkIndex = 0
            var lastRunTokens = 0

            for try await partial in stream {
                fullText = partial.content
                readingSummaryStreamingText = fullText
                chunkIndex += 1
                if let contextSize, chunkIndex.isMultiple(of: 5) {
                    lastRunTokens = await updateTokenUsage(session: session, contextSize: contextSize)
                }
            }

            if let contextSize {
                lastRunTokens = await updateTokenUsage(session: session, contextSize: contextSize)
            }

            persistDailyTokenUsage(lastRunTokens: lastRunTokens)
            readingSummaryPhase = .completed
        } catch {
            readingSummaryStreamingText = ""
            readingSummaryPhase = .failed("요약 중 오류가 발생했습니다.")
        }
    }

    /// 요약 시트가 닫힐 때 호출. 상태를 초기화합니다.
    @MainActor
    func dismissReadingSummary() {
        readingSummaryPhase = .idle
        readingSummaryStreamingText = ""
    }

    // MARK: - Token Usage

    private func resolveContextSize() -> Int? {
        guard #available(iOS 26.4, *) else { return nil }
        return SystemLanguageModel.default.contextSize
    }

    @MainActor
    private func updateTokenUsage(session: LanguageModelSession, contextSize: Int) async -> Int {
        guard #available(iOS 26.4, *) else { return 0 }
        do {
            let used = try await SystemLanguageModel.default.tokenCount(for: session.transcript)
            return used
        } catch {
            return 0
        }
    }

    @MainActor
    private func persistDailyTokenUsage(lastRunTokens: Int) {
        guard let modelContext = readingSummaryModelContext, lastRunTokens > 0 else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let currentMemberId = String(AppStorageKey.legacyMemberIdInt())

        do {
            let descriptor = FetchDescriptor<AITokenDailyUsageRecord>()
            let records = try modelContext.fetch(descriptor)

            if let record = records.first(where: { $0.memberKey == currentMemberId && $0.date == today }) {
                record.usedTokens += lastRunTokens
            } else {
                modelContext.insert(AITokenDailyUsageRecord(
                    memberKey: currentMemberId,
                    date: today,
                    usedTokens: lastRunTokens
                ))
            }

            try modelContext.save()
        } catch {
            // 저장 실패해도 요약 결과에 영향 없음
        }
    }
}
