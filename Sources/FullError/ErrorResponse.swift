import Vapor

/// Structure for `FullErrorMiddleware` default response and for tests.
struct ErrorResponse: Content {
    // MARK: Stored properties
    /// The code of the reason.
    let code: String

    /// The reason for the error.
    let reason: String

    /// List with validation failures.
    let failures: [ValidationFailure]?
    
    // MARK: - Init
    init(code: String, reason: String, failures: [ValidationFailure]?) {
        self.code = code
        self.reason = reason
        self.failures = failures
    }
}
