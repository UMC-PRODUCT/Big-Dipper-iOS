//
//  ChallengerGenRepository.swift
//  HomeData
//
//  Created by euijjang97 on 2/12/26.
//

import CoreDomain
import Foundation
import SwiftData

/// SwiftData 기반 기수-기수ID 매핑 로컬 저장소 구현체
///
/// `ModelContext`를 주입받아 (gen, gisuId) 매핑을 upsert/조회합니다.
/// CloudKit Sync 활성화 시 `@Attribute(.unique)` 사용 불가하므로,
/// `gen` 기준 fetch 후 upsert 방식으로 처리합니다.
public final class ChallengerGenRepository: ChallengerGenRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let modelContext: ModelContext

    // MARK: - Init

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Function

    /// 전체 매핑을 교체 저장합니다 (upsert + 미사용 레코드 삭제).
    ///
    /// - Note: CloudKit Sync에서 `@Attribute(.unique)` 사용 불가하므로
    ///   gen 기준 fetch 후 수동 upsert 방식으로 처리합니다.
    ///   이미 같은 gen 레코드가 여러 개 존재하면 최신 레코드만 남기고 정리합니다.
    /// - Note: 정수로 파싱되지 않는 gen/gisuId 쌍은 정렬·매칭 기준을 세울 수 없어 저장에서 제외한다
    ///   (저장하지 않으므로 기존 레코드도 그 gen 기준으로는 유지되지 않고 pruning 대상이 된다).
    public func replaceMappings(_ pairs: [(gen: String, gisuId: String)]) throws {
        let existingDescriptor = FetchDescriptor<GenerationMappingRecord>()
        let existing = try modelContext.fetch(existingDescriptor)
        let incomingPairs = pairs.reduce(into: [Int: Int]()) { partialResult, pair in
            guard let gen = Int(pair.gen), let gisuId = Int(pair.gisuId) else { return }
            partialResult[gen] = gisuId
        }
        let incomingGens = Set(incomingPairs.keys)
        let dedupedExisting = deduplicateExistingRecords(existing)
        let existingByGen = dedupedExisting.recordsByGen

        for (gen, gisuId) in incomingPairs {
            if let record = existingByGen[gen] {
                record.gisuId = gisuId
                record.updatedAt = .now
            } else {
                let record = GenerationMappingRecord(
                    gisuId: gisuId,
                    gen: gen
                )
                modelContext.insert(record)
            }
        }

        for record in dedupedExisting.duplicates {
            modelContext.delete(record)
        }

        for record in existingByGen.values where !incomingGens.contains(record.gen) {
            modelContext.delete(record)
        }

        try modelContext.save()
    }

    /// 전체 기수의 (gen, gisuId) 매핑을 gen 오름차순으로 조회합니다.
    ///
    /// - Note: CloudKit Sync로 인한 중복 레코드를 `seenGens` 집합으로 필터링합니다.
    public func fetchGenGisuIdPairs() throws -> [(gen: String, gisuId: String)] {
        let descriptor = FetchDescriptor<GenerationMappingRecord>(
            sortBy: [SortDescriptor(\.gen, order: .forward)]
        )
        let records = try modelContext.fetch(descriptor)
        var seenGens = Set<Int>()

        return records.compactMap {
            guard seenGens.insert($0.gen).inserted else {
                return nil
            }
            return (gen: String($0.gen), gisuId: String($0.gisuId))
        }
    }

    // MARK: - Private Function

    private func deduplicateExistingRecords(
        _ records: [GenerationMappingRecord]
    ) -> (
        recordsByGen: [Int: GenerationMappingRecord],
        duplicates: [GenerationMappingRecord]
    ) {
        var recordsByGen: [Int: GenerationMappingRecord] = [:]
        var duplicates: [GenerationMappingRecord] = []

        for record in records.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            if recordsByGen[record.gen] == nil {
                recordsByGen[record.gen] = record
            } else {
                duplicates.append(record)
            }
        }

        return (recordsByGen, duplicates)
    }
}
