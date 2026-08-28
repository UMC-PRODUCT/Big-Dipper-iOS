//
//  Profile+ActivityLogs.swift
//  CoreDomain
//
//  Created by euijjang97 on 8/28/26.
//
//  MyPageDomain `Profile+ProfileData` 에서 승격 (#1222).
//

import Foundation
import UMCFoundation

public extension Profile {
    /// 역할(`roles`)·챌린저 이력(`challengerRecords`)을 병합해 기수 내림차순 활동 이력을
    /// 구성합니다.
    ///
    /// 마이페이지 「활동 이력」 목록과 명함 「나의 활동・프로젝트」 카운트가 **같은 배열**을
    /// 본다. 예전에는 카운트 쪽이 `challengerRecords` 에서 따로 세는 바람에 운영진 이력이
    /// 목록에는 보이고 숫자에는 빠졌다 (#1222). 규칙이 갈리지 않도록 파생을 한 곳에 둔다.
    ///
    /// - Returns: 같은 기수의 운영진 역할은 한 줄로 병합한 활동 이력. 항목 수가 곧
    ///   「활동・프로젝트」 카운트다.
    func activityLogs() -> [ActivityLog] {
        let roleLogs = roles.map { role in
            ActivityLog(
                part: role.responsiblePart.flatMap { UMCPartType(apiValue: $0) } ?? .admin,
                generation: role.gisu.generationValue,
                role: role.roleType
            )
        }

        let challengerLogs = challengerRecords.compactMap { record -> ActivityLog? in
            guard let part = UMCPartType(apiValue: record.part), part != .admin else {
                return nil
            }

            return ActivityLog(
                part: part,
                generation: record.gisu.generationValue,
                role: .challenger
            )
        }

        let merged = mergeAdminLogs(roleLogs + challengerLogs)

        return merged.sorted { lhs, rhs in
            if lhs.generation == rhs.generation {
                return lhs.role > rhs.role
            }
            return lhs.generation > rhs.generation
        }
    }
}

private extension Profile {
    /// 같은 기수의 Admin 이력을 하나로 병합합니다.
    func mergeAdminLogs(_ logs: [ActivityLog]) -> [ActivityLog] {
        var adminByGen: [Int: [ManagementTeam]] = [:]
        var result: [ActivityLog] = []

        for log in logs {
            if log.part == .admin {
                adminByGen[log.generation, default: []].append(log.role)
            } else {
                result.append(log)
            }
        }

        for (gen, adminRoles) in adminByGen {
            let sortedRoles = adminRoles.sorted(by: >)
            result.append(ActivityLog(
                part: .admin,
                generation: gen,
                roles: sortedRoles
            ))
        }

        return result
    }
}

private extension String {
    /// 서버가 String으로 주는 기수를 정렬·병합 키로 쓸 Int로 읽는다 (절대 규칙 #2).
    var generationValue: Int { Int(self) ?? 0 }
}
