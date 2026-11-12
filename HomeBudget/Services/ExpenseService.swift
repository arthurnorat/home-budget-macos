import Foundation

/// The `/expenses` resource of the API.
struct ExpenseService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func fetchExpenses(month: String) async throws(AppError) -> [Expense] {
        try await client.get("expenses", query: [URLQueryItem(name: "month", value: month)])
    }

    func create(_ request: ExpenseRequest) async throws(AppError) -> Expense {
        try await client.send("POST", "expenses", body: request)
    }

    func update(id: String, _ request: ExpenseRequest) async throws(AppError) -> Expense {
        try await client.send("PUT", "expenses/\(id)", body: request)
    }

    func delete(id: String) async throws(AppError) {
        try await client.delete("expenses/\(id)")
    }
}
