import WebKit

#if os(iOS)
import UIKit
#endif

import PromiseKit

fileprivate extension JSError {
    init(fromDictionary error: Dictionary<String, AnyObject>) {
        self.init(
            name: (error["name"] as? String) ?? "Error",
            message: (error["message"] as? String) ?? "Unknown error",
            stack: (error["stack"] as? String) ?? "<unknown>",
            line: (error["line"] as? Int) ?? 0,
            column: (error["column"] as? Int) ?? 0,
            code: (error["code"] as? String)
        )
    }
}

fileprivate let defaultOrigin = URL(string: "bridge://localhost/")!
fileprivate let html = "<!DOCTYPE html>\n<html>\n<head></head>\n<body></body>\n</html>".data(using: .utf8)!
fileprivate let notFound = "404 Not Found".data(using: .utf8)!

fileprivate let internalLibrary = """
(function () {
    function serializeError (value) {
        return (typeof value !== 'object' || value === null) ? {} : {
            name: String(value.name),
            message: String(value.message),
            stack: String(value.stack),
            line: Number(value.line),
            column: Number(value.column),
            code: value.code ? String(value.code) : null
        }
    }

    let nextId = 1
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
            webkit.messageHandlers.scriptHandler.postMessage({ id, result: JSON.stringify(result === undefined ? null : result) })
        }, (err) => {
            webkit.messageHandlers.scriptHandler.postMessage({ id, error: serializeError(err) })
        })
    }

    window.__JSBridge__send__ = function (method, ...args) {
        return new Promise((resolve, reject) => {
            const id = nextId++
            callbacks[id] = { resolve, reject }
            webkit.messageHandlers.scriptHandler.postMessage({ id, method, params: args.map(x => JSON.stringify(x)) })
        })
    }

    window.__JSBridge__ready__ = function (success, err) {
        if (success) {
            webkit.messageHandlers.scriptHandler.postMessage({ id: 0, result: 'null' })
        } else {
            webkit.messageHandlers.scriptHandler.postMessage({ id: 0, error: serializeError(err) })
        }
    }
}())
"""

@available(iOS 11.0, macOS 10.13, *)
fileprivate class BridgeSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let url = urlSchemeTask.request.url!

        if url.path == "/" {
            urlSchemeTask.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [
                "Content-Type": "text/html; charset=utf-8",
                "Content-Length": String(html.count),
            ])!)
            urlSchemeTask.didReceive(html)
        } else {
            urlSchemeTask.didReceive(HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: [
                "Content-Type": "text/plain; charset=utf-8",
                "Content-Length": String(notFound.count),
            ])!)
            urlSchemeTask.didReceive(notFound)
        }

        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

@available(iOS 11.0, macOS 10.13, *)
fileprivate func buildWebViewConfig(libraryCode: String, incognito: Bool) -> WKWebViewConfiguration {
    let source = "\(internalLibrary);try{(function () {\(libraryCode)}());__JSBridge__ready__(true)} catch (err) {__JSBridge__ready__(false, err)}"
    let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    let controller = WKUserContentController()
    let configuration = WKWebViewConfiguration()

    controller.addUserScript(script)
    configuration.userContentController = controller

    configuration.setURLSchemeHandler(BridgeSchemeHandler(), forURLScheme: "bridge")

    if incognito {
        configuration.websiteDataStore = .nonPersistent()
    }

    return configuration
}

@available(iOS 11.0, macOS 10.13, *)
internal class Context: NSObject, WKScriptMessageHandler {
    private let ready: Promise<Void>

    private var nextIdentifier = 1
    private var handlers = [Int: Resolver<String>]()

    private var functions = [String: ([String]) throws -> Promise<String>]()

    private static var errorEncoder = JSONEncoder()

    internal let webView: WKWebView

    init(libraryCode: String, customOrigin: URL?, incognito: Bool) {
        let (readyPromise, readyResolver) = Promise<String>.pending()

        self.webView = WKWebView.init(frame: .zero, configuration: buildWebViewConfig(libraryCode: libraryCode, incognito: incognito))
        self.ready = readyPromise.map { _ in () }
        self.handlers[0] = readyResolver

        super.init()

        webView.configuration.userContentController.add(self, name: "scriptHandler")
        webView.load(html, mimeType: "text/html", characterEncodingName: "utf8", baseURL: customOrigin ?? defaultOrigin)
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? Dictionary<String, AnyObject> else { return }
        guard let id = dict["id"] as? Int else { return }

        if let result = dict["result"] as? String {
            guard let handler = handlers.removeValue(forKey: id) else { return }

            return handler.fulfill(result)
        }

        if let error = dict["error"] as? Dictionary<String, AnyObject> {
            guard let handler = handlers.removeValue(forKey: id) else { return }

            return handler.reject(JSError(fromDictionary: error))
        }

        if let method = dict["method"] as? String {
            guard let fn = functions[method] else { return }
            let params = dict["params"] as? [String] ?? []

            firstly {
                try fn(params)
            }.done {
                self.webView.evaluateJavaScript("__JSBridge__resolve__(\(id), \($0))")
            }.catch {
                if let error = $0 as? JSError, let encoded = try? Context.errorEncoder.encode(error), let props = String(data: encoded, encoding: .utf8) {
                    self.webView.evaluateJavaScript("__JSBridge__reject__(\(id), Object.assign(new Error(''), \(props)))")
                } else {
                    self.webView.evaluateJavaScript("__JSBridge__reject__(\(id), new Error('\($0.localizedDescription)'))")
                }
            }
        }
    }

    private func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        firstly {
            self.ready
        }.done {
            self.webView.evaluateJavaScript(javaScriptString, completionHandler: completionHandler)
        }.catch {
            completionHandler?(nil, $0)
        }
    }

    internal func rawCall(function: String, args: String) -> Promise<String> {
        return Promise<String> { seal in
            let id = self.nextIdentifier
            self.nextIdentifier += 1
            self.handlers[id] = seal

            self.evaluateJavaScript("__JSBridge__receive__(\(id), () => \(function), ...[\(args)])") {
                if let error = $1 { seal.reject(error) }
            }
        }
    }

    internal func register(namespace: String) {
        self.evaluateJavaScript("window.\(namespace) = {}")
    }

    internal func register(functionNamed name: String, _ fn: @escaping ([String]) throws -> Promise<String>) {
        self.functions[name] = fn
        self.evaluateJavaScript("window.\(name) = (...args) => __JSBridge__send__('\(name)', ...args)")
    }
}
