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

    let nextId = 0
    let callbacks = {}

    window.__JSBridge__resolve__ = function (id, value) {
        callbacks[id].resolve(value)
        delete callbacks[id]
    }

    window.__JSBridge__reject__ = function (id, error) {
        callbacks[id].reject(error)
        delete callbacks[id]
    }

    window.__JSBridge__receive__ = function (id, fnFactory, ...args) {
        Promise.resolve().then(() => {
            return fnFactory()(...args)
        }).then((result) => {
            window.webkit.messageHandlers.scriptHandler.postMessage({ id, result: JSON.stringify(result === undefined ? null : result) })
        }, (err) => {
            window.webkit.messageHandlers.scriptHandler.postMessage({ id, error: serializeError(err) })
        })
    }

    window.__JSBridge__send__ = function (method, ...args) {
        return new Promise((resolve, reject) => {
            const id = nextId++
            callbacks[id] = { resolve, reject }
            window.webkit.messageHandlers.scriptHandler.postMessage({ id, method, params: args.map(x => JSON.stringify(x)) })
        })
    }
}())
"""

@available(iOS 11.0, macOS 10.13, *)
fileprivate class SchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let html = "<!DOCTYPE html>\n<html>\n<head></head>\n<body></body>\n</html>".data(using: .utf8)!
        let response = URLResponse(url: urlSchemeTask.request.url!, mimeType: "text/html", expectedContentLength: html.count, textEncodingName: "utf-8")

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(html)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

fileprivate class ResolveWhenNavigatedDelegate: NSObject, WKNavigationDelegate {
    fileprivate let (ready, readyResolver) = Promise<Void>.pending()

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.readyResolver.fulfill(())
    }
}

@available(iOS 11.0, macOS 10.13, *)
fileprivate func defaultWebViewConfig() -> WKWebViewConfiguration {
    let config = WKWebViewConfiguration()
    config.setURLSchemeHandler(SchemeHandler(), forURLScheme: "bridge")
    return config
}

@available(iOS 11.0, macOS 10.13, *)
internal class Context: NSObject, WKScriptMessageHandler {
    private let webView: WKWebView

    private var currentIndex = 0
    private var handlers = [Int: Resolver<String>]()

    private var functions = [String: ([String]) throws -> Promise<String>]()

    public static func asyncInit(libraryCode: String, customOrigin: URL? = nil) -> Promise<Context> {
        let webView = WKWebView.init(frame: .zero, configuration: defaultWebViewConfig())
        var delegate: ResolveWhenNavigatedDelegate? = ResolveWhenNavigatedDelegate()

        webView.navigationDelegate = delegate

        if let origin = customOrigin {
            let html = "<!DOCTYPE html>\n<html>\n<head></head>\n<body></body>\n</html>".data(using: .utf8)!
            webView.load(html, mimeType: "text/html", characterEncodingName: "utf8", baseURL: origin)
        } else {
            webView.load(URLRequest(url: URL(string: "bridge://localhost/")!))
        }

        #if os(iOS)
        switch globalUIHook {
            case .none: break
            case .view(let view): view.addSubview(webView)
            case .viewController(let viewController): viewController.view.addSubview(webView)
            case .window(let window): window.addSubview(webView)
        }
        #endif

        return firstly {
            delegate!.ready
        }.done { _ in
            delegate = nil
        }.then { _ in
            return Promise<Void> { seal in
                webView.evaluateJavaScript(internalLibrary) { _, err in seal.resolve((), err) }
            }
        }.then { _ in
            return Promise<Void> { seal in
                webView.evaluateJavaScript("(function () {\(libraryCode)}())") { _, err in seal.resolve((), err) }
            }
        }.map { _ in
            return Context(webView)
        }
    }

    private init(_ webView: WKWebView) {
        self.webView = webView

        super.init()

        webView.configuration.userContentController.add(self, name: "scriptHandler")
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? Dictionary<String, AnyObject> else { return }
        guard let id = dict["id"] as? Int else { return }

        if let result = dict["result"] as? String {
            guard let handler = handlers[id] else { return }

            return handler.fulfill(result)
        }

        if let error = dict["error"] as? Dictionary<String, AnyObject> {
            guard let handler = handlers[id] else { return }

            return handler.reject(JSError(
                name: (error["name"] as? String) ?? "Error",
                message: (error["message"] as? String) ?? "Unknown error",
                stack: (error["stack"] as? String) ?? "<unknown>",
                line: (error["line"] as? Int) ?? 0,
                column: (error["column"] as? Int) ?? 0
            ))
        }

        if let method = dict["method"] as? String {
            guard let fn = functions[method] else { return }
            let params = dict["params"] as? [String] ?? []

            firstly {
                try fn(params)
            }.done {
                self.webView.evaluateJavaScript("window.__JSBridge__resolve__(\(id), \($0))")
            }.catch {
                self.webView.evaluateJavaScript("window.__JSBridge__reject__(\(id), new Error('\($0.localizedDescription)'))")
            }
        }
    }

    internal func rawCall(function: String, args: String) -> Promise<String> {
        return Promise<String> { seal in
            let id = self.currentIndex
            self.currentIndex += 1
            self.handlers[id] = seal

            self.webView.evaluateJavaScript("window.__JSBridge__receive__(\(id), () => \(function), ...[\(args)])")
        }
    }

    internal func register(namespace: String) {
        self.webView.evaluateJavaScript("window.\(namespace) = {}")
    }

    internal func register(functionNamed name: String, _ fn: @escaping ([String]) throws -> Promise<String>) {
        self.functions[name] = fn
        self.webView.evaluateJavaScript("window.\(name) = (...args) => __JSBridge__send__('\(name)', ...args)")
    }
}
