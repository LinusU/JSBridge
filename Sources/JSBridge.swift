import Foundation
import JavaScriptCore
import WebKit

#if os(iOS)
import UIKit
#endif

import PromiseKit

fileprivate let internalLibrary = """
(function () {
    function serializeError (value) {
        return (typeof value !== 'object' || value === null) ? {} : {
            name: String(value.name),
            message: String(value.message),
            stack: String(value.stack),
            line: Number(value.line),
            column: Number(value.column)
        }
    }

    window.__JSBridge__call__ = function (id, fnFactory, ...args) {
        Promise.resolve().then(() => {
            return fnFactory()(...args.map(wrap => wrap[0]))
        }).then((result) => {
            window.webkit.messageHandlers.scriptHandler.postMessage({ id, type: 'resolve', result: JSON.stringify(result === undefined ? null : result) })
        }, (err) => {
            window.webkit.messageHandlers.scriptHandler.postMessage({ id, type: 'reject', error: serializeError(err) })
        })
    }
}())
"""

@available(iOS 11.0, macOS 10.13, *)
internal class JSBridgeSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let html = "<!DOCTYPE html>\n<html>\n<head></head>\n<body></body>\n</html>".data(using: .utf8)!
        let response = URLResponse(url: urlSchemeTask.request.url!, mimeType: "text/html", expectedContentLength: html.count, textEncodingName: "utf-8")

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(html)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

public struct JSError: Error {
    let name: String
    let message: String
    let stack: String

    let line: Int
    let column: Int
}

fileprivate func createDeferred() -> (Guarantee<Void>, (()) -> Void) {
    var resolver: ((()) -> Void)? = nil
    let promise = Guarantee { seal in resolver = seal }

    return (promise, resolver!)
}

@available(iOS 11.0, macOS 10.13, *)
fileprivate func defaultWebViewConfig() -> WKWebViewConfiguration {
    let config = WKWebViewConfiguration()
    config.setURLSchemeHandler(JSBridgeSchemeHandler(), forURLScheme: "bridge")
    return config
}

@available(iOS 11.0, macOS 10.13, *)
open class JSBridge: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    internal let encoder = JSONEncoder()
    internal let decoder = JSONDecoder()
    internal let queue = DispatchQueue(label: "org.linusu.JSBridge")
    internal let webView = WKWebView.init(frame: .zero, configuration: defaultWebViewConfig())

    internal let ready: Guarantee<Void>
    internal let readyResolver: (()) -> Void

    internal var currentIndex = 0
    internal var handlers = [Int: Resolver<String>]()

    public init (libraryCode: String) {
        (ready, readyResolver) = createDeferred()

        super.init()

        webView.navigationDelegate = self
        webView.configuration.userContentController.add(self, name: "scriptHandler")
        webView.load(URLRequest(url: URL(string: "bridge://localhost/")!))

        #if os(iOS)
            if let window = UIApplication.shared.windows.first {
                window.addSubview(webView)
            }
        #endif

        ready.done { _ in
            self.webView.evaluateJavaScript(internalLibrary)
            self.webView.evaluateJavaScript(libraryCode)
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.readyResolver(())
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? Dictionary<String, AnyObject> else { return }
        guard let id = dict["id"] as? Int else { return }
        guard let handler = handlers[id] else { return }

        if let result = dict["result"] as? String {
            return handler.fulfill(result)
        }

        if let error = dict["error"] as? Dictionary<String, AnyObject> {
            return handler.reject(JSError(
                name: (error["name"] as? String) ?? "Error",
                message: (error["message"] as? String) ?? "Unknown error",
                stack: (error["stack"] as? String) ?? "<unknown>",
                line: (error["line"] as? Int) ?? 0,
                column: (error["column"] as? Int) ?? 0
            ))
        }
    }

    internal func rawCall(function: String, args: String) -> Promise<String> {
        return self.ready.then { _ in
            Promise<String> { seal in
                let id = self.currentIndex
                self.currentIndex += 1
                self.handlers[id] = seal

                self.webView.evaluateJavaScript("window.__JSBridge__call__(\(id), () => \(function), ...[\(args)])")
            }
        }
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
            self.rawCall(function: function, args: args)
        }.then { _ in
            Promise.value(()) as Promise<Void>
        }
    }

    internal func call<Result: Decodable>(function: String, withStringifiedArgs args: String) -> Promise<Result> {
        return firstly {
            self.rawCall(function: function, args: args)
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
