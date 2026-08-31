# Response DTO Decoding

> 서버가 모든 정수를 String으로 직렬화하는 문제에 대한 디코딩 규칙 상세 레퍼런스.
> 핵심 요약은 `CLAUDE.md` 참고.

서버는 **응답으로 내려주는 모든 정수 값을 String 으로 직렬화**합니다.
JSON Number 가 아닌 String 으로 오므로, Response DTO 가 `Int` 로
선언된 필드를 그대로 디코딩하면 런타임 `DecodingError.typeMismatch`
가 발생합니다.

- 작성자: 제옹(euijjang97)

## 원칙

1. **Response DTO 의 모든 `Int` 필드는 String 폴백을 보장한다**
2. **synthesized `Codable` 금지** — `Int` 필드가 있으면 반드시 custom
   `init(from:)` + `encode(to:)` 를 작성
3. **`decode(Int.self)` / `decodeIfPresent(Int.self)` 직접 호출 금지** —
   `decodeIntFlexibleIfPresent` 헬퍼 사용
4. **폴백 순서**: `Int` → `String("123")` → `Double(123.0)` → throw
5. **Request DTO (Encodable, 우리가 보내는 쪽) 는 제외** — `Int` 그대로 OK

## ❌ 안티패턴

```swift
struct UserDTO: Codable {
    let userId: Int           // synthesized Codable — "123" String 응답에서 typeMismatch
    let name: String
}

// 또는 custom init 안에서 직접 Int decode
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    userId = try container.decodeIfPresent(Int.self, forKey: .userId) ?? 0
}
```

## ✅ 권장 패턴

```swift
struct UserDTO: Codable {
    let userId: Int
    let name: String

    private enum CodingKeys: String, CodingKey {
        case userId, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeIntFlexibleIfPresent(forKey: .userId) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
    }
}

private extension KeyedDecodingContainer {
    func decodeIntFlexible(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key),
           let intValue = Int(value) { return intValue }
        if let value = try? decode(Double.self, forKey: key) { return Int(value) }
        throw DecodingError.typeMismatch(
            Int.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Int/String-number/Double for key '\(key.stringValue)'"
            )
        )
    }

    func decodeIntFlexibleIfPresent(forKey key: Key) throws -> Int? {
        if (try? decodeNil(forKey: key)) == true { return nil }
        return try? decodeIntFlexible(forKey: key)
    }
}
```

## 리뷰 체크리스트

Response DTO 변경이 포함된 PR 리뷰 시 검증:

- [ ] `Int` / `Int?` / `[Int]` / `Int64` 등 정수 타입 필드가 있는가
- [ ] 정수 필드가 있다면 custom `init(from:)` 이 정의되어 있는가 (synthesized Codable 금지)
- [ ] `init(from:)` 안에서 `decodeIntFlexibleIfPresent` (또는 동급) 사용 — `decode(Int.self)` 직접 호출 없음
- [ ] 헬퍼가 파일 내 `private extension KeyedDecodingContainer` 로 정의되어 있는가
- [ ] **Request/Encodable DTO 는 적용 제외 확인** — 보내는 쪽이라 무관

## 적용 범위

- **신규 Response DTO**: 처음부터 위 패턴 적용
- **기존 Response DTO**: 별도 마이그레이션 PR 로 진행
- **공용 헬퍼 통합**: 현재 파일별 중복 정의 — 추후 `Core/Common/Decoding/` 위치로 단일화 예정
