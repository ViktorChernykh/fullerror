import Vapor

/// Use this protocol for application errors
public protocol CodeError: AbortError {
    
    /// The code for translate this error.
    var code: String { get }
}

