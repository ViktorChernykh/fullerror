import Foundation
import Testing
@testable import Vapor
import XCTVapor
import FullError
import FullErrorModel

private struct ParameterizedRouteError: CodeError {
	var status: HTTPStatus {
		.tooManyRequests
	}

	var headers: HTTPHeaders {
		var result: HTTPHeaders = [:]
		result.add(name: "Retry-After", value: "40")

		return result
	}

	var code: String {
		"mailRateLimited"
	}

	var reason: String {
		"Wait 40 seconds"
	}

	var parameters: [String: ErrorParameterValueType]? {
		["seconds": .integer(40)]
	}
}

private struct LegacyRouteError: CodeError {
	var status: HTTPStatus {
		.badRequest
	}

	var code: String {
		"legacy"
	}

	var reason: String {
		"Old error"
	}
}

private struct RouteFailureResult: ValidatorResult {
	let isFailure: Bool = true
	let successDescription: String? = nil
	let failureDescription: String? = "invalid"
}

private final class ResolverRecorder: @unchecked Sendable {
	private let lock: NSLock = NSLock()
	private var calls: [String] = []

	func record(field: String, code: String) {
		lock.lock()
		calls.append("\(field):\(code)")
		lock.unlock()
	}

	func snapshot() -> [String] {
		lock.lock()
		let result: [String] = calls
		lock.unlock()

		return result
	}
}

@Test("CodeError parameters cross a real route without changing status or headers")
func codeErrorRouteParameters() throws {
	let app: Application = Application(.testing)
	defer { app.shutdown() }
	app.middleware = .init()
	app.middleware.use(FullErrorMiddleware(), at: .beginning)
	app.get("typed") { _ async throws -> String in
		let error: any CodeError = ParameterizedRouteError()

		throw error
	}
	app.get("legacy") { _ async throws -> String in
		throw LegacyRouteError()
	}

	try app.test(.GET, "/typed") { response in
		let body: ErrorResponse = try JSONDecoder().decode(
			ErrorResponse.self,
			from: Data(response.body.readableBytesView)
		)
		#expect(response.status == .tooManyRequests)
		#expect(response.headers.first(name: "Retry-After") == "40")
		#expect(response.headers.first(name: .contentType) == "application/json; charset=utf-8")
		#expect(body.code == "mailRateLimited")
		#expect(body.reason == "Wait 40 seconds")
		#expect(body.parameters?["seconds"] == .integer(40))
		#expect(body.failures?.count == 0)
	}

	try app.test(.GET, "/legacy") { response in
		let body: ErrorResponse = try JSONDecoder().decode(
			ErrorResponse.self,
			from: Data(response.body.readableBytesView)
		)
		#expect(response.status == .badRequest)
		#expect(response.headers.first(name: "Retry-After") == nil)
		#expect(body.code == "legacy")
		#expect(body.parameters == nil)
	}
}

@Test("Prebuilt validation failures keep parameters and their order")
func prebuiltValidationRouteParameters() throws {
	let app: Application = Application(.testing)
	defer { app.shutdown() }
	app.middleware = .init()
	app.middleware.use(FullErrorMiddleware(), at: .beginning)
	app.get("prebuilt") { _ async throws -> String in
		let typed: ValidationFailure = ValidationFailure(
			field: "first",
			error: ParameterizedRouteError()
		)
		let old: ValidationFailure = ValidationFailure(
			field: "second",
			error: LegacyRouteError()
		)

		throw VerificationsError(failures: [typed, old])
	}

	try app.test(.GET, "/prebuilt") { response in
		let body: ErrorResponse = try JSONDecoder().decode(
			ErrorResponse.self,
			from: Data(response.body.readableBytesView)
		)
		let failures: [ValidationFailure] = try #require(body.failures)
		#expect(response.status == .badRequest)
		#expect(response.headers.first(name: "Retry-After") == nil)
		#expect(body.code == "ValidationError")
		#expect(body.reason == "Validation errors occurs.")
		#expect(body.parameters == nil)
		try #require(failures.count == 2)
		#expect(failures[0].field == "first")
		#expect(failures[0].code == "mailRateLimited")
		#expect(failures[0].parameters?["seconds"] == .integer(40))
		#expect(failures[1].field == "second")
		#expect(failures[1].code == "legacy")
		#expect(failures[1].parameters == nil)
	}
}

@Test("Vapor validation resolver uses only parsed nonempty custom codes")
func vaporValidationRouteParameters() throws {
	let app: Application = Application(.testing)
	defer { app.shutdown() }
	app.middleware = .init()
	let recorder: ResolverRecorder = ResolverRecorder()
	let middleware: FullErrorMiddleware = FullErrorMiddleware(
		validationParameters: { field, code in
			recorder.record(field: field, code: code)
			guard field == "first" && code == "range" else {
				return nil
			}

			return ["minimum": .integer(1), "maximum": .integer(63)]
		}
	)
	app.middleware.use(middleware, at: .beginning)
	app.get("validation") { _ async throws -> String in
		let result: RouteFailureResult = RouteFailureResult()
		let failures: [ValidationResult] = [
			ValidationResult(
				key: .key("first"),
				result: result,
				customFailureDescription: "range:Between 1 and 63"
			),
			ValidationResult(
				key: .key("second"),
				result: result,
				customFailureDescription: "other:Unchanged"
			),
			ValidationResult(
				key: .key("third"),
				result: result,
				customFailureDescription: ":No code"
			),
			ValidationResult(
				key: .key("fourth"),
				result: result,
				customFailureDescription: nil
			),
			ValidationResult(
				key: .key("fifth"),
				result: result,
				customFailureDescription: "triple:message:details"
			)
		]

		throw Vapor.ValidationsError(failures: failures)
	}

	try app.test(.GET, "/validation") { response in
		let body: ErrorResponse = try JSONDecoder().decode(
			ErrorResponse.self,
			from: Data(response.body.readableBytesView)
		)
		let failures: [ValidationFailure] = try #require(body.failures)
		#expect(response.status == .badRequest)
		#expect(body.code == "ValidationError")
		#expect(body.reason == "Validation errors occurs.")
		#expect(body.parameters == nil)
		try #require(failures.count == 5)
		#expect(failures[0].field == "first")
		#expect(failures[0].code == "range")
		#expect(failures[0].reason == "Between 1 and 63")
		#expect(failures[0].parameters == [
			"minimum": .integer(1),
			"maximum": .integer(63)
		])
		#expect(failures[1].field == "second")
		#expect(failures[1].code == "other")
		#expect(failures[1].reason == "Unchanged")
		#expect(failures[1].parameters == nil)
		#expect(failures[2].field == "third")
		#expect(failures[2].code == "")
		#expect(failures[2].reason == ":No code")
		#expect(failures[2].parameters == nil)
		#expect(failures[3].field == "fourth")
		#expect(failures[3].code == "")
		#expect(failures[3].reason == "invalid")
		#expect(failures[3].parameters == nil)
		#expect(failures[4].field == "fifth")
		#expect(failures[4].code == "")
		#expect(failures[4].reason == "triple:message:details")
		#expect(failures[4].parameters == nil)
	}
	#expect(recorder.snapshot() == ["first:range", "second:other"])
}
