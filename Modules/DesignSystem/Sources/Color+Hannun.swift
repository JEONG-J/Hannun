import SwiftUI

/// static framework 의 Asset 은 main bundle 에 없다. 번들을 반드시 명시한다 (§9.1).
public extension Color {
    static let brand = Color("brand", bundle: .module)
}
