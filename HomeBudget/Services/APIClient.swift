import Foundation

/// The single place that talks HTTP. Services describe *what* to call;
/// this type knows *how*: build the request, send it, validate the status
/// and convert every failure into an `AppError`.
struct APIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = APIClient.defaultBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Debug builds talk to the local API; Release builds talk to Cloud Run.
    private static var defaultBaseURL: URL {
        #if DEBUG
        URL(string: "http://localhost:8080")!
        #else
        URL(string: "https://home-budget-api-689350097433.southamerica-east1.run.app")!
        #endif
    }

    /// `GET` that decodes the response body.
    func get<Response: Decodable>(
        _ path: String,
        query: [URLQueryItem] = []
    ) async throws(AppError) -> Response {
        let request = makeRequest(method: "GET", path: path, query: query)
        return try decode(try await perform(request))
    }

    /// `POST`/`PUT` with a JSON body that decodes the response body.
    func send<Body: Encodable, Response: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Body
    ) async throws(AppError) -> Response {
        var request = makeRequest(method: method, path: path, query: query)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw .encoding
        }
        return try decode(try await perform(request))
    }

    /// `DELETE`, which answers with no body.
    func delete(_ path: String) async throws(AppError) {
        _ = try await perform(makeRequest(method: "DELETE", path: path, query: []))
    }

    private func makeRequest(method: String, path: String, query: [URLQueryItem]) -> URLRequest {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            url.append(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func perform(_ request: URLRequest) async throws(AppError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw .network(error)
        } catch {
            throw .network(URLError(.unknown))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw .server(statusCode: httpResponse.statusCode)
        }
        return data
    }

    private func decode<Response: Decodable>(_ data: Data) throws(AppError) -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw .decoding
        }
    }
}
