import Vapor

/// A structure for an array of validation errors.
public struct ValidationFailure: Content {
    // MARK: Stored properties
    /// Field name.
    public let field: String
    
    /// The code of the reason.
    public let code: String
    
    /// The reason for the error.
    public let reason: String
    
    // MARK: - Init    
    public init(field: String, code: String, reason: String) {
        self.field = field
        self.code = code
        self.reason = reason
    }
}
