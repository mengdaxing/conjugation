import XCTest

final class ConjugationUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-state-for-testing", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSpeechSwitchingBetweenReferenceAndPractice() {
        app.buttons["level.basic"].tap()
        let aimer = app.buttons["verb.aimer"]
        if !aimer.isHittable { app.swipeUp() }
        aimer.tap()
        XCTAssertTrue(app.buttons["法语发音"].waitForExistence(timeout: 5))
        app.buttons["法语发音"].tap()
        app.buttons["朗读 je"].tap()
        app.buttons["朗读 nous"].tap()
        app.buttons["朗读 nous"].tap()
        XCTAssertFalse(app.alerts["无法播放语音"].exists)
        let practice = app.buttons["practiceVerb"]
        if !practice.isHittable { app.swipeUp() }
        practice.tap()
        XCTAssertTrue(app.buttons["checkAnswers"].waitForExistence(timeout: 5))
        app.buttons["checkAnswers"].tap()
        XCTAssertTrue(app.buttons["朗读答案"].waitForExistence(timeout: 5))
        app.buttons["朗读答案"].tap()
        app.buttons["朗读答案"].tap()
        app.buttons["nextQuestion"].tap()
        XCTAssertTrue(app.staticTexts["本轮练习完成"].waitForExistence(timeout: 5))
        app.buttons["finishSession"].tap()
        XCTAssertTrue(app.buttons["法语发音"].waitForExistence(timeout: 5))
        app.buttons["法语发音"].tap()
        XCTAssertFalse(app.alerts["无法播放语音"].exists)
        capture("19-speech-reference-replay")
    }

    func testPracticeAndCorrectionFlow() {
        XCTAssertTrue(app.buttons["level.basic"].waitForExistence(timeout: 8))
        capture("01-home")
        app.buttons["level.basic"].tap()
        let start = app.buttons["startPractice"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        capture("02-verb-list")
        start.tap()
        let first = app.textFields["answer.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(app.buttons["checkAnswers"].isHittable, "Submit must be visible above the keyboard and accent bar")
        // Return moves through the selected people and submits the final row.
        for (person, value) in ["aime","aimes","aime","aimons","aimez","aiment"].enumerated() {
            let field = app.textFields["answer.\(person)"]
            field.tap()
            field.typeText(value + "\n")
        }
        XCTAssertTrue(app.buttons["nextQuestion"].waitForExistence(timeout: 5))
        for person in 0..<6 { XCTAssertTrue(app.images["correct.\(person)"].exists) }
        capture("03-all-correct")
        app.buttons["nextQuestion"].tap()
        let second = app.textFields["answer.0"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        second.tap()
        for person in 0..<6 {
            let field = app.textFields["answer.\(person)"]
            field.tap()
            field.typeText("faux\n")
        }
        XCTAssertTrue(app.staticTexts["correction.0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["correction.0"].label, "écoute")
        capture("04-corrections")
        app.buttons["retryQuestion"].tap()
        XCTAssertTrue(app.textFields["answer.0"].waitForExistence(timeout: 5))
        capture("05-practice-keyboard")
        app.buttons["practiceMenu"].tap()
        app.buttons["结束练习"].tap()
        XCTAssertTrue(app.buttons["startPractice"].waitForExistence(timeout: 5))
    }

    func testReplicateFocusedAnswerAcrossPeople() {
        app.buttons["level.basic"].tap()
        app.buttons["startPractice"].tap()
        let first = app.textFields["answer.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        first.typeText("aim")
        let replicate = app.buttons["replicateAnswer"]
        XCTAssertTrue(replicate.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "replicateAnswer").count, 1)
        XCTAssertGreaterThan(replicate.frame.minX, first.frame.midX)
        XCTAssertEqual(replicate.frame.midY, first.frame.midY, accuracy: 10)
        capture("12-replicate-focused-input")
        replicate.tap()
        for person in 0..<6 {
            XCTAssertEqual(app.textFields["answer.\(person)"].value as? String, "aim")
        }
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        // Continue typing without another tap: copying must preserve the source focus.
        first.typeText("e")
        XCTAssertEqual(first.value as? String, "aime")
        XCTAssertEqual(app.textFields["answer.1"].value as? String, "aim")

        let nous = app.textFields["answer.3"]
        nous.tap()
        nous.typeText("ons")
        XCTAssertEqual(nous.value as? String, "aimons")
        XCTAssertEqual(replicate.frame.midY, nous.frame.midY, accuracy: 10)
        replicate.tap()
        for person in 0..<6 {
            XCTAssertEqual(app.textFields["answer.\(person)"].value as? String, "aimons")
        }
        capture("13-replicate-filled-answers")
        // An empty source is applied as-is too, clearing the other visible fields.
        nous.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        replicate.tap()
        for person in 0..<6 {
            XCTAssertEqual(app.textFields["answer.\(person)"].value as? String ?? "", "")
        }
        app.buttons["收起键盘"].tap()
        XCTAssertFalse(replicate.exists)
        app.textFields["answer.5"].tap()
        XCTAssertTrue(replicate.waitForExistence(timeout: 5))
        XCTAssertEqual(replicate.frame.midY, app.textFields["answer.5"].frame.midY, accuracy: 10)
        app.buttons["checkAnswers"].tap()
        XCTAssertTrue(app.buttons["retryQuestion"].waitForExistence(timeout: 5))
        XCTAssertFalse(replicate.exists)
    }

    func testSettingsFavoriteAndSearch() {
        app.buttons["level.basic"].tap()
        app.buttons["tenseOptions"].tap()
        XCTAssertTrue(app.switches["tense.perfect"].waitForExistence(timeout: 5))
        app.switches["tense.perfect"].tap()
        XCTAssertEqual(app.switches["tense.perfect"].value as? String, "1")
        capture("06-tense-options")
        app.buttons["optionsDone"].tap()
        app.buttons["personOptions"].tap()
        XCTAssertTrue(app.switches["person.0"].waitForExistence(timeout: 5))
        app.switches["person.0"].tap()
        capture("07-person-options")
        app.buttons["optionsDone"].tap()
        let aimer = app.buttons["verb.aimer"]
        if !aimer.isHittable { app.swipeUp() }
        aimer.tap()
        XCTAssertTrue(app.buttons["favoriteVerb"].waitForExistence(timeout: 5))
        app.buttons["favoriteVerb"].tap()
        XCTAssertEqual(app.buttons["favoriteVerb"].label, "取消收藏")
        capture("08-reference")
        app.buttons["完成"].tap()
        // Verify selections persisted when opening the options again.
        app.swipeDown()
        if app.buttons["tenseOptions"].isHittable {
            app.buttons["tenseOptions"].tap()
            XCTAssertEqual(app.switches["tense.perfect"].value as? String, "1")
            app.buttons["optionsDone"].tap()
        }
    }

    func testSearchAndOneVerbSessionCompletion() {
        let search = app.textFields["verbSearch"]
        search.tap()
        search.typeText("perdre")
        XCTAssertTrue(app.buttons["search.perdre"].waitForExistence(timeout: 5))
        app.buttons["search.perdre"].tap()
        let practice = app.buttons["practiceVerb"]
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        if !practice.isHittable { app.swipeUp() }
        practice.tap()
        XCTAssertTrue(app.textFields["answer.0"].waitForExistence(timeout: 5))
        capture("09-perdre-input")
        for (person, value) in ["perds","perds","perd","perdsont","perdsez","perdsent"].enumerated() {
            let field = app.textFields["answer.\(person)"]
            field.tap()
            field.typeText(value + "\n")
        }
        XCTAssertTrue(app.staticTexts["correction.3"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["correction.3"].label, "perdons")
        XCTAssertEqual(app.staticTexts["correction.4"].label, "perdez")
        XCTAssertEqual(app.staticTexts["correction.5"].label, "perdent")
        capture("10-perdre-feedback")
        app.buttons["nextQuestion"].tap()
        XCTAssertTrue(app.staticTexts["本轮练习完成"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3 / 6"].exists)
        capture("11-session-summary")
        app.buttons["finishSession"].tap()
        XCTAssertTrue(app.buttons["practiceVerb"].waitForExistence(timeout: 5))
    }

    func testDiagnosticLogsFilteringDetailsExportAndClear() {
        app.terminate()
        app.launchArguments += ["--seed-diagnostic-logs"]
        app.launch()
        openDiagnosticLogs(captureEntry: true)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("UI_DIAGNOSTIC\n")
        app.buttons["Warning"].tap()
        XCTAssertTrue(app.staticTexts["UI_DIAGNOSTIC_WARNING"].exists)
        XCTAssertFalse(app.staticTexts["UI_DIAGNOSTIC_ERROR"].exists)
        app.buttons["Error"].tap()
        XCTAssertTrue(app.staticTexts["UI_DIAGNOSTIC_ERROR"].exists)
        XCTAssertFalse(app.staticTexts["UI_DIAGNOSTIC_WARNING"].exists)
        app.buttons["全部"].tap()
        app.buttons["取消"].tap()
        capture("15-warning-error-logs")
        app.staticTexts["UI_DIAGNOSTIC_ERROR"].tap()
        XCTAssertTrue(app.navigationBars["日志详情"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DiagnosticsUITests (42): 导出与详情测试"].exists)
        capture("16-log-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["exportDiagnosticLogs"].tap()
        XCTAssertTrue(app.collectionViews["activityCollectionView"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["LP.CaptionBar.TopCaption"].label.hasPrefix("MyConju-Logs-"))
        capture("17-log-export")

        // Relaunch without reset or seeding: logs must come from persistent storage.
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        openDiagnosticLogs()
        search.tap()
        search.typeText("UI_DIAGNOSTIC\n")
        XCTAssertTrue(app.staticTexts["UI_DIAGNOSTIC_WARNING"].exists)
        XCTAssertTrue(app.staticTexts["UI_DIAGNOSTIC_ERROR"].exists)
        app.buttons["取消"].tap()
        app.buttons["clearDiagnosticLogs"].tap()
        app.sheets.buttons["清空日志"].tap()
        search.tap()
        search.typeText("UI_DIAGNOSTIC\n")
        XCTAssertFalse(app.staticTexts["UI_DIAGNOSTIC_WARNING"].exists)
        XCTAssertFalse(app.staticTexts["UI_DIAGNOSTIC_ERROR"].exists)
        capture("18-empty-error-logs")
        app.buttons["取消"].tap()
        app.buttons["logsDone"].tap()
        app.terminate()
        app.launch()
        openDiagnosticLogs()
        search.tap()
        search.typeText("UI_DIAGNOSTIC\n")
        XCTAssertFalse(app.staticTexts["UI_DIAGNOSTIC_WARNING"].exists)
        XCTAssertFalse(app.staticTexts["UI_DIAGNOSTIC_ERROR"].exists)
    }

    private func openDiagnosticLogs(captureEntry: Bool = false) {
        let entry = app.buttons["errorLogsEntry"]
        for _ in 0..<5 where !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertTrue(entry.isHittable)
        if captureEntry { capture("14-error-logs-entry") }
        entry.tap()
        XCTAssertTrue(app.navigationBars["错误日志"].waitForExistence(timeout: 5))
    }
}
