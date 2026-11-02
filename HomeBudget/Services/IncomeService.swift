import Foundation

enum IncomeServiceError: Error {
    case invalidResponse
    case requestFailed(statusCode: Int)
    case decodingFailed(Error)
}

struct IncomeService {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = IncomeService.defaultBaseURL, session: URLSession = .shared) {
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

    func fetch(month: String) async throws -> MonthlyIncome {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("income"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "month", value: month)]

        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        return try Self.decode(MonthlyIncome.self, from: data)
    }

    func save(month: String, _ request: IncomeRequest) async throws -> MonthlyIncome {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("income"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "month", value: month)]

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        try Self.validate(response)
        return try Self.decode(MonthlyIncome.self, from: data)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IncomeServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw IncomeServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw IncomeServiceError.decodingFailed(error)
        }
    }
}
