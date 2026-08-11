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
/// 도메인 지식은 상위 레이어가 갖는다.
///
/// `Sendable` 은 수신 루프(actor) 경계를 넘겨 전달하기 위한 것이다.
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
        let transform = Self.escapesHeaders(command) ? Self.escape : { $0 }

        // 헤더 순서가 흔들리면 테스트와 서버 로그를 대조하기 어렵다. 키 정렬로 고정한다.
        let headerLines = headers
            .sorted { $0.key < $1.key }
            .map { "\(transform($0.key)):\(transform($0.value))" }
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
    ///
    /// 프레임 경계는 NULL 종료자가 정의한다. 종료자가 없으면 잘린 버퍼로 보고 `.malformed`.
    public static func decode(_ data: Data) throws -> StompFrame? {
        // heartbeat 는 버퍼 전체가 EOL 인 경우다. 우측 트림으로 판정하면 본문 끝 개행을 먹는다.
        guard data.contains(where: { $0 != 0x0A && $0 != 0x0D }) else { return nil }

        // 종료자 뒤에 서버가 덧붙인 EOL 만 걷어낸 뒤, NULL 종료자를 명시적으로 소비한다.
        var payload = data
        while let last = payload.last, last == 0x0A || last == 0x0D {
            payload.removeLast()
        }
        guard payload.last == 0x00 else { throw StompFrameError.malformed }
        payload.removeLast()

        guard let text = String(data: payload, encoding: .utf8) else {
            throw StompFrameError.malformed
        }

        // 헤더 블록과 본문은 빈 줄로 나뉜다. 본문 자체에 빈 줄이 있을 수 있으므로 첫 경계만 자른다.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let parts = normalized.components(separatedBy: "\n\n")
        // components(separatedBy:) 는 항상 1개 이상을 반환하므로 이 분기는 도달하지 않는다.
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

        let restore = escapesHeaders(command) ? unescape : { $0 }

        var headers: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = restore(String(line[line.startIndex..<separator]))
            let value = restore(String(line[line.index(after: separator)...]))
            // STOMP 1.2: 같은 키가 반복되면 첫 값이 유효하다.
            if headers[key] == nil { headers[key] = value }
        }

        return StompFrame(command: command, headers: headers, body: Data(bodyText.utf8))
    }

    // MARK: - Header Escaping

    /// STOMP 1.2 는 1.0 호환을 위해 CONNECT/CONNECTED 헤더의 이스케이프를 면제한다.
    private static func escapesHeaders(_ command: StompCommand) -> Bool {
        command != .connect && command != .connected
    }

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
