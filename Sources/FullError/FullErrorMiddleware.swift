import Vapor
import FullErrorModel

/// Captures all errors and transforms them into an internal server error HTTP response.
public struct FullErrorMiddleware: AsyncMiddleware {
	private let validationParameters: @Sendable (
		_ field: String,
		_ code: String
	) -> [String: ErrorParameterValueType]?

    // MARK: - Init
	/// Creates middleware with values for parsed custom validation codes.
	///
	/// - Parameter validationParameters: Values for a field and code.
	public init(
		validationParameters: @escaping @Sendable (
			_ field: String,
			_ code: String
		) -> [String: ErrorParameterValueType]? = { _, _ in nil }
	) {
		self.validationParameters = validationParameters
	}
    
    // MARK: - Methods
    /// See `Middleware`.
    public func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: req)
        } catch {
            return await self.body(req: req, error: error)
        }
    }
    
    /// Error-handling closure.
    internal func body(req: Request, error: Error) async -> Response {
        
        // variables to determine
        let code: String
        let headers: HTTPHeaders
        let reason: String
        let status: HTTPStatus
		let parameters: [String: ErrorParameterValueType]?
		let source: ErrorSource
        lazy var failures: [ValidationFailure] = []
        
        // inspect the error type
        switch error {
        case let custom as CodeError:
            code = custom.code
            headers = custom.headers
            reason = custom.reason
            status = custom.status
			parameters = custom.parameters
			source = .capture()
        case let validation as VerificationsError:
            failures = validation.failures
            code = "ValidationError"
            headers = [:]
            reason = "Validation errors occurs."
            status = .badRequest
			parameters = nil
			source = .capture()
        case let validation as Vapor.ValidationsError:
            for failure in validation.failures {
                var items = [String]()
                if let description = failure.customFailureDescription {
                    items = description.split(separator: ":", maxSplits: 2).map { String($0) }
                    if items.count == 2 {
						let customCode: String = items[0]
						let values: [String: ErrorParameterValueType]? = customCode.isEmpty
							? nil
							: validationParameters(failure.key.stringValue, customCode)
                        failures.append(ValidationFailure(
                            field: failure.key.stringValue,
                            code: customCode,
							reason: items[1],
							parameters: values))
                    } else {
                        failures.append(ValidationFailure(
                            field: failure.key.stringValue,
                            code: "",
                            reason: failure.customFailureDescription!))
                    }
                } else {
                    failures.append(ValidationFailure(
                        field: failure.key.stringValue,
                        code: "",
                        reason: failure.result.failureDescription ?? ""))
                }
            }
            code = "ValidationError"
            headers = [:]
            reason = "Validation errors occurs."
            status = .badRequest
			parameters = nil
			source = .capture()
        case let abort as AbortError:
            code = abort.reason
            headers = abort.headers
            reason = abort.reason
            status = abort.status
			parameters = nil
			source = .capture()
        case let debug as DebuggableError:
            code = req.application.environment.isRelease
            ? "internalApplicationError"
            : debug.identifier
            headers = [:]
            // if not release mode, and error is debuggable, provide debug info
            // otherwise, deliver a generic 500 to avoid exposing any sensitive error info
            reason = req.application.environment.isRelease
            ? "The operation failed due to a server error."
            : debug.reason
            status = .internalServerError
			parameters = nil
			source = debug.source ?? .capture()
        default:
            code = "internalApplicationError"
            headers = [:]
            // if not release mode, and error is debuggable, provide debug info
            // otherwise, deliver a generic 500 to avoid exposing any sensitive error info
            reason = req.application.environment.isRelease
            ? "The operation failed due to a server error."
            : String(describing: error)
            status = .internalServerError
			parameters = nil
			source = .capture()
        }
        
		// Report the error
		req.logger.report(
			error: error,
			metadata: ["method" : "\(req.method.rawValue)",
					   "url" : "\(req.url.string)",
					   "userAgent" : .array(req.headers["User-Agent"].map { "\($0)" })],
			file: source.file,
			function: source.function,
			line: source.line
		)

        // Attempt to serialize the error to json.
        do {
            let errorResponse = ErrorResponse(
				code: code,
				reason: reason,
				failures: failures,
				parameters: parameters
			)
            let body = try Response.Body(data: JSONEncoder().encode(errorResponse))
            let response = Response(status: status, headers: headers, body: body)
            response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
            
            return response
        } catch {
            let body = Response.Body(string: "Oops: \(error)")
            let response = Response(status: status, headers: headers, body: body)
            response.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
            
            return response
        }
    }
}
