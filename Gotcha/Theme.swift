import SwiftUI
import UIKit

enum Theme {

    static let ink = Color(light: 0.06, dark: 0.94)

    static let paper = Color(light: 1.00, dark: 0.05)

    static let surface = Color(light: 0.95, dark: 0.10)

    static let elevated = Color(light: 1.00, dark: 0.14)

    static let hairline = Color(light: 0.88, dark: 0.20)

    static let muted = Color(light: 0.42, dark: 0.60)
}

extension Color {
    init(light: Double, dark: Double) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: dark, alpha: 1)
                : UIColor(white: light, alpha: 1)
        })
    }
}
