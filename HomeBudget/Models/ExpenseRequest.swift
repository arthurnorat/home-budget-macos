import Foundation

struct ExpenseRequest: Encodable {
    let description: String
    let amount: Int
    let date: String
    let category: Category
}
