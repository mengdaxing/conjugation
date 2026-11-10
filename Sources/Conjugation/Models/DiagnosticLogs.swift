import Foundation

enum DiagnosticLevel: String, Codable, CaseIterable {
    case warning, error
    var title: String { rawValue.uppercased() }
}

struct DiagnosticLogEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    let level: DiagnosticLevel
    let category: String
    let message: String
    var details = ""
    var source = "应用"
    var location = ""

    var fingerprint: String {
        "\(date.timeIntervalSince1970)|\(level.rawValue)|\(category)|\(source)|\(message)"
    }
    func matches(_ query: String) -> Bool {
        query.isEmpty || [message, details, category, source, location]
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }
    var text: String {
        let timestamp = ISO8601DateFormatter().string(from: date)
        var value = "[\(timestamp)] [\(level.title)] [\(category)] [\(source)] \(message)"
        if !location.isEmpty { value += "\n位置：\(location)" }
        if !details.isEmpty { value += "\n\(details)" }
        return value
    }
}

/// The facade keeps the shared model sources usable by the separate Android target.
enum AppDiagnostics {
    static func warning(_ message: String, category: String, error: Error? = nil,
                        file: String = #fileID, line: Int = #line) {
        #if os(iOS)
        DiagnosticLogStore.shared.record(.warning, category: category, message: message,
                                        error: error, location: "\(file):\(line)")
        #endif
    }
    static func error(_ message: String, category: String, error: Error? = nil,
                      file: String = #fileID, line: Int = #line) {
        #if os(iOS)
        DiagnosticLogStore.shared.record(.error, category: category, message: message,
                                        error: error, location: "\(file):\(line)")
        #endif
    }
}

#if os(iOS)
import OSLog
import UIKit

extension Notification.Name {
    static let diagnosticLogsChanged = Notification.Name("Conjugation.diagnosticLogsChanged")
}

/// Every mutation is serialized; persistence is bounded and atomically replaced.
final class DiagnosticLogStore: @unchecked Sendable {
    static let subsystem = "com.personal.frenchconjugation.diagnostics"
    static let shared = DiagnosticLogStore()
    private let queue = DispatchQueue(label: "Conjugation.diagnostic-storage")
    private let fileURL: URL
    private let limit: Int
    private let emitToConsole: Bool
    private var records: [DiagnosticLogEntry] = []
    private var storageFailure: String?
    private let console = Logger(subsystem: subsystem, category: "Application")

    init(fileURL: URL? = nil, limit: Int = 1_000, emitToConsole: Bool = true) {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = fileURL ?? root.appendingPathComponent("Diagnostics/logs.json")
        self.limit = max(1, limit)
        self.emitToConsole = emitToConsole
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        do {
            records = Array(try JSONDecoder().decode([DiagnosticLogEntry].self,
                                from: Data(contentsOf: self.fileURL)).sorted { $0.date < $1.date }.suffix(self.limit))
        } catch {
            // Preserve an unreadable file before replacing it with a usable log.
            let backup = self.fileURL.appendingPathExtension("corrupt")
            if !FileManager.default.fileExists(atPath: backup.path) {
                try? FileManager.default.copyItem(at: self.fileURL, to: backup)
            }
            records = [.init(level: .error, category: "日志存储", message: "读取历史日志失败",
                             details: Self.describe(error))]
            persistLocked()
        }
    }

    func snapshot() -> [DiagnosticLogEntry] { queue.sync { records } }
    var storageIssue: String? { queue.sync { storageFailure } }

    func record(_ level: DiagnosticLevel, category: String, message: String,
                error: Error? = nil, details: String = "", location: String = "") {
        let description = error.map(Self.describe) ?? details
        let entry = DiagnosticLogEntry(level: level, category: String(category.prefix(128)),
                                       message: String(message.prefix(2_000)),
                                       details: String(description.prefix(4_000)), location: location)
        append([entry])
        if emitToConsole {
            let text = "[\(entry.category)] \(entry.message) \(entry.details)"
            if level == .error { console.error("\(text, privacy: .public)") }
            else { console.warning("\(text, privacy: .public)") }
        }
    }

    func append(_ incoming: [DiagnosticLogEntry]) {
        guard !incoming.isEmpty else { return }
        let changed = queue.sync { () -> Bool in
            var known = Set(records.map(\.fingerprint))
            let additions = incoming.filter { known.insert($0.fingerprint).inserted }
            guard !additions.isEmpty else { return false }
            records = Array((records + additions).sorted { $0.date < $1.date }.suffix(limit))
            persistLocked()
            return true
        }
        if changed { notify() }
    }

    func clear() {
        queue.sync { records = []; persistLocked() }
        notify()
    }

