import Foundation

struct Expense: Identifiable, Codable, Equatable {
    let expenseId: String
    let description: String
    let amount: Int
    let date: String
    let category: Category
    let createdAt: String

    var id: String { expenseId }
}
