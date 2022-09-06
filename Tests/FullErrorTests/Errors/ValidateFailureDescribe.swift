
enum ValidateFailureDescribe: String {
    case nameLengthMustBeBetween

    var codeReason: String {
        switch self {
        case .nameLengthMustBeBetween:
            return "\(self.rawValue):Name length must be between 3 and 32:3, 32"
        }
    }
}
