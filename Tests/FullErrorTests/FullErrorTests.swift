@testable import FullError
import FullErrorModel
@testable import Vapor
import XCTVapor

final class FullErrorTests: XCTestCase {
    
    static var allTests = [
        ("testErrorTheСorrespondingCodeErrorShouldReturnCorrectErrorResponse", testErrorTheСorrespondingCodeErrorShouldReturnErrorResponse),
        ("testVerificationsErrorShouldReturnErrorFailures", testVerificationsErrorShouldReturnErrorFailures),
        ("testValidationErrorShouldReturnCorrectErrorFailures", testValidationErrorShouldReturnErrorFailures),
        ("testValidationErrorWithIncorrectDescription", testValidationErrorWithIncorrectDescription),
        ("testValidationErrorWithoutDescription", testValidationErrorWithoutDescription),
        ("testAbortError", testAbortError),
        ("testAnyError", testAnyError),
    ]
    
    func testErrorTheСorrespondingCodeErrorShouldReturnErrorResponse() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // given
        let request = Request(application: app, on: app.eventLoopGroup.next())
        
        // when
        let middleware = FullErrorMiddleware()
        let response = await middleware.body(req: request, error: TestError.emailIsNotFound(["test@email.com"]))
        let error = try response.content.decode(ErrorResponse.self)
        
        // then
        XCTAssertEqual(response.status, .badRequest)
        XCTAssertEqual(error.code, TestError.emailIsNotFound(["test@email.com"]).code)
        XCTAssertEqual(error.reason, TestError.emailIsNotFound(["test@email.com"]).reason)
    }
    
    func testVerificationsErrorShouldReturnErrorFailures() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // given
        let request = Request(application: app, on: app.eventLoopGroup.next())
        let failure1 = ValidationFailure(field: "name", code: "nameIsEmpty", reason: "Name is empty")
        let failure2 = ValidationFailure(field: "email", code: "emailIsInvalid", reason: "Email is invalid")
        let failures = VerificationsError(failures: [failure1, failure2])
        
        // when
        let middleware = FullErrorMiddleware()
        let response = await middleware.body(req: request, error: failures)
        let error = try response.content.decode(ErrorResponse.self)
        
        // then
        XCTAssertEqual(response.status, .badRequest)
        XCTAssertEqual(error.code, "ValidationError")
        XCTAssertEqual(error.reason, "Validation errors occurs.")
        
        XCTAssertEqual(error.failures![0].field, "name")
        XCTAssertEqual(error.failures![0].code, "nameIsEmpty")
        XCTAssertEqual(error.failures![0].reason, "Name is empty")
        
        XCTAssertEqual(error.failures![1].field, "email")
        XCTAssertEqual(error.failures![1].code, "emailIsInvalid")
        XCTAssertEqual(error.failures![1].reason, "Email is invalid")
    }
    
    func testValidationErrorShouldReturnErrorFailures() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // given
        let request = Request(application: app, on: app.eventLoopGroup.next())
        let failure = ValidateFailureDescribe.nameLengthMustBeBetween
        let validationResult = ValidationResult(
			key: ValidationKey.key("name"),
            result: FailureDescribe(isFailure: true),
            customFailureDescription: failure.codeReason)
        
        let failures = ValidationsError(failures: [validationResult])
        
        // when
        let middleware = FullErrorMiddleware()
        let response = await middleware.body(req: request, error: failures)
        let error = try response.content.decode(ErrorResponse.self)
        
        // then
        XCTAssertEqual(response.status, .badRequest)
        XCTAssertEqual(error.code, "ValidationError")
        XCTAssertEqual(error.reason, "Validation errors occurs.")
        
        XCTAssertEqual(error.failures![0].field, "name")
        XCTAssertEqual(error.failures![0].code, "nameLengthMustBeBetween")
        XCTAssertEqual(error.failures![0].reason, "Name length must be between 3 and 32")
    }
    
    func testValidationErrorWithIncorrectDescription() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // given
        let request = Request(application: app, on: app.eventLoopGroup.next())
        let failure = "any failure"
        let validationResult = ValidationResult(
			key: ValidationKey.key("name"),
            result: FailureDescribe(isFailure: true),
            customFailureDescription: failure)
        
        let failures = ValidationsError(failures: [validationResult])
        
        // when
        let middleware = FullErrorMiddleware()
        let response = await middleware.body(req: request, error: failures)
        let error = try response.content.decode(ErrorResponse.self)
        
        // then
        XCTAssertEqual(response.status, .badRequest)
        XCTAssertEqual(error.code, "ValidationError")
        XCTAssertEqual(error.reason, "Validation errors occurs.")
        
        XCTAssertEqual(error.failures![0].field, "name")
        XCTAssertEqual(error.failures![0].code, "")
        XCTAssertEqual(error.failures![0].reason, "any failure")
    }
    
    func testValidationErrorWithoutDescription() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // given
        let request = Request(application: app, on: app.eventLoopGroup.next())
        let validationResult = ValidationResult(
			key: ValidationKey.key("name"),
            result: FailureDescribe(
                isFailure: true,
                failureDescription: "Failure description"),
            customFailureDescription: nil)
        
        let failures = ValidationsError(failures: [validationResult])
        
        // when
        let middleware = FullErrorMiddleware()
        let response = await middleware.body(req: request, error: failures)
        let error = try response.content.decode(ErrorResponse.self)
        
        // then
        XCTAssertEqual(response.status, .badRequest)
        XCTAssertEqual(error.code, "ValidationError")
        XCTAssertEqual(error.reason, "Validation errors occurs.")
        
        XCTAssertEqual(error.failures![0].field, "name")
        XCTAssertEqual(error.failures![0].code, "")
        XCTAssertEqual(error.failures![0].reason, "Failure description")
    }
    
    func testAbortError() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // given
        let request = Request(application: app, on: app.eventLoopGroup.next())

        // when
        let middleware = FullErrorMiddleware()
        let response = await middleware.body(req: request, error: Abort(.notFound, reason: "Is not found"))
        let error = try response.content.decode(ErrorResponse.self)
        
        // then
        XCTAssertEqual(response.status, .notFound)
        XCTAssertEqual(error.code, "Is not found")
        XCTAssertEqual(error.reason, "Is not found.")
    }
    
    func testAnyError() async throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // given
        let request = Request(application: app, on: app.eventLoopGroup.next())

        // when
        let middleware = FullErrorMiddleware()
        let response = await middleware.body(req: request, error: "Something went wrong")
        let error = try response.content.decode(ErrorResponse.self)
        
        // then
        XCTAssertEqual(response.status, .internalServerError)
        XCTAssertEqual(error.code, "internalApplicationError")
        XCTAssertEqual(error.reason, "Something went wrong")
    }
}