    func report() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let header = """
        MyConju · 错误日志
        导出时间：\(ISO8601DateFormatter().string(from: Date()))
        应用版本：\(info["CFBundleShortVersionString"] as? String ?? "?") (build \(info["CFBundleVersion"] as? String ?? "?"))
        系统：\(ProcessInfo.processInfo.operatingSystemVersionString)
        时区：\(TimeZone.current.identifier)
        范围：应用 warning/error 与当前进程可读取的系统诊断；最多保留 \(limit) 条。
        """
        let entries = snapshot()
        return header + "\n日志数量：\(entries.count)\n\n" + entries.reversed().map(\.text).joined(separator: "\n\n")
    }

    func export(to directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("MyConju-Logs-\(UUID().uuidString).txt")
        try report().write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func persistLocked() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(records).write(to: fileURL, options: .atomic)
            storageFailure = nil
        } catch {
            let description = Self.describe(error)
            if storageFailure != description {
                records.append(.init(level: .error, category: "日志存储",
                                     message: "日志暂时无法写入磁盘，当前记录保留在内存中", details: description))
                records = Array(records.suffix(limit))
            }
            storageFailure = description
        }
    }
    private func notify() {
        DispatchQueue.main.async { NotificationCenter.default.post(name: .diagnosticLogsChanged, object: nil) }
    }
    private static func describe(_ error: Error) -> String {
        let error = error as NSError
        return "\(error.domain) (\(error.code)): \(error.localizedDescription)"
    }
}

/// OSLogStore exposes this process only on iOS. Never reads the whole device log.
final class RuntimeLogCollector {
    static let shared = RuntimeLogCollector()
    private let queue = DispatchQueue(label: "Conjugation.runtime-log-reader", qos: .utility)
    private var cursor = Date(timeIntervalSinceNow: -30)
    private var clearedAfter = Date.distantPast
    private var lastFailure: String?
    private var timer: Timer?
    private var memoryObserver: NSObjectProtocol?

    func resume() {
        if memoryObserver == nil {
            memoryObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
            ) { _ in AppDiagnostics.warning("系统发出内存不足警告", category: "内存") }
        }
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
    }
    func pause() { timer?.invalidate(); timer = nil; refresh() }

    func refresh(completion: @escaping () -> Void = {}) {
        queue.async {
            do {
                let readStarted = Date()
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                let position = store.position(date: self.cursor)
                var incoming: [DiagnosticLogEntry] = []
                var scanned = 0
                var latest = self.cursor
                var reachedLimit = false
                for case let entry as OSLogEntryLog in try store.getEntries(at: position) {
                    latest = max(latest, entry.date)
                    scanned += 1
                    if entry.date >= self.clearedAfter, entry.subsystem != DiagnosticLogStore.subsystem,
                       let level = Self.classify(level: entry.level, message: entry.composedMessage) {
                        incoming.append(.init(date: entry.date, level: level,
                            category: String((entry.category.isEmpty ? "系统运行时" : entry.category).prefix(128)),
                            message: String(entry.composedMessage.prefix(2_000)),
                            details: "subsystem: \(entry.subsystem)", source: "系统"))
                    }
                    if scanned >= 10_000 { reachedLimit = true; break }
                }
                DiagnosticLogStore.shared.append(incoming)
                // Overlap a little to accommodate delayed unified-log delivery;
                // fingerprints remove duplicates from subsequent refreshes.
                let through = reachedLimit ? latest : max(readStarted, latest)
                self.cursor = max(self.clearedAfter, through.addingTimeInterval(-5))
                self.lastFailure = nil
            } catch {
                let description = (error as NSError).description
                if self.lastFailure != description {
                    AppDiagnostics.warning("系统运行日志暂时不可读取，应用自身日志仍会保存",
                                           category: "日志采集", error: error)
                    self.lastFailure = description
                }
            }
            DispatchQueue.main.async { completion() }
        }
    }

    func clear(completion: @escaping () -> Void) {
        queue.async {
            self.clearedAfter = Date()
            self.cursor = self.clearedAfter
            DiagnosticLogStore.shared.clear()
            DispatchQueue.main.async { completion() }
        }
    }

    static func classify(level: OSLogEntryLog.Level, message: String) -> DiagnosticLevel? {
        switch level {
        case .error, .fault: return .error
        case .notice, .undefined:
            // Unified logging has no separate warning level. Do not incorrectly
            // label ordinary notice/info messages as warnings.
            return String(message.prefix(180)).range(of: #"^\s*(?:\[[^\]\n]{1,80}\]\s*)*(?:\[warn(?:ing)?\]|warn(?:ing)?\s*:)"#,
                options: [.regularExpression, .caseInsensitive]) == nil ? nil : .warning
        default: return nil
        }
    }
}
#endif
