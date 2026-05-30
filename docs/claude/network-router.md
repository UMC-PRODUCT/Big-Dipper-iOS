# Network Router (Moya)

> API Router 설계 규칙(DTO 캡슐화)에 대한 상세 레퍼런스.
> 핵심 요약은 `CLAUDE.md` 참고.

API Router는 **엔드포인트 메타데이터(Path / Method / Encoding)만** 책임집니다.
**파라미터 키 이름과 직렬화 규칙은 Request/Query DTO가 캡슐화**합니다.
`AppProduct/Features/*/Data/Router/` 와 `UMCApp/Features/*/Data/Router/` 양쪽 동일하게 적용합니다.

## 원칙

1. **Router의 `task` 안에 인라인 딕셔너리 금지**
   `["key": value, ...]` 형태로 파라미터 키와 값을 Router 안에 직접 작성하지 않습니다. key 문자열이 Router에 흩어지면 스펙 변경 시 모든 case를 뒤져야 합니다.
2. **Body → `Encodable` DTO + `.requestJSONEncodable(body)`**
3. **Query → DTO + `toParameters` + `.requestParameters(..., encoding: URLEncoding.queryString)`**
   Query DTO는 직렬화 책임을 `var toParameters: [String: Any]` computed property로 캡슐화합니다. 네이밍은 `toParameters`로 통일합니다 (`queryItems`는 표준 `[URLQueryItem]`을 연상시켜 오해 소지).
4. **Path 변수(`{id}`)는 case associated value로 받아 `path`에서만 사용** — 쿼리/바디와 섞지 않습니다.
5. **단일 path 변수만 받는 case (예: `case getDetail(id: Int)`)는 DTO 불필요** — 파라미터 컬렉션이 생기는 순간 DTO 분리.

## ❌ 안티패턴

```swift
// Router가 파라미터 키 이름까지 알고 있음
case .getNoticeReadStatusList(_, let cursorId, let filterType, let organizationIds, let status):
    return .requestParameters(
        parameters: [
            "cursorId": cursorId,
            "filterType": filterType,
            "organizationIds": organizationIds,
            "status": status
        ],
        encoding: URLEncoding.queryString
    )

case .addLink(_, let links):
    return .requestParameters(
        parameters: ["links": links],
        encoding: JSONEncoding.default
    )
```

## ✅ 권장 패턴

```swift
// 1. Query/Body DTO 정의
struct NoticeReadStatusListQuery: Encodable {
    let cursorId: Int
    let filterType: String
    let organizationIds: [Int]
    let status: String

    var toParameters: [String: Any] {
        [
            "cursorId": cursorId,
            "filterType": filterType,
            "organizationIds": organizationIds,
            "status": status
        ]
    }
}

struct AddLinkRequestDTO: Encodable {
    let links: [String]
}

// 2. Router는 DTO만 받아 위임
case .getNoticeReadStatusList(_, let query):
    return .requestParameters(parameters: query.toParameters, encoding: URLEncoding.queryString)

case .addLink(_, let body):
    return .requestJSONEncodable(body)
```

## DTO 파일 위치

- Body: `Features/{Feature}/Data/DTO/Request/{Name}RequestDTO.swift`
- Query: `Features/{Feature}/Data/DTO/Request/{Name}Query.swift`

## 적용 범위

- **신규 라우터/엔드포인트**: 처음부터 DTO 분리.
- **기존 라우터**: 별도 마이그레이션 작업으로 진행 (기능 작업과 분리해 PR을 따로 연다).
