# FullError

[![Swift 5.5](https://img.shields.io/badge/Swift-5.5-orange.svg?style=flat)](ttps://developer.apple.com/swift/)
[![Vapor 4](https://img.shields.io/badge/vapor-4.56-blue.svg?style=flat)](https://vapor.codes)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![Platforms OS X | Linux](https://img.shields.io/badge/Platforms-OS%20X%20%7C%20Linux%20-lightgray.svg?style=flat)](https://developer.apple.com/swift/)

Slightly modified Vapor.ErrorMiddleware [Vapor](https://github.com/Vapor).  
Custom error middleware for Vapor. Thanks to this FullError you can create errors with additional fields `code` and `values`. More you have field `field` for ValidationError. You create your own errors according to the `CodeError` protocol. 

## Getting started

You need to add library to `Package.swift` file:

 - add package to dependencies:
```swift
.package(url: "https://github.com/ViktorChernykh/fullerror.git", from: "2.0.0")
```

- and add product to your target:
```swift
.target(name: "App", dependencies: [
    . . .
    .product(name: "FullError", package: "fullerror")
])
```

Then you need add middleware to Vapor:

```swift
. . .
import FullError
import Vapor

public func configure(_ app: Application) throws {
. . .
// Add error middleware.
let errorMiddleware = FullErrorMiddleware()
app.middleware.use(errorMiddleware)
. . .
}
```

## Use case:

```swift
import FullError
import Vapor

enum UserError: CodeError {
    case emailIsNotFound([String] = [])
    var status: HTTPStatus {
        switch self {
        case .emailIsNotFound:
            return .badRequest
        }
    }
    var code: String {
        "\(String(describing: self))"
    }
    var reason: String {
        switch self {
        case .emailIsNotFound(let values):
            guard values.count == 1 else {
                fatalError("TestError.emailIsNotFound - values count is incorrect.")
            }
            return "Email '\(values[0])' is not found."
        }
    }
    
    var values: [String] {
        switch self {
        case .emailIsNotFound(let values):
            return values
        }
    }
}

throw UserError.emailIsNotFound(["name@email.com"])
```

Thanks to this to client will be send below JSON:

```json
{
    "code": "productIsNotFound",
    "reason": "Email 'name@email.com' is not found."
    "values": ["name@email.com"]
}
```

You can also create your own validation errors using `:` as separator:

```swift
import FullError

enum ValidateFailure: String {
    case nameLengthMustBeBetween([String])
    
    var codeReason: String {
        switch self {
        case .nameLengthMustBeBetween(let values):
            return "\(self.rawValue):Name length must be between \(values[0]) and \(values[1]):\(values.joined(separator: ", "))"
        }
    }
}
struct RegistrationDto: Content {
    name: String
}
extension RegistrationDto: Validatable {
    public static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: .count(3...32),
                        customFailureDescription: ValidateFailure.nameLengthMustBeBetween(["3", "32"]).codeReason)
    }
}
```

Thanks to this to client will be send below JSON:

```json
{
    "code": "validationError",
    "reason": "Validation errors occurs"
    "values": []
    [
        {
            "field": "name",
            "code": "nameLengthMustBeBetween",
            "reason": "Name length must be between 3 and 32",
            "values": ["3", "32"]
        }
    ]
}
```

The `code` and `values` allows you to show a custom message in different languages, and the `field` allows you to bind the message to the corresponding input field.  

## Developing

Download the source code and run in command line:

```bash
$ git clone https://github.com/ViktorChernykh/fullerror.git
$ swift package update
$ swift build
```
Run the following command if you want to open project in Xcode:

```bash
$ open Package.swift
```

## Contributing

You can fork and clone repository. Do your changes and pull a request.

