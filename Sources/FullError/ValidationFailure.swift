import Vapor
import FullErrorModel

extension ValidationFailure {
    public init(field: String, error: CodeError) {
        self.init(
            field: field,
            code: error.code,
            reason: error.reason,
            values: error.values)
    }
}
