import XCTest

/// 各画面のスクリーンショットをテスト結果に添付する。
/// レイアウト崩れを目で確認したいときに `xcresulttool` で取り出す。
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["アプリの使用中は許可", "Allow While Using App"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 3) {
                button.tap()
                return
            }
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureScreens() {
        _ = app.staticTexts["新発売"].waitForExistence(timeout: 15)
        Thread.sleep(forTimeInterval: 1)
        capture("01-home")

        app.tabBars.buttons["探す"].tap()
        _ = app.collectionViews.cells.firstMatch.waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1)
        capture("02-search")

        app.collectionViews.cells.firstMatch.tap()
        _ = app.staticTexts["どこで買える？"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1)
        capture("03-product-detail")

        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        capture("04-product-detail-lower")

        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["マップ"].tap()
        Thread.sleep(forTimeInterval: 4)
        capture("05-map")

        app.tabBars.buttons["ニュース"].tap()
        Thread.sleep(forTimeInterval: 2)
        capture("06-news")

        app.tabBars.buttons["マイページ"].tap()
        Thread.sleep(forTimeInterval: 2)
        capture("07-profile")
    }
}
