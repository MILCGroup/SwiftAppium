import SwiftAppium

extension Driver {
    public static let chrome = Driver.Chromium(
        platformVersion: "135.0.7049.96",
        automationName: "Chromium",
        browserName: "chrome"
    )
}
