import XCTest
import AppKit

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
    private func launch(_ fixture: String, appearance: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--wmt-ui-tests"]
        app.launchEnvironment["WMT_UI_FIXTURE"] = fixture
        if let appearance {
            app.launchEnvironment["WMT_UI_APPEARANCE"] = appearance
        }
        app.launch()
        runningApp = app

        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 20),
            "The actual macOS application must launch for GUI screenshots."
        )
        XCTAssertTrue(app.staticTexts["mainHeading"].waitForExistence(timeout: 10))
        return app
    }

    /// Baseline-free render smoke check: sample pixels away from the gutter and
    /// focus border. If the editor's text is present in accessibility but all
    /// glyphs are invisible, this region is almost entirely the background.
    /// This is deliberately coarse; screenshot attachments remain authoritative.
    private func paintedTextSampleCount(_ editor: XCUIElement) -> Int {
        let image = editor.screenshot().image
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              bitmap.pixelsWide > 180, bitmap.pixelsHigh > 80,
              let sample = bitmap.colorAt(
                x: bitmap.pixelsWide * 9 / 10,
                y: bitmap.pixelsHigh * 4 / 5
              )?.usingColorSpace(.deviceRGB) else { return 0 }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        let firstX = width / 7
        let lastX = width * 3 / 4
        let firstY = max(12, height / 50)
        let lastY = min(height / 2, 220)
        var contrastCount = 0

        for y in stride(from: firstY, to: lastY, by: 2) {
            for x in stride(from: firstX, to: lastX, by: 2) {
                guard let color = bitmap.colorAt(x: x, y: y)?
                    .usingColorSpace(.deviceRGB) else { continue }
                let contrast = max(
                    abs(color.redComponent - sample.redComponent),
                    max(
                        abs(color.greenComponent - sample.greenComponent),
                        abs(color.blueComponent - sample.blueComponent)
                    )
                )
                if contrast > 0.28 { contrastCount += 1 }
            }
        }

        return contrastCount
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
        XCTAssertGreaterThan(
            paintedTextSampleCount(draft),
            80,
            "Editor text is in accessibility but no contrasting glyph pixels were found."
        )
        XCTAssertTrue(app.staticTexts["pythonBadge"].exists)
        XCTAssertTrue(app.staticTexts["draftHeading-Draft 1"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "codeFormattingNotice").firstMatch.exists
        )
    }

    func testDarkModePythonRendering() {
        let app = launch("python", appearance: "dark")
        let draft = editor(1, in: app)
        XCTAssertTrue(draft.isHittable)
        XCTAssertTrue((draft.value as? String ?? "").contains("def greet(name: str)"))
        XCTAssertTrue(app.staticTexts["pythonBadge"].exists)
        XCTAssertGreaterThan(
            paintedTextSampleCount(draft),
            80,
            "Dark Mode source is in accessibility but its glyphs are invisible."
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
