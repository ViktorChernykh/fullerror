import FullError
import Vapor

enum TestError: CodeError {
    case emailIsNotFound([String] = [])
    var status: HTTPStatus {
        switch self {
        case .emailIsNotFound:
            return .badRequest
        }
    }
    var code: String {
        "\(String(describing: self))"
    }
    var reason: String {
        switch self {
        case .emailIsNotFound(let values):
            guard values.count == 1 else {
                fatalError("TestError.emailIsNotFound - values count is incorrect.")
            }
            return "Email '\(values[0])' is not found."
        }
    }
    
    var values: [String] {
        switch self {
        case .emailIsNotFound(let values):
            return values
        }
    }
}
