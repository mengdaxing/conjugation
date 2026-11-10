import XCTest
import OSLog
@testable import Conjugation

final class DiagnosticLogTests: XCTestCase {
    private var directory: URL!
    private var file: URL { directory.appendingPathComponent("logs.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testRetentionDeduplicationAndUnicodeSurviveRestart() {
        let store = DiagnosticLogStore(fileURL: file, limit: 3, emitToConsole: false)
        let entries = (0..<5).map { index in
            DiagnosticLogEntry(date: Date(timeIntervalSince1970: Double(index)), level: .warning,
                               category: "法语朗读", message: "échec \(index)", details: "中文详情")
        }
        store.append(Array(entries.reversed()))
        store.append([entries[4]])
        XCTAssertEqual(store.snapshot().map(\.message), ["échec 2", "échec 3", "échec 4"])
        XCTAssertEqual(DiagnosticLogStore(fileURL: file, emitToConsole: false).snapshot(), store.snapshot())
        XCTAssertTrue(store.snapshot()[0].matches("中文"))
        XCTAssertTrue(store.snapshot()[0].matches("ÉCHEC"))
    }

    func testConcurrentErrorsAreAllPersisted() {
        let store = DiagnosticLogStore(fileURL: file, emitToConsole: false)
        DispatchQueue.concurrentPerform(iterations: 40) { index in
            store.record(.error, category: "Concurrency", message: "failure \(index)")
        }
        XCTAssertEqual(Set(store.snapshot().map(\.message)).count, 40)
        XCTAssertEqual(DiagnosticLogStore(fileURL: file, emitToConsole: false).snapshot().count, 40)
        XCTAssertNil(store.storageIssue)
    }

    func testExportContainsContextAndClearPersists() throws {
        let store = DiagnosticLogStore(fileURL: file, emitToConsole: false)
        store.record(.warning, category: "语音", message: "没有法语语音", location: "Speaker.swift:42")
        store.record(.error, category: "文件", message: "读取失败",
                     error: NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "测试错误"]))
        let url = try store.export(to: directory.appendingPathComponent("export"))
        let report = try String(contentsOf: url, encoding: .utf8)
        for value in ["WARNING", "ERROR", "没有法语语音", "Speaker.swift:42", "TestDomain (42)", "测试错误", "应用版本：", "日志数量：2"] {
            XCTAssertTrue(report.contains(value), value)
        }
        store.clear()
        XCTAssertTrue(DiagnosticLogStore(fileURL: file, emitToConsole: false).snapshot().isEmpty)
    }

    func testCorruptHistoryIsPreservedAndReportsAnError() throws {
        let corrupt = Data("broken-json".utf8)
        try corrupt.write(to: file)
        let store = DiagnosticLogStore(fileURL: file, emitToConsole: false)
        XCTAssertEqual(store.snapshot().first?.level, .error)
        XCTAssertEqual(store.snapshot().first?.category, "日志存储")
        XCTAssertEqual(try Data(contentsOf: file.appendingPathExtension("corrupt")), corrupt)
        store.record(.warning, category: "恢复", message: "可以继续记录")
        XCTAssertEqual(DiagnosticLogStore(fileURL: file, emitToConsole: false).snapshot().count, 2)
    }

    func testWriteFailureKeepsUsefulLogsWithoutRecursion() throws {
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data("file".utf8).write(to: blocker)
        let store = DiagnosticLogStore(fileURL: blocker.appendingPathComponent("logs.json"), emitToConsole: false)
        store.record(.warning, category: "测试", message: "first")
        store.record(.error, category: "测试", message: "second")
        XCTAssertNotNil(store.storageIssue)
        XCTAssertEqual(store.snapshot().filter { $0.category == "日志存储" }.count, 1)
        XCTAssertTrue(store.snapshot().contains { $0.message == "first" })
        XCTAssertTrue(store.snapshot().contains { $0.message == "second" })
    }

    func testRuntimeSeverityDoesNotPromoteOrdinaryMessages() {
        XCTAssertEqual(RuntimeLogCollector.classify(level: .error, message: "failure"), .error)
        XCTAssertEqual(RuntimeLogCollector.classify(level: .fault, message: "fault"), .error)
        XCTAssertEqual(RuntimeLogCollector.classify(level: .notice, message: "Warning: low memory"), .warning)
        XCTAssertEqual(RuntimeLogCollector.classify(level: .undefined, message: "[WARN] unavailable"), .warning)
        XCTAssertNil(RuntimeLogCollector.classify(level: .notice, message: "normal operation"))
        XCTAssertNil(RuntimeLogCollector.classify(level: .notice, message: "unwarned"))
        XCTAssertNil(RuntimeLogCollector.classify(level: .notice, message: "Checking 'Warning' for accessibility"))
        XCTAssertNil(RuntimeLogCollector.classify(level: .notice, message: "Added observer for expiration warning"))
        XCTAssertEqual(RuntimeLogCollector.classify(level: .notice, message: "[SwiftUI] Warning: invalid layout"), .warning)
        XCTAssertNil(RuntimeLogCollector.classify(level: .info, message: "Warning in informational text"))
        XCTAssertNil(RuntimeLogCollector.classify(level: .debug, message: "debug"))
    }

    @MainActor
    func testLearningStateDecodeFailureCreatesRealDiagnostic() {
        let suite = "DiagnosticState.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid".utf8), forKey: "conjugation.state.v1")
        let previous = Set(DiagnosticLogStore.shared.snapshot().map(\.id))
        let store = AppStore(defaults: defaults)
        XCTAssertEqual(store.settings.dailyGoal, 5)
        XCTAssertTrue(DiagnosticLogStore.shared.snapshot().contains {
            !previous.contains($0.id) && $0.category == "学习记录" && $0.level == .error && !$0.details.isEmpty
        })
    }
}
