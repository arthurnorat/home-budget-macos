import Foundation

enum Category: String, Codable, CaseIterable, Identifiable {
    case fixed = "FIXED"
    case variable = "VARIABLE"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixed: return "Fixo"
        case .variable: return "Variável"
        }
    }
}
