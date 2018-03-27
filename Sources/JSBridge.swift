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

    internal func decodeResult<Result: Decodable>(_ jsonString: String) -> Promise<Result> {
        return Promise<Result> { seal in
            do {
                let data = ("[" + jsonString + "]").data(using: .utf8)!
                let result = try self.decoder.decode([Result].self, from: data)

                seal.fulfill(result[0])
            } catch {
                seal.reject(error)
            }
        }
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
        }.then { stringified in
            self.decodeResult(stringified) as Promise<Result>
        }
    }

    public func call(function: String) -> Promise<Void> {
        return call(function: function, withStringifiedArgs: "")
    }

    public func call<A: Encodable>(function: String, withArg arg: A) -> Promise<Void> {
        let a = try! String(data: self.encoder.encode([arg]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a)")
    }

    public func call<A: Encodable, B: Encodable>(function: String, withArgs args: (A, B)) -> Promise<Void> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b)")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable>(function: String, withArgs args: (A, B, C)) -> Promise<Void> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c)")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable, D: Encodable>(function: String, withArgs args: (A, B, C, D)) -> Promise<Void> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        let d = try! String(data: self.encoder.encode([args.3]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c),\(d)")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable>(function: String, withArgs args: (A, B, C, D, E)) -> Promise<Void> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        let d = try! String(data: self.encoder.encode([args.3]), encoding: .utf8)!
        let e = try! String(data: self.encoder.encode([args.4]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c),\(d),\(e)")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable>(function: String, withArgs args: (A, B, C, D, E, F)) -> Promise<Void> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        let d = try! String(data: self.encoder.encode([args.3]), encoding: .utf8)!
        let e = try! String(data: self.encoder.encode([args.4]), encoding: .utf8)!
        let f = try! String(data: self.encoder.encode([args.5]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c),\(d),\(e),\(f)")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable, G: Encodable>(function: String, withArgs args: (A, B, C, D, E, F, G)) -> Promise<Void> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        let d = try! String(data: self.encoder.encode([args.3]), encoding: .utf8)!
        let e = try! String(data: self.encoder.encode([args.4]), encoding: .utf8)!
        let f = try! String(data: self.encoder.encode([args.5]), encoding: .utf8)!
        let g = try! String(data: self.encoder.encode([args.6]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c),\(d),\(e),\(f),\(g)")
    }

    public func call<A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable, G: Encodable, H: Encodable>(function: String, withArgs args: (A, B, C, D, E, F, G, H)) -> Promise<Void> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        let d = try! String(data: self.encoder.encode([args.3]), encoding: .utf8)!
        let e = try! String(data: self.encoder.encode([args.4]), encoding: .utf8)!
        let f = try! String(data: self.encoder.encode([args.5]), encoding: .utf8)!
        let g = try! String(data: self.encoder.encode([args.6]), encoding: .utf8)!
        let h = try! String(data: self.encoder.encode([args.7]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c),\(d),\(e),\(f),\(g),\(h)")
    }

    public func call<Result: Decodable>(function: String) -> Promise<Result> {
        return call(function: function, withStringifiedArgs: "")
    }

    public func call<Result: Decodable, A: Encodable>(function: String, withArg arg: A) -> Promise<Result> {
        let a = try! String(data: self.encoder.encode([arg]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a)")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable>(function: String, withArgs args: (A, B)) -> Promise<Result> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b)")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable>(function: String, withArgs args: (A, B, C)) -> Promise<Result> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c)")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable, D: Encodable>(function: String, withArgs args: (A, B, C, D)) -> Promise<Result> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        let d = try! String(data: self.encoder.encode([args.3]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c),\(d)")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable>(function: String, withArgs args: (A, B, C, D, E)) -> Promise<Result> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        let d = try! String(data: self.encoder.encode([args.3]), encoding: .utf8)!
        let e = try! String(data: self.encoder.encode([args.4]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c),\(d),\(e)")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable>(function: String, withArgs args: (A, B, C, D, E, F)) -> Promise<Result> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        let d = try! String(data: self.encoder.encode([args.3]), encoding: .utf8)!
        let e = try! String(data: self.encoder.encode([args.4]), encoding: .utf8)!
        let f = try! String(data: self.encoder.encode([args.5]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c),\(d),\(e),\(f)")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable, G: Encodable>(function: String, withArgs args: (A, B, C, D, E, F, G)) -> Promise<Result> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        let d = try! String(data: self.encoder.encode([args.3]), encoding: .utf8)!
        let e = try! String(data: self.encoder.encode([args.4]), encoding: .utf8)!
        let f = try! String(data: self.encoder.encode([args.5]), encoding: .utf8)!
        let g = try! String(data: self.encoder.encode([args.6]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c),\(d),\(e),\(f),\(g)")
    }

    public func call<Result: Decodable, A: Encodable, B: Encodable, C: Encodable, D: Encodable, E: Encodable, F: Encodable, G: Encodable, H: Encodable>(function: String, withArgs args: (A, B, C, D, E, F, G, H)) -> Promise<Result> {
        let a = try! String(data: self.encoder.encode([args.0]), encoding: .utf8)!
        let b = try! String(data: self.encoder.encode([args.1]), encoding: .utf8)!
        let c = try! String(data: self.encoder.encode([args.2]), encoding: .utf8)!
        let d = try! String(data: self.encoder.encode([args.3]), encoding: .utf8)!
        let e = try! String(data: self.encoder.encode([args.4]), encoding: .utf8)!
        let f = try! String(data: self.encoder.encode([args.5]), encoding: .utf8)!
        let g = try! String(data: self.encoder.encode([args.6]), encoding: .utf8)!
        let h = try! String(data: self.encoder.encode([args.7]), encoding: .utf8)!
        return call(function: function, withStringifiedArgs: "\(a),\(b),\(c),\(d),\(e),\(f),\(g),\(h)")
    }
}
