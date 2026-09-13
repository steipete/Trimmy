import OSLog

enum Telemetry {
    static let accessibility = Logger(subsystem: "com.steipete.trimmy", category: "accessibility")
    static let clipboard = Logger(subsystem: "com.steipete.trimmy", category: "clipboard")
    static let eventTap = Logger(subsystem: "com.steipete.trimmy", category: "eventtap")
}
