// typealias URCCallback = (String) -> Void

// public struct URCMessage {
//     var prefix: String = ""
//     var suffix: String = ""
//     let callback: URCCallback
// }

// public enum ATCommand {
//     case test(command: String)
//     case query(command: String)
//     case setup(command: String, parameter: String)
//     case execute(command: String)
// }

// public enum ESP32ATClientError: Error {
//     case uartTransferFailed
//     case joinAPFailed

//     case timeout
//     case passwordError
//     case cannotFindAP
//     case connectFailed
//     case unknownError

//     case requestError
//     case requestOverlength
//     case responseTimeout
//     case responseError
//     case receivePromptFailed
//     case resetError
// }

// // public enum ESP32ATClientJoinWiFiError: Error {
// //     case timeout
// //     case passwordError
// //     case cannotFindAP
// //     case connectFailed
// //     case unknownError
// // }

// public struct ATResponse {
//     public var content: [String] = []
//     public var ok = false
// }

// public struct ATRequest {
//     static let maxRequestByteCount = 256
//     let content: ATCommand

//     public init(_ atCommand: ATCommand) {
//         content = atCommand
//     }

//     public func parse() throws(ESP32ATClientError) -> String {
//         let requestString: String

//         switch self.content {
//             case let .test(command):
//             requestString = ESP32ATClient.prefix + command + "=?" + ESP32ATClient.endMark
//             case let .query(command):
//             requestString = ESP32ATClient.prefix + command + "?" + ESP32ATClient.endMark
//             case let .setup(command, parameter):
//             requestString = ESP32ATClient.prefix + command + "=" + parameter + ESP32ATClient.endMark
//             case let .execute(command):
//             requestString = ESP32ATClient.prefix + command + ESP32ATClient.endMark
//         }

//         if requestString.utf8.count <= ATRequest.maxRequestByteCount {
//             return requestString
//         }

//         throw ESP32ATClientError.requestOverlength
//     }
// }

// extension String {
//     mutating func removeCommand() {
//         if let firstColon = self.firstIndex(of: ":") {
//             self.removeSubrange(self.startIndex...firstColon)
//         }
//     }


// }