import Foundation

enum ExpenseServiceError: Error {
    case invalidResponse
    case requestFailed(statusCode: Int)
    case decodingFailed(Error)
}

struct ExpenseService {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = ExpenseService.defaultBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    private static var defaultBaseURL: URL {
        #if DEBUG
        URL(string: "http://localhost:8080")!
        #else
        URL(string: "https://home-budget-api-689350097433.southamerica-east1.run.app")!
        #endif
    }

    func fetchExpenses(month: String) async throws -> [Expense] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("expenses"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "month", value: month)]

        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        return try Self.decode([Expense].self, from: data)
    }

    func create(_ request: ExpenseRequest) async throws -> Expense {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("expenses"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        try Self.validate(response)
        return try Self.decode(Expense.self, from: data)
    }

    func update(id: String, _ request: ExpenseRequest) async throws -> Expense {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("expenses/\(id)"))
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        try Self.validate(response)
        return try Self.decode(Expense.self, from: data)
    }

    func delete(id: String) async throws {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("expenses/\(id)"))
        urlRequest.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: urlRequest)
        try Self.validate(response)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExpenseServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ExpenseServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ExpenseServiceError.decodingFailed(error)
        }
    }
}
