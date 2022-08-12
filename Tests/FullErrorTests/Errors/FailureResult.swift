import Vapor

public struct FailureDescribe: ValidatorResult {
    public let isFailure: Bool
    public let successDescription: String?
    public let failureDescription: String?
    
    public init(
        isFailure: Bool,
        successDescription: String? = nil,
        failureDescription: String? = nil
    ) {
        self.isFailure = isFailure
        self.successDescription = successDescription
        self.failureDescription = failureDescription
    }
}

