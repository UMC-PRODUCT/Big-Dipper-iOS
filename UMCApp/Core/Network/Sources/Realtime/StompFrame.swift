//
//  StompFrame.swift
//  CoreNetwork
//

import Foundation

/// STOMP 1.2 프레임 커맨드.
public enum StompCommand: String, Sendable {
    case connect = "CONNECT"
    case connected = "CONNECTED"
    case subscribe = "SUBSCRIBE"
    case unsubscribe = "UNSUBSCRIBE"
    case send = "SEND"
    case message = "MESSAGE"
    case receipt = "RECEIPT"
    case error = "ERROR"
    case disconnect = "DISCONNECT"
}

public enum StompFrameError: Error, Equatable {
    case malformed
    case unknownCommand(String)
}

/// STOMP 1.2 프레임의 값 표현.
///
/// 이 타입은 바이트 ↔ 값 변환만 담당한다. destination 문자열이나 이벤트 의미 같은
/// 도메인 지식은 상위(`CommunityData`)가 갖는다.
public struct StompFrame: Equatable, Sendable {

    // MARK: - Property

    public let command: StompCommand
    public let headers: [String: String]
    public let body: Data

    // MARK: - Init

    public init(command: StompCommand, headers: [String: String] = [:], body: Data = Data()) {
        self.command = command
        self.headers = headers
        self.body = body
    }

    // MARK: - Computed Property

    public var bodyString: String? {
        String(data: body, encoding: .utf8)
    }

    // MARK: - Function

    /// `COMMAND\n헤더...\n\n<body>\0` 형태로 직렬화한다.
    public func encoded() -> Data {
        // 헤더 순서가 흔들리면 테스트와 서버 로그를 대조하기 어렵다. 키 정렬로 고정한다.
        let headerLines = headers
            .sorted { $0.key < $1.key }
            .map { "\(Self.escape($0.key)):\(Self.escape($0.value))" }
            .joined(separator: "\n")

        var text = command.rawValue + "\n"
        if !headerLines.isEmpty {
            text += headerLines + "\n"
        }
        text += "\n"

        var data = Data(text.utf8)
        data.append(body)
        data.append(0x00)
        return data
    }

    /// 수신 바이트를 프레임으로 복원한다. heartbeat(EOL 단독)이면 `nil`.
    public static func decode(_ data: Data) throws -> StompFrame? {
        // 종료 NULL 과 뒤따르는 heartbeat EOL 을 걷어낸다.
        var payload = data
        while let last = payload.last, last == 0x00 || last == 0x0A || last == 0x0D {
            payload.removeLast()
        }
        guard !payload.isEmpty else { return nil }

        guard let text = String(data: payload, encoding: .utf8) else {
            throw StompFrameError.malformed
        }

        // 헤더 블록과 본문은 빈 줄로 나뉜다. 본문 자체에 빈 줄이 있을 수 있으므로 첫 경계만 자른다.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let parts = normalized.components(separatedBy: "\n\n")
        guard let head = parts.first else { throw StompFrameError.malformed }

        let bodyText = parts.dropFirst().joined(separator: "\n\n")

        var lines = head.components(separatedBy: "\n")
        guard let commandLine = lines.first, !commandLine.isEmpty else {
            throw StompFrameError.malformed
        }
        guard let command = StompCommand(rawValue: commandLine) else {
            throw StompFrameError.unknownCommand(commandLine)
        }
        lines.removeFirst()

        var headers: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = unescape(String(line[line.startIndex..<separator]))
            let value = unescape(String(line[line.index(after: separator)...]))
            // STOMP 1.2: 같은 키가 반복되면 첫 값이 유효하다.
            if headers[key] == nil { headers[key] = value }
        }

        return StompFrame(command: command, headers: headers, body: Data(bodyText.utf8))
    }

    // MARK: - Header Escaping

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ":", with: "\\c")
    }

    private static func unescape(_ value: String) -> String {
        var result = ""
        var iterator = value.makeIterator()
        while let character = iterator.next() {
            guard character == "\\", let escaped = iterator.next() else {
                result.append(character)
                continue
            }
            switch escaped {
            case "r": result.append("\r")
            case "n": result.append("\n")
            case "c": result.append(":")
            case "\\": result.append("\\")
            default: result.append(escaped)
            }
        }
        return result
    }
}
