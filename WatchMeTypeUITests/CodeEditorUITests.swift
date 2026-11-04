import XCTest

/// End-to-end AppKit/SwiftUI layout smoke tests. Every test captures the real
/// macOS window as an xcresult screenshot attachment, including on failures.
///
/// These tests cannot by themselves prove that syntax glyphs are painted:
/// retain and inspect the screenshots, or add approved pixel baselines later.
final class CodeEditorUITests: XCTestCase {
    private var runningApp: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if let app = runningApp {
            if app.windows.firstMatch.exists {
                let screenshot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
                screenshot.name = "\(name)-window"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            app.terminate()
        }
        try super.tearDownWithError()
    }

    @discardableResult
    private func launch(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--wmt-ui-tests"]
        app.launchEnvironment["WMT_UI_FIXTURE"] = fixture
        app.launch()
        runningApp = app

        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 20),
            "The actual macOS application must launch for GUI screenshots."
        )
        XCTAssertTrue(app.staticTexts["mainHeading"].waitForExistence(timeout: 10))
        return app
    }

    private func editor(_ number: Int, in app: XCUIApplication) -> XCUIElement {
        let element = app.textViews["draft\(number)Editor"]
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Draft \(number) NSTextView missing")
        return element
    }

    func testEmptyCodeEditorAndCaret() {
        let app = launch("empty")
        let draft = editor(1, in: app)
        XCTAssertTrue(draft.isHittable)
        XCTAssertTrue(app.staticTexts["pythonBadge"].exists)
        XCTAssertTrue(app.staticTexts["draftHeading-Draft 1"].exists)

        draft.click()
        draft.typeText("print('ready')")
        XCTAssertTrue(
            (draft.value as? String)?.contains("print('ready')") == true,
            "The text editor must accept real keyboard input."
        )
    }

    func testMultilinePythonFixture() {
        let app = launch("python")
        let draft = editor(1, in: app)
        XCTAssertTrue(draft.isHittable)
        let value = draft.value as? String ?? ""
        XCTAssertTrue(value.contains("def greet(name: str)"))
        XCTAssertTrue(value.contains("return f\"Hello, {name}!\""))
        XCTAssertTrue(app.staticTexts["pythonBadge"].exists)
        XCTAssertTrue(app.staticTexts["draftHeading-Draft 1"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "codeFormattingNotice").firstMatch.exists
        )
    }

    func testLongLineWrapping() {
        let app = launch("wrapped")
        let draft = editor(1, in: app)
        XCTAssertTrue(draft.isHittable)
        XCTAssertTrue((draft.value as? String ?? "").contains("this_is_a_long_unbroken_token"))
    }

    func testScrollingLongPythonFile() {
        let app = launch("scroll")
        let draft = editor(1, in: app)
        XCTAssertTrue((draft.value as? String ?? "").contains("line 160"))
        XCTAssertTrue(draft.isHittable)
        draft.swipeUp()
        XCTAssertTrue(draft.exists)
    }

    func testSwitchingBackToNormalPreservesSource() {
        let app = launch("python")
        let draft = editor(1, in: app)
        let original = draft.value as? String
        XCTAssertNotNil(original)
        let toggle = app.checkBoxes["codeModeToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.click()

        XCTAssertFalse(app.staticTexts["pythonBadge"].exists)
        XCTAssertTrue(app.staticTexts["Clean-Up"].exists)
        XCTAssertEqual(draft.value as? String, original)
    }

    func testNormalProseUnchanged() {
        let app = launch("normal")
        let draft = editor(1, in: app)
        XCTAssertTrue((draft.value as? String ?? "").contains("Normal mode should"))
        XCTAssertFalse(app.staticTexts["pythonBadge"].exists)
        XCTAssertTrue(app.staticTexts["Clean-Up"].exists)
    }

    func testTwoDraftLayout() {
        let app = launch("two-drafts")
        XCTAssertTrue(editor(1, in: app).exists)
        XCTAssertTrue(editor(2, in: app).exists)
        XCTAssertTrue(app.staticTexts["draftHeading-Draft 2"].exists)
        XCTAssertTrue((editor(2, in: app).value as? String ?? "").contains("Grace"))
    }

    func testThreeDraftLayout() {
        let app = launch("three-drafts")
        XCTAssertTrue(editor(1, in: app).exists)
        XCTAssertTrue(editor(2, in: app).exists)
        XCTAssertTrue(editor(3, in: app).exists)
        XCTAssertTrue(app.staticTexts["draftHeading-Draft 3"].exists)
        XCTAssertTrue((editor(3, in: app).value as? String ?? "").contains("Linus"))
    }
}
