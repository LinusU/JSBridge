# JSBridge

Bridge your JavaScript library for usage in Swift 🚀

## Installation

### SwiftPM

```swift
dependencies: [
    .package(url: "https://github.com/LinusU/JSBridge", from: "1.0.0"),
]
```

### Carthage

```text
github "LinusU/JSBridge" ~> 1.0.0
```

### Manually

If you have [PromiseKit](https://github.com/mxcl/PromiseKit) installed, you can simply drop the single source file [JSBridge.swift](Sources/JSBridge.swift) into your project.

## Usage

**foobar.js:**

```js
window.Foobar = {
  add (a, b) {
    return a + b
  },
  greet (name) {
    return `Hello, ${name}!`
  },
  async fetch (url) {
    const response = await fetch(url)
    const body = await response.text()

    return { status: response.status, body }
  }
}
```

**Foobar.swift:**

```swift
struct FetchResponse: Decodable {
    let status: Int
    let body: String
}

class Foobar {
    static internal let bridge: JSBridge = {
        let libraryPath = Bundle.main.path(forResource: "foobar", ofType: "js")!
        let libraryCode = try! String(contentsOfFile: libraryPath)

        return JSBridge(libraryCode: libraryCode)
    }()

    static func add(_ lhs: Int, _ rhs: Int) -> Promise<Int> {
        return Foobar.bridge.call(function: "Foobar.add", withArgs: (lhs, rhs)) as Promise<Int>
    }

    static func greet(name: String) -> Promise<String> {
        return Foobar.bridge.call(function: "Foobar.greet", withArg: name) as Promise<String>
    }

    static func fetch(url: URL) -> Promise<FetchResponse> {
        return Foobar.bridge.call(function: "Foobar.fetch", withArg: url) as Promise<FetchResponse>
    }
}
```

## API

### `JSBridge(libraryCode: String)`

Create a new `JSBridge` instance, with the supplied library source code.

The `libraryCode` should be a string of JavaScript that attaches one or more functions to the `window` object. These functions can then be called using the `call` method.

### `call(function: String) -> Promise<Void>`

Call a function without any arguments, ignoring the return value. The returned promise will settle once the function have completed running.

### `call<Result: Decodable>(function: String) -> Promise<Result>`

Call a function without any arguments. The returned promise will settle with the return value of the function.

### `call<A: Encodable>(function: String, withArg: A) -> Promise<Void>`

Call a function with a single argument, ignoring the return value. The returned promise will settle once the function have completed running.

### `call<Result: Decodable, A: Encodable>(function: String, withArg: A) -> Promise<Result>`

Call a function with a single argument. The returned promise will settle with the return value of the function.

### `call<A: Encodable, B: Encodable, ...>(function: String, withArgs: (A, B, ...)) -> Promise<Void>`

Call a function with multiple arguments, ignoring the return value. The returned promise will settle once the function have completed running.

### `call<Result: Decodable, A: Encodable, B: Encodable, ...>(function: String, withArgs: (A, B, ...)) -> Promise<Result>`

Call a function with multiple arguments. The returned promise will settle with the return value of the function.

## iOS

To be able to use JSBridge on iOS, you need to give JSBridge a hook to your view hierarchy. Otherwise the `WKWebView` will get suspended by the OS, and your Promises will never settle.

This is accomplished by using the `setGlobalUIHook` function before instantiating any `JSBridge` instances.

**App:**

```swift
// Can be called from anywhere, e.g. your AppDelegate
JSBridge.setGlobalUIHook(window: UIApplication.shared.windows.first)
```

**App Extension:**

```swift
// From within your root view controller
JSBridge.setGlobalUIHook(viewController: self)
```

## Hacking

The Xcode project is generated automatically from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). It's only checked in because Carthage needs it, do not edit it manually.

```sh
$ mint run yonaskolb/xcodegen
💾  Saved project to JSBridge.xcodeproj
```
