import Foundation

/// 포트폴리오 분류 축. DesignSystem 이 색·아이콘 매핑에 쓰므로 Domain 이 아닌 Core 에 둔다 (§3).
public enum AssetCategory: String, Codable, Sendable, CaseIterable {
    case cash
    case domesticStock
    case overseasStock
    case etf
    case crypto
}
