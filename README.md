# FullError

[![Swift 5.5](https://img.shields.io/badge/Swift-5.5-orange.svg?style=flat)](ttps://developer.apple.com/swift/)
[![Vapor 4](https://img.shields.io/badge/vapor-4.56-blue.svg?style=flat)](https://vapor.codes)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![Platforms OS X | Linux](https://img.shields.io/badge/Platforms-OS%20X%20%7C%20Linux%20-lightgray.svg?style=flat)](https://developer.apple.com/swift/)

Slightly modified Vapor.ErrorMiddleware [Vapor](https://github.com/Vapor).  
Custom error middleware for Vapor. Thanks to this FullError you can create errors with additional field `code`. More you have field `field` for ValidationError. You create your own errors according to the `CodeError` protocol. 

## Getting started

You need to add library to `Package.swift` file:

 - add package to dependencies:
```swift
.package(url: "https://github.com/ViktorChernykh/fullerror.git", from: "1.0.0")
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

enum ProductError {
    case productIsNotFound
}

extension ProductError: CodeError {
    var status: HTTPStatus
        switch self {
        case .productIsNotFound:
            return "Product is not found."
        }
    var code: String {
        "\(String(describing: self))"
    }
    var reason: String {
        switch self {
        case .productIsNotFound:
            return "There is no product with the specified ID."
        }
    }
}

throw ProductError.productIsNotFound
```

Thanks to this to client will be send below JSON:

```json
{
    "code": "productIsNotFound",
    "reason": "There is no product with the specified ID."
}
```

You can also create your own validation errors:

```swift
import FullError

enum ValidateFailure: String {
    case nameIsRequired
    
    var codeReason: String {
        switch self {
        case .nameIsRequired:
            return "\(self.rawValue):Name must be no empty"
        }
    }
}
struct RegistrationDto: Content {
    name: String
}
extension RegistrationDto: Validatable {
    public static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty,
                        customFailureDescription: ValidateFailure.nameIsRequired.codeReason)
    }
}
```

Thanks to this to client will be send below JSON:

```json
{
    "code": "validationError",
    "reason": "Validation errors occurs"
    [
        {
            "field": "name",
            "code": "nameIsRequired",
            "reason": "Name must be no empty"
        }
    ]
}
```

The `code` allows you to show a custom message in different languages, and the `field` allows you to bind the message to the corresponding input field.  

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

