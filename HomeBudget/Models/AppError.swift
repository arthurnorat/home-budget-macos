import Foundation

/// Every failure the app can meet while talking to the API.
enum AppError: Error, Equatable {
    /// The request never got an HTTP answer (offline, timeout, server down).
    case network(URLError)
    /// The answer was not an HTTP response.
    case invalidResponse
    /// The server answered with a status outside 200–299.
    case server(statusCode: Int)
    /// The response body does not match the expected model.
    case decoding
    /// The request body could not be turned into JSON.
    case encoding

    /// Text shown to the user. UI text is in Portuguese.
    var userMessage: String {
        switch self {
        case .network:
            return "Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente."
        case .invalidResponse:
            return "O servidor enviou uma resposta inválida."
        case .server(let statusCode) where statusCode == 404:
            return "Este registro não existe mais no servidor."
        case .server(let statusCode) where (400..<500).contains(statusCode):
            return "O servidor recusou os dados enviados (erro \(statusCode))."
        case .server(let statusCode):
            return "O servidor está com problemas (erro \(statusCode)). Tente novamente em instantes."
        case .decoding:
            return "Não foi possível interpretar os dados recebidos do servidor."
        case .encoding:
            return "Não foi possível preparar os dados para envio."
        }
    }
}
