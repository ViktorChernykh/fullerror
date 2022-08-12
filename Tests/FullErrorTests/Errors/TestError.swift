import FullError
import Vapor

enum TestError: CodeError {
    case anyError
    var status: HTTPStatus {
        switch self {
        case .anyError:
            return .badRequest
        }
    }
    var code: String {
        "\(String(describing: self))"
    }
    var reason: String {
        switch self {
        case .anyError:
            return "There was any error."
        }
    }
}
