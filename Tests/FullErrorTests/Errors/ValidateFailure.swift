
enum ValidateFailureDescribe: String {
    case nameIsRequired

    var codeReason: String {
        switch self {
        case .nameIsRequired:
            return "\(self.rawValue):Name is required"
        }
    }
}
