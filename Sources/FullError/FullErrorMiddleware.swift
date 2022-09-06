import Vapor
import FullErrorModel

/// Captures all errors and transforms them into an internal server error HTTP response.
public struct FullErrorMiddleware: AsyncMiddleware {
    
    // MARK: - Init
    public init() { }
    
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
        let values: [String]
        lazy var failures: [ValidationFailure] = []
        
        // inspect the error type
        switch error {
        case let custom as CodeError:
            code = custom.code
            headers = custom.headers
            reason = custom.reason
            status = custom.status
            values = custom.values
        case let validation as VerificationsError:
            failures = validation.failures
            code = "ValidationError"
            headers = [:]
            reason = "Validation errors occurs."
            status = .badRequest
            values = []
        case let validation as Vapor.ValidationsError:
            for failure in validation.failures {
                var items = [String]()
                if let description = failure.customFailureDescription {
                    items = description.split(separator: ":", maxSplits: 2).map { String($0) }
                    if items.count == 3 {
                        failures.append(ValidationFailure(
                            field: failure.key.stringValue,
                            code: items[0],
                            reason: items[1],
                            values: items[2].components(separatedBy: ", ")))
                    } else {
                        failures.append(ValidationFailure(
                            field: failure.key.stringValue,
                            code: "",
                            reason: failure.customFailureDescription!, values: []))
                    }
                } else {
                    failures.append(ValidationFailure(
                        field: failure.key.stringValue,
                        code: "",
                        reason: failure.result.failureDescription ?? "",
                        values: []))
                }
            }
            code = "ValidationError"
            headers = [:]
            reason = "Validation errors occurs."
            status = .badRequest
            values = []
        case let abort as AbortError:
            code = abort.reason
            headers = abort.headers
            reason = abort.reason + "."
            status = abort.status
            values = []
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
            values = []
        default:
            code = "internalApplicationError"
            headers = [:]
            // if not release mode, and error is debuggable, provide debug info
            // otherwise, deliver a generic 500 to avoid exposing any sensitive error info
            reason = req.application.environment.isRelease
            ? "The operation failed due to a server error."
            : String(describing: error)
            status = .internalServerError
            values = []
        }
        
        req.logger.report(error: error)
        
        // Attempt to serialize the error to json.
        do {
            let errorResponse = ErrorResponse(code: code, reason: reason, values: values, failures: failures)
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

