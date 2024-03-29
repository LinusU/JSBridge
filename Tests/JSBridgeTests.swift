import XCTest

import Foundation
import PromiseKit

import JSBridge

extension XCTestCase {
    func expectation(description: String, _ promiseFactory: () -> Promise<Void>) {
        let done = self.expectation(description: "Promise \(description) settled")

        firstly {
            promiseFactory()
        }.catch { err in
            XCTFail("Failed with error: \(err)")
        }.finally {
            done.fulfill()
        }
    }
}

class TestError: NSObject, LocalizedError {
    var errorDescription: String? { return "DF17904B" }
}

@available(iOS 11.0, macOS 10.13, *)
class BioPassTests: XCTestCase {
    func testCustomScheme() {
        let bridge = JSBridge(libraryCode: "window.readLocation = () => location.href")

        self.expectation(description: "readLocation") {
            firstly {
                bridge.call(function: "readLocation") as Promise<String>
            }.done { result in
                XCTAssertEqual(result, "bridge://localhost/")
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testSimpleInvocation() {
        let bridge = JSBridge(libraryCode: "window.test = () => 42")

        self.expectation(description: "test") {
            firstly {
                bridge.call(function: "test") as Promise<Int>
            }.done { result in
                XCTAssertEqual(result, 42)
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testInputParameters() {
        let bridge = JSBridge(libraryCode: "window.add = (a, b) => a + b")

        self.expectation(description: "add") {
            firstly {
                bridge.call(function: "add", withArgs: (1, 2)) as Promise<Int>
            }.done { result in
                XCTAssertEqual(result, 3)
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testUndefinedFunction() {
        let bridge = JSBridge(libraryCode: "window.firstName = () => true")

        self.expectation(description: "anotherName") {
            firstly {
                bridge.call(function: "anotherName") as Promise<Bool>
            }.done { _ in
                XCTFail("Missed expected error")
            }.recover { (err) throws -> Promise<Void> in
                guard let e = err as? JSError else { throw err }

                XCTAssertEqual(e.name, "ReferenceError")
                XCTAssertEqual(e.message, "Can't find variable: anotherName")

                return Promise.value(())
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testThrowError() {
        let bridge = JSBridge(libraryCode: "window.explode = () => { throw new Error('mJet3Bn35') }")

        self.expectation(description: "explode") {
            firstly {
                bridge.call(function: "explode") as Promise<Void>
            }.done { _ in
                XCTFail("Missed expected error")
            }.recover { (err) throws -> Promise<Void> in
                guard let e = err as? JSError else { throw err }

                XCTAssertEqual(e.name, "Error")
                XCTAssertEqual(e.message, "mJet3Bn35")

                return Promise.value(())
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testAsyncFunction() {
        let bridge = JSBridge(libraryCode: "window.sleep = () => new Promise(r => setTimeout(r, 40, 'ok'))")

        self.expectation(description: "sleep") {
            firstly {
                bridge.call(function: "sleep") as Promise<String>
            }.done { result in
                XCTAssertEqual(result, "ok")
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testLocalStorage() {
        let bridge = JSBridge(libraryCode: "window.write = (key, val) => localStorage.setItem(key, val)\nwindow.read = (key) => localStorage.getItem(key)")

        self.expectation(description: "write & read") {
            firstly {
                bridge.call(function: "write", withArgs: ("key", "value")) as Promise<Void>
            }.then { _ in
                bridge.call(function: "read", withArg: "key") as Promise<String?>
            }.done { result in
                XCTAssertEqual(result, "value")
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testCodableStruct() {
        struct Input: Codable {
            let name: String
            let age: Int
        }

        struct Output: Codable {
            let greeting: String
            let age: Int
        }

        let bridge = JSBridge(libraryCode: "window.fn = ({ name, age }) => ({ greeting: `Hello, ${name}!`, age })")

        self.expectation(description: "fn") {
            firstly {
                bridge.call(function: "fn", withArg: Input(name: "Steve", age: 56)) as Promise<Output>
            }.done { result in
                XCTAssertEqual(result.greeting, "Hello, Steve!")
                XCTAssertEqual(result.age, 56)
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testReadmeExample() {
        struct FetchResponse: Decodable {
            let status: Int
            let body: String
        }

        class Foobar {
            static internal let bridge = JSBridge(libraryCode: """
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
            """)

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

        self.expectation(description: "add") {
            firstly {
                Foobar.add(20, 22)
            }.done { result in
                XCTAssertEqual(result, 42)
            }
        }

        self.expectation(description: "greet") {
            firstly {
                Foobar.greet(name: "World")
            }.done { result in
                XCTAssertEqual(result, "Hello, World!")
            }
        }

        self.expectation(description: "fetch") {
            firstly {
                Foobar.fetch(url: URL(string: "data:text/plain,Hello,%20World!")!)
            }.done { result in
                XCTAssertEqual(result.status, 200)
                XCTAssertEqual(result.body, "Hello, World!")
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testCallingIntoSwift() {
        let bridge = JSBridge(libraryCode: "")

        bridge.register(namespace: "Swift")
        bridge.register(functionNamed: "Swift.four") { 4 }
        bridge.register(functionNamed: "Swift.addOne") { (i: Int) in i + 1 }
        bridge.register(functionNamed: "Swift.addTwo") { (i: Int) in Promise.value(i + 2) }
        bridge.register(functionNamed: "Swift.reject") { return Promise<Void>(error: TestError()) }
        bridge.register(functionNamed: "Swift.addAllArgs") { (a: Int, b: Int, c: Int, d: Int, e: Int, f: Int, g: Int) in a + b + c + d + e + f + g }

        self.expectation(description: "four") {
            firstly {
                bridge.call(function: "Swift.four") as Promise<Int>
            }.done { result in
                XCTAssertEqual(result, 4)
            }
        }

        self.expectation(description: "addOne") {
            firstly {
                bridge.call(function: "Swift.addOne", withArg: 5) as Promise<Int>
            }.done { result in
                XCTAssertEqual(result, 6)
            }
        }

        self.expectation(description: "addTwo") {
            firstly {
                bridge.call(function: "Swift.addTwo", withArg: 7) as Promise<Int>
            }.done { result in
                XCTAssertEqual(result, 9)
            }
        }

        self.expectation(description: "reject") {
            firstly {
                bridge.call(function: "Swift.reject") as Promise<Void>
            }.done { _ in
                XCTFail("Missed expected error")
            }.recover { (err) throws -> Promise<Void> in
                guard let e = err as? JSError else { throw err }

                XCTAssertEqual(e.name, "Error")
                XCTAssertEqual(e.message, "DF17904B")

                return Promise.value(())
            }
        }

        self.expectation(description: "addAllArgs") {
            firstly {
                bridge.call(function: "Swift.addAllArgs", withArgs: (1, 2, 3, 4, 5, 6, 7)) as Promise<Int>
            }.done { result in
                XCTAssertEqual(result, 28)
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testCustomOrigin() {
        let origin = URL(string: "https://example.com")!
        let bridge = JSBridge(libraryCode: "window.getOrigin = () => location.origin", customOrigin: origin)

        self.expectation(description: "getOrigin") {
            firstly {
                bridge.call(function: "getOrigin") as Promise<URL>
            }.done { result in
                XCTAssertEqual(result, origin)
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testRelativeFetch() {
        struct FetchResponse: Decodable {
            let status: Int
            let body: String
        }

        let bridge = JSBridge(libraryCode: "window.test = a => fetch(a).then(async r => ({ status: r.status, body: await r.text() }))")

        self.expectation(description: "fetchRoot") {
            firstly {
                bridge.call(function: "test", withArg: "/") as Promise<FetchResponse>
            }.done { result in
                XCTAssertEqual(result.status, 200)
                XCTAssertEqual(result.body, "<!DOCTYPE html>\n<html>\n<head></head>\n<body></body>\n</html>")
            }
        }

        self.expectation(description: "fetchTest") {
            firstly {
                bridge.call(function: "test", withArg: "/test") as Promise<FetchResponse>
            }.done { result in
                XCTAssertEqual(result.status, 404)
                XCTAssertEqual(result.body, "404 Not Found")
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testInitError() {
        let bridge = JSBridge(libraryCode: "throw new Error('g0krG9Jjj')")

        self.expectation(description: "focus") {
            firstly {
                bridge.call(function: "focus") as Promise<Void>
            }.done { _ in
                XCTFail("Missed expected error")
            }.recover { (err) throws -> Promise<Void> in
                guard let e = err as? JSError else { throw err }

                XCTAssertEqual(e.name, "Error")
                XCTAssertEqual(e.message, "g0krG9Jjj")

                return Promise.value(())
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testErrorCodes() {
        let bridge = JSBridge(libraryCode: "window.crash = () => { throw Object.assign(new Error('Test'), { code: 'E_TEST' }) }")

        self.expectation(description: "crash") {
            firstly {
                bridge.call(function: "crash") as Promise<Void>
            }.done { _ in
                XCTFail("Missed expected error")
            }.recover { (err) throws -> Promise<Void> in
                guard let e = err as? JSError else { throw err }

                XCTAssertEqual(e.name, "Error")
                XCTAssertEqual(e.message, "Test")
                XCTAssertEqual(e.code, "E_TEST")

                return Promise.value(())
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testErrorPropagation() {
        let bridge = JSBridge(libraryCode: "window.crash = () => { throw Object.assign(new Error('Test'), { code: 'E_TEST' }) }; window.jsTest = () => window.swiftTest()")

        bridge.register(functionNamed: "swiftTest") { () -> Promise<Void> in bridge.call(function: "crash") }

        self.expectation(description: "errorPropagation") {
            firstly {
                bridge.call(function: "jsTest") as Promise<Void>
            }.done { _ in
                XCTFail("Missed expected error")
            }.recover { (err) throws -> Promise<Void> in
                guard let e = err as? JSError else { throw err }

                XCTAssertEqual(e.name, "Error")
                XCTAssertEqual(e.message, "Test")
                XCTAssertEqual(e.code, "E_TEST")

                return Promise.value(())
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testAnonymousFunctions() {
        let bridge = JSBridge(libraryCode: "")

        self.expectation(description: "anonymousFunctions 0") {
            firstly {
                bridge.call(function: "function test () { return 'test0' }") as Promise<String>
            }.done {
                XCTAssertEqual($0, "test0")
            }
        }

        self.expectation(description: "anonymousFunctions 1") {
            firstly {
                bridge.call(function: "function () { return 'test1' }") as Promise<String>
            }.done {
                XCTAssertEqual($0, "test1")
            }
        }

        self.expectation(description: "anonymousFunctions 2") {
            firstly {
                bridge.call(function: "(function test () { return 'test2' })") as Promise<String>
            }.done {
                XCTAssertEqual($0, "test2")
            }
        }

        self.expectation(description: "anonymousFunctions 3") {
            firstly {
                bridge.call(function: "(function () { return 'test3' })") as Promise<String>
            }.done {
                XCTAssertEqual($0, "test3")
            }
        }

        self.expectation(description: "anonymousFunctions 4") {
            firstly {
                bridge.call(function: "() => 'test4'") as Promise<String>
            }.done {
                XCTAssertEqual($0, "test4")
            }
        }

        self.expectation(description: "anonymousFunctions 5") {
            firstly {
                bridge.call(function: "() => { return 'test5' }") as Promise<String>
            }.done {
                XCTAssertEqual($0, "test5")
            }
        }

        self.expectation(description: "anonymousFunctions 6") {
            firstly {
                bridge.call(function: "_ => 'test6'") as Promise<String>
            }.done {
                XCTAssertEqual($0, "test6")
            }
        }

        self.expectation(description: "anonymousFunctions 7") {
            firstly {
                bridge.call(function: "_ => { return 'test7' }") as Promise<String>
            }.done {
                XCTAssertEqual($0, "test7")
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testAbortedError() {
        let bridge = JSBridge(libraryCode: """
            window.interruptedLongRunningTask = () => {
                setTimeout(() => (window.location.href = '/'), 120)
                return new Promise(resolve => setTimeout(resolve, 300))
            }
        """)

        self.expectation(description: "interruptedLongRunningTask") {
            firstly {
                bridge.call(function: "interruptedLongRunningTask") as Promise<Void>
            }.done { _ in
                XCTFail("Missed expected error")
            }.recover { (err) throws -> Promise<Void> in
                guard err is AbortedError else { throw err }
                return Promise.value(())
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testIFrameNotAborting() {
        let bridge = JSBridge(libraryCode: """
            window.longRunningTask = () => {
                let iframe

                setTimeout(() => {
                    iframe = document.createElement('iframe')
                    iframe.src = '/1'
                    document.body.appendChild(iframe)
                }, 100)

                setTimeout(() => {
                    iframe.src = '/2'
                }, 200)

                return new Promise(resolve => setTimeout(resolve, 300))
            }
        """)

        self.expectation(description: "longRunningTask") {
            bridge.call(function: "longRunningTask")
        }

        self.waitForExpectations(timeout: 2)
    }

    func testThrowNull() {
        let bridge = JSBridge(libraryCode: "window.throwNull = () => { throw null }")

        self.expectation(description: "throwNull") {
            firstly {
                bridge.call(function: "throwNull") as Promise<Void>
            }.done { _ in
                XCTFail("Missed expected error")
            }.recover { (err) throws -> Promise<Void> in
                guard let e = err as? JSError else { throw err }

                XCTAssertEqual(e.name, "Error")
                XCTAssertEqual(e.message, "Unknown error")
                XCTAssertEqual(e.stack, "<unknown>")
                XCTAssertEqual(e.line, 0)
                XCTAssertEqual(e.column, 0)
                XCTAssertEqual(e.code, nil)

                return Promise.value(())
            }
        }

        self.waitForExpectations(timeout: 2)
    }

    func testReturnBuiltinConstructor() {
        let bridge = JSBridge(libraryCode: "window.giveEvent = () => Event")

        self.expectation(description: "giveEvent") {
            bridge.call(function: "giveEvent") as Promise<Void>
        }

        self.waitForExpectations(timeout: 2)
    }
}
