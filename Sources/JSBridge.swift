import WebKit

#if os(iOS)
import UIKit
#endif

import PromiseKit

public struct JSError: Error {
    let name: String
    let message: String
    let stack: String

    let line: Int
    let column: Int
}

#if os(iOS)
enum GlobalUIHook {
    case none
    case view(UIView)
    case viewController(UIViewController)
    case window(UIWindow)
}

internal var globalUIHook: GlobalUIHook = .none
#endif

@available(iOS 11.0, macOS 10.13, *)
open class JSBridge {
    public let encoder = JSONEncoder()
    public let decoder = JSONDecoder()

    internal let context: Promise<Context>

    #if os(iOS)
    public static func setGlobalUIHook(view: UIView) {
        globalUIHook = .view(view)
    }

    public static func setGlobalUIHook(viewController: UIViewController) {
        globalUIHook = .viewController(viewController)
    }

    public static func setGlobalUIHook(window: UIWindow) {
        globalUIHook = .window(window)
    }
    #endif

    public init(libraryCode: String) {
        self.context = Context.asyncInit(libraryCode: libraryCode)
    }

    private func encode<T: Encodable>(_ value: T) -> String {
        return String(data: try! self.encoder.encode([value]).dropFirst().dropLast(), encoding: .utf8)!
    }

    private func decode<T: Decodable>(_ jsonString: String) throws -> T {
        let data = ("[" + jsonString + "]").data(using: .utf8)!
        return (try self.decoder.decode([T].self, from: data))[0]
    }

    internal func call(function: String, withStringifiedArgs args: String) -> Promise<Void> {
        return firstly {
            self.context
        }.then { context in
            context.rawCall(function: function, args: args)
        }.then { _ in
            Promise.value(()) as Promise<Void>
        }
    }

    internal func call<Result: Decodable>(function: String, withStringifiedArgs args: String) -> Promise<Result> {
        return firstly {
            self.context
        }.then { context in
            context.rawCall(function: function, args: args)
        }.map { stringified in
            try self.decode(stringified)
        }
    }

    public func call(function: String) -> Promise<Void> {
        return call(function: function, withStringifiedArgs: "")
    }

    public func call<A: Encodable>(function: String, withArg arg: A) -> Promise<Void> {
        return call(function: function, withStringifiedArgs: "\(self.encode(arg))")
    }

