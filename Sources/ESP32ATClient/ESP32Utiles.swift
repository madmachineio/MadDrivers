typealias URCCallback = (String?) -> Void

public struct URCMessage {
    let prefix: String
    let suffix: String
    let callback: URCCallback?
}

public enum ATCommand {
    case test(command: String)
    case query(command: String)
    case setup(command: String, parameter: String)
    case execute(command: String)
}

public enum ESP32ATClientError: Error {
    case requestOverlength
    case responseTimeout
    case responseError
    case resetError
}

public struct ATResponse {
    var content: [String] = []
    var ok = false
}

public struct ATRequest {
    static let maxRequestByteCount = 256
    let content: ATCommand

    public init(_ atCommand: ATCommand) {
        content = atCommand
    }

    func parse() throws -> String {
        let requestString: String

        switch self.content {
            case let .test(command):
            requestString = ESP32ATClient.prefix + command + "=?" + ESP32ATClient.endMark
            case let .query(command):
            requestString = ESP32ATClient.prefix + command + "?" + ESP32ATClient.endMark
            case let .setup(command, parameter):
            requestString = ESP32ATClient.prefix + command + "=" + parameter + ESP32ATClient.endMark
            case let .execute(command):
            requestString = ESP32ATClient.prefix + command + ESP32ATClient.endMark
        }

        if requestString.utf8.count <= ATRequest.maxRequestByteCount {
            return requestString
        }

        throw ESP32ATClientError.requestOverlength
    }
}

extension String {
    mutating func removeCommand() {
        if let firstColon = self.firstIndex(of: ":") {
            self.removeSubrange(self.startIndex...firstColon)
        }
    }
}