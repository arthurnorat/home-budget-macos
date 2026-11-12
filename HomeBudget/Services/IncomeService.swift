import Foundation

/// The `/income` resource of the API. The month is the natural key:
/// there is at most one income per month, so `PUT` both creates and updates.
struct IncomeService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func fetch(month: String) async throws(AppError) -> MonthlyIncome {
        try await client.get("income", query: [URLQueryItem(name: "month", value: month)])
    }

    func save(month: String, _ request: IncomeRequest) async throws(AppError) -> MonthlyIncome {
        try await client.send(
            "PUT",
            "income",
            query: [URLQueryItem(name: "month", value: month)],
            body: request
        )
    }
}