    public func call<A: Encodable, B: Encodable>(function: String, withArgs args: (A, B)) -> Promise<Void> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1))")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable>(function: String, withArgs args: (A, B, C)) -> Promise<Void> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2))")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable, D: Encodable>(function: String, withArgs args: (A, B, C, D)) -> Promise<Void> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2)),\(self.encode(args.3))")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable>(function: String, withArgs args: (A, B, C, D, E)) -> Promise<Void> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2)),\(self.encode(args.3)),\(self.encode(args.4))")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable>(function: String, withArgs args: (A, B, C, D, E, F)) -> Promise<Void> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2)),\(self.encode(args.3)),\(self.encode(args.4)),\(self.encode(args.5))")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable, G: Encodable>(function: String, withArgs args: (A, B, C, D, E, F, G)) -> Promise<Void> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2)),\(self.encode(args.3)),\(self.encode(args.4)),\(self.encode(args.5)),\(self.encode(args.6))")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable, G: Encodable, H: Encodable>(function: String, withArgs args: (A, B, C, D, E, F, G, H)) -> Promise<Void> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2)),\(self.encode(args.3)),\(self.encode(args.4)),\(self.encode(args.5)),\(self.encode(args.6)),\(self.encode(args.7))")
    }

    public func call<Result: Decodable>(function: String) -> Promise<Result> {
        return call(function: function, withStringifiedArgs: "")
    }

    public func call<Result: Decodable, A: Encodable>(function: String, withArg arg: A) -> Promise<Result> {
        return call(function: function, withStringifiedArgs: "\(self.encode(arg))")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable>(function: String, withArgs args: (A, B)) -> Promise<Result> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1))")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable>(function: String, withArgs args: (A, B, C)) -> Promise<Result> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2))")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable, D: Encodable>(function: String, withArgs args: (A, B, C, D)) -> Promise<Result> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2)),\(self.encode(args.3))")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable>(function: String, withArgs args: (A, B, C, D, E)) -> Promise<Result> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2)),\(self.encode(args.3)),\(self.encode(args.4))")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable>(function: String, withArgs args: (A, B, C, D, E, F)) -> Promise<Result> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2)),\(self.encode(args.3)),\(self.encode(args.4)),\(self.encode(args.5))")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable, G: Encodable>(function: String, withArgs args: (A, B, C, D, E, F, G)) -> Promise<Result> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2)),\(self.encode(args.3)),\(self.encode(args.4)),\(self.encode(args.5)),\(self.encode(args.6))")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable, G: Encodable, H: Encodable>(function: String, withArgs args: (A, B, C, D, E, F, G, H)) -> Promise<Result> {
        return call(function: function, withStringifiedArgs: "\(self.encode(args.0)),\(self.encode(args.1)),\(self.encode(args.2)),\(self.encode(args.3)),\(self.encode(args.4)),\(self.encode(args.5)),\(self.encode(args.6)),\(self.encode(args.7))")
    }

    private func rawRegister(namespace: String) {
        let _ = self.context.done { $0.register(namespace: namespace) }
    }

    private func rawRegister(functionNamed name: String, _ fn: @escaping ([String]) throws -> Promise<String>) {
        let _ = self.context.done { $0.register(functionNamed: name, fn) }
    }

    public func register(namespace: String) {
        rawRegister(namespace: namespace)
    }

    public func register(functionNamed name: String, _ fn: @escaping () throws -> Void) {
        rawRegister(functionNamed: name) { _ in try fn(); return Promise.value("null") }
    }

    public func register<A: Decodable>(functionNamed name: String, _ fn: @escaping (A) throws -> Void) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0])); return Promise.value("null") }
    }

    public func register<A: Decodable, B: Decodable>(functionNamed name: String, _ fn: @escaping (A, B) throws -> Void) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1])); return Promise.value("null") }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C) throws -> Void) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2])); return Promise.value("null") }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable, D: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D) throws -> Void) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3])); return Promise.value("null") }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E) throws -> Void) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4])); return Promise.value("null") }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F) throws -> Void) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5])); return Promise.value("null") }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable, G: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F, G) throws -> Void) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5]), self.decode($0[6])); return Promise.value("null") }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable, G: Decodable, H: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F, G, H) throws -> Void) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5]), self.decode($0[6]), self.decode($0[7])); return Promise.value("null") }
    }

    public func register(functionNamed name: String, _ fn: @escaping () throws -> Promise<Void>) {
        rawRegister(functionNamed: name) { _ in try fn().map { "null" } }
    }

    public func register<A: Decodable>(functionNamed name: String, _ fn: @escaping (A) throws -> Promise<Void>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0])).map { "null" } }
    }

    public func register<A: Decodable, B: Decodable>(functionNamed name: String, _ fn: @escaping (A, B) throws -> Promise<Void>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1])).map { "null" } }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C) throws -> Promise<Void>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2])).map { "null" } }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable, D: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D) throws -> Promise<Void>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3])).map { "null" } }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E) throws -> Promise<Void>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4])).map { "null" } }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F) throws -> Promise<Void>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5])).map { "null" } }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable, G: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F, G) throws -> Promise<Void>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5]), self.decode($0[6])).map { "null" } }
    }

    public func register<A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable, G: Decodable, H: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F, G, H) throws -> Promise<Void>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5]), self.decode($0[6]), self.decode($0[7])).map { "null" } }
    }

    public func register<Return: Encodable>(functionNamed name: String, _ fn: @escaping () throws -> Return) {
        rawRegister(functionNamed: name) { _ in Promise.value(self.encode(try fn())) }
    }

    public func register<Return: Encodable, A: Decodable>(functionNamed name: String, _ fn: @escaping (A) throws -> Return) {
        rawRegister(functionNamed: name) { Promise.value(self.encode(try fn(self.decode($0[0])))) }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable>(functionNamed name: String, _ fn: @escaping (A, B) throws -> Return) {
        rawRegister(functionNamed: name) { Promise.value(self.encode(try fn(self.decode($0[0]), self.decode($0[1])))) }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C) throws -> Return) {
        rawRegister(functionNamed: name) { Promise.value(self.encode(try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2])))) }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable, D: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D) throws -> Return) {
        rawRegister(functionNamed: name) { Promise.value(self.encode(try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3])))) }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E) throws -> Return) {
        rawRegister(functionNamed: name) { Promise.value(self.encode(try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4])))) }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F) throws -> Return) {
        rawRegister(functionNamed: name) { Promise.value(self.encode(try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5])))) }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable, G: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F, G) throws -> Return) {
        rawRegister(functionNamed: name) { Promise.value(self.encode(try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5]), self.decode($0[6])))) }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable, G: Decodable, H: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F, G, H) throws -> Return) {
        rawRegister(functionNamed: name) { Promise.value(self.encode(try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5]), self.decode($0[6]), self.decode($0[7])))) }
    }

    public func register<Return: Encodable>(functionNamed name: String, _ fn: @escaping () throws -> Promise<Return>) {
        rawRegister(functionNamed: name) { _ in try fn().map { self.encode($0) } }
    }

    public func register<Return: Encodable, A: Decodable>(functionNamed name: String, _ fn: @escaping (A) throws -> Promise<Return>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0])).map { self.encode($0) } }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable>(functionNamed name: String, _ fn: @escaping (A, B) throws -> Promise<Return>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1])).map { self.encode($0) } }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C) throws -> Promise<Return>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2])).map { self.encode($0) } }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable, D: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D) throws -> Promise<Return>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3])).map { self.encode($0) } }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E) throws -> Promise<Return>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4])).map { self.encode($0) } }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F) throws -> Promise<Return>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5])).map { self.encode($0) } }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable, G: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F, G) throws -> Promise<Return>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5]), self.decode($0[6])).map { self.encode($0) } }
    }

    public func register<Return: Encodable, A: Decodable, B: Decodable, C: Decodable, D: Decodable, E: Decodable, F: Decodable, G: Decodable, H: Decodable>(functionNamed name: String, _ fn: @escaping (A, B, C, D, E, F, G, H) throws -> Promise<Return>) {
        rawRegister(functionNamed: name) { try fn(self.decode($0[0]), self.decode($0[1]), self.decode($0[2]), self.decode($0[3]), self.decode($0[4]), self.decode($0[5]), self.decode($0[6]), self.decode($0[7])).map { self.encode($0) } }
    }
}
