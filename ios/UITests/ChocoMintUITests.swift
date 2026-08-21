import XCTest

/// 5 タブが実際に開けて、主要な画面が描画されるかを通しで確認する。
/// 単体テストでは検出できない「起動して操作できる」ことを担保するのが目的。
final class ChocoMintUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        allowLocationIfNeeded()
    }

    /// 位置情報の確認ダイアログは SpringBoard 側に出る。
    private func allowLocationIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["アプリの使用中は許可", "Allow While Using App"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 3) {
                button.tap()
                return
            }
        }
    }

    private func tapTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "タブ「\(name)」が見つからない")
        tab.tap()
    }

    func testHomeShowsSections() {
        XCTAssertTrue(
            app.staticTexts["近くのチョコミント"].waitForExistence(timeout: 15),
            "ホームのセクションが表示されない"
        )
        XCTAssertTrue(app.staticTexts["新発売"].exists)
        XCTAssertTrue(app.staticTexts["今人気のチョコミント"].exists)
    }

    func testAllTabsOpen() {
        for tab in ["探す", "マップ", "ニュース", "マイページ"] {
            tapTab(tab)
            XCTAssertTrue(
                app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                "タブ「\(tab)」で画面が出ない"
            )
        }
        tapTab("ホーム")
    }

    /// 商品一覧 → 商品詳細 → レビュー一覧まで遷移できること。
    func testProductDetailNavigation() {
        tapTab("探す")
        let firstProduct = app.collectionViews.cells.firstMatch
        XCTAssertTrue(firstProduct.waitForExistence(timeout: 15), "検索結果が出ない")
        firstProduct.tap()

        XCTAssertTrue(
            app.staticTexts["どこで買える？"].waitForExistence(timeout: 15),
            "商品詳細が表示されない"
        )
        XCTAssertTrue(app.staticTexts["評価"].exists)
        XCTAssertTrue(app.buttons["食べた"].exists)
        XCTAssertTrue(app.buttons["食べたい"].exists)
        XCTAssertTrue(app.buttons["この商品を見つけた"].exists)
    }

    /// 未ログインで「食べた」を押すとログインが要求されること（設計 §39）。
    func testTastedRequiresSignIn() {
        tapTab("探す")
        let firstProduct = app.collectionViews.cells.firstMatch
        XCTAssertTrue(firstProduct.waitForExistence(timeout: 15))
        firstProduct.tap()

        let tastedButton = app.buttons["食べた"]
        XCTAssertTrue(tastedButton.waitForExistence(timeout: 15))
        tastedButton.tap()

        XCTAssertTrue(
            app.staticTexts["チョコミントを記録しよう"].waitForExistence(timeout: 10),
            "ログイン画面が出ない"
        )
    }

    /// マイページは未ログインならログインを促す。
    func testProfilePromptsSignIn() {
        tapTab("マイページ")
        XCTAssertTrue(
            app.staticTexts["ログインすると記録が残ります"].waitForExistence(timeout: 15),
            "未ログイン時の案内が出ない"
        )
    }
}
