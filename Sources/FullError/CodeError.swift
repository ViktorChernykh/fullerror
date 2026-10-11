import Vapor
import FullErrorModel

/// Use this protocol for application errors
public protocol CodeError: AbortError {
    
    /// The code for translate this error.
    var code: String { get }

	/// Typed values for translating this error.
	var parameters: [String: ErrorParameterValueType]? { get }
}

public extension CodeError {
	var parameters: [String: ErrorParameterValueType]? {
		nil
	}
}
