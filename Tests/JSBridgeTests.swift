import XCTest

import Foundation
import PromiseKit

@testable import JSBridge

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
        let bridge = JSBridge(libraryCode: "window.readLocation = () => window.location.href")

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
        let bridge = JSBridge(libraryCode: "window.explode = () => { throw new Error('123xyz') }")

        self.expectation(description: "explode") {
            firstly {
                bridge.call(function: "explode") as Promise<Void>
            }.done { _ in
                XCTFail("Missed expected error")
            }.recover { (err) throws -> Promise<Void> in
                guard let e = err as? JSError else { throw err }

                XCTAssertEqual(e.name, "Error")
                XCTAssertEqual(e.message, "123xyz")

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
        let bridge = JSBridge(libraryCode: "window.write = (key, val) => window.localStorage.setItem(key, val)\nwindow.read = (key) => window.localStorage.getItem(key)")

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
                // Yes, I know it's bad to call live servers in unit tests, I'll fix this soon™
                Foobar.fetch(url: URL(string: "https://server.test-cors.org/server?enable=true")!)
            }.done { result in
                XCTAssertEqual(result.status, 200)
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
        bridge.register(functionNamed: "Swift.addAllArgs") { (a: Int, b: Int, c: Int, d: Int, e: Int, f: Int, g: Int, h: Int) in a + b + c + d + e + f + g + h }

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
                bridge.call(function: "Swift.addAllArgs", withArgs: (1, 2, 3, 4, 5, 6, 7, 8)) as Promise<Int>
            }.done { result in
                XCTAssertEqual(result, 36)
            }
        }

        self.waitForExpectations(timeout: 2)
    }
}
