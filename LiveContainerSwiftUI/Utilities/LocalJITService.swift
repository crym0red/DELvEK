
import Foundation
import Network
import Security
import UIKit

/// Real built-in JIT coordinator. The host owns a loopback-only HTTP control plane;
/// the actual JIT operation is performed by the separately embedded ShareExtension
/// helper using StikJIT, so the host never debugs itself.
public final class LocalJITService: NSObject {
    public static let shared = LocalJITService()

    private let queue = DispatchQueue(label: "com.delvek.local-jit", qos: .userInitiated)
    private var listener: NWListener?
    private var port: UInt16 = 0
    private var helperExtension: NSExtension?
    private var waiters: [String: CheckedContinuation<Result, Never>] = [:]
    private let lock = NSLock()

    public struct Result: Sendable {
        public let success: Bool
        public let message: String
    }

    private override init() {
        super.init()
    }

    public func start() {
        queue.async { [weak self] in
            guard let self, self.listener == nil else { return }
            do {
                let listener = try NWListener(using: .tcp, on: .any)
                listener.newConnectionHandler = { [weak self] connection in
                    self?.handle(connection)
                }
                listener.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    if case .ready = state, let port = listener.port?.rawValue {
                        self.port = port
                        NSLog("[DELvEK JIT] local API ready on 127.0.0.1:%u", port)
                    }
                }
                listener.parameters.allowLocalEndpointReuse = true
                listener.start(queue: self.queue)
                self.listener = listener
            } catch {
                NSLog("[DELvEK JIT] failed to start local API: %@", error.localizedDescription)
            }
        }
    }

    public var isAvailable: Bool {
        if #available(iOS 17.4, *) { return true }
        return false
    }

    public var pairingFileURL: URL {
        DELvEKPairingStore.shared.pairingURL
    }

    public var hasPairingFile: Bool {
        DELvEKPairingStore.shared.exists
    }

    public func storePairingFile(from source: URL) throws {
        _ = try DELvEKPairingStore.shared.importPairing(from: source)
    }

    public func removePairingFile() {
        DELvEKPairingStore.shared.remove()
    }

    public func enableJIT(targetPID: Int32 = getpid()) async -> Result {
        guard #available(iOS 17.4, *) else {
            return Result(success: false, message: "Built-in JIT requires iOS 17.4 or later.")
        }
        guard hasGetTaskAllow else {
            return Result(success: false, message: "DELvEK is not signed with get-task-allow. Reinstall it with a development/debug signing method.")
        }
        guard hasPairingFile else {
            return Result(success: false, message: "Import a device pairing file before enabling Built-in JIT.")
        }
        start()

        let data: Data
        do { data = try Data(contentsOf: pairingFileURL) }
        catch { return Result(success: false, message: "Unable to read pairing file: \(error.localizedDescription)") }

        let requestID = UUID().uuidString
        let callbackPort = await waitForPort()
        let callbackURL = "http://127.0.0.1:\(callbackPort)/v1/jit/result/\(requestID)"
        let item = NSExtensionItem()
        item.userInfo = [
            "delvekJIT": true,
            "requestID": requestID,
            "targetPID": Int(targetPID),
            "pairingData": data,
            "callbackURL": callbackURL
        ]

        return await withCheckedContinuation { continuation in
            lock.lock()
            waiters[requestID] = continuation
            lock.unlock()
            do {
                let ext = try NSExtension(identifier: "com.delvek.app.ShareExtension")
                helperExtension = ext
                Task { await ext.beginRequest(withInputItems: [item]) }
            } catch {
                lock.lock()
                let waiter = waiters.removeValue(forKey: requestID)
                lock.unlock()
                waiter?.resume(returning: Result(success: false, message: "Unable to start the JIT helper: \(error.localizedDescription)"))
            }
        }
    }

    private var hasGetTaskAllow: Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        guard let value = SecTaskCopyValueForEntitlement(task, "get-task-allow" as CFString, nil) else { return false }
        return (value as? NSNumber)?.boolValue == true
    }

    private func waitForPort() async -> UInt16 {
        for _ in 0..<100 {
            if port != 0 { return port }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return port
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, data: Data())
    }

    private func receive(_ connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] chunk, _, isComplete, error in
            guard let self else { return }
            var buffer = data
            if let chunk { buffer.append(chunk) }
            if let error {
                connection.cancel()
                NSLog("[DELvEK JIT] local API receive error: %@", error.localizedDescription)
                return
            }
            if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let header = String(decoding: buffer[..<headerEnd.lowerBound], as: UTF8.self)
                let bodyStart = headerEnd.upperBound
                var bodyLength = 0
                for line in header.components(separatedBy: "\r\n") where line.lowercased().hasPrefix("content-length:") {
                    bodyLength = Int(line.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
                }
                let availableBodyBytes = buffer.distance(from: bodyStart, to: buffer.endIndex)
                if availableBodyBytes >= bodyLength {
                    let bodyEnd = buffer.index(bodyStart, offsetBy: bodyLength)
                    let body = buffer[bodyStart..<bodyEnd]
                    self.handleRequest(header: header, body: Data(body), connection: connection)
                    return
                }
            }
            if isComplete {
                connection.cancel()
            } else {
                self.receive(connection, data: buffer)
            }
        }
    }

    private func handleRequest(header: String, body: Data, connection: NWConnection) {
        let firstLine = header.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? ""
        let path = parts.count > 1 ? String(parts[1]) : "/"

        if method == "GET" && path == "/v1/status" {
            respond(connection, status: 200, body: Data(#"{"running":true,"jit":"builtin"}"#.utf8))
            return
        }

        if method == "POST", path.hasPrefix("/v1/jit/result/") {
            let requestID = String(path.dropFirst("/v1/jit/result/".count))
            let result = (try? JSONDecoder().decode(HelperResult.self, from: body)) ?? HelperResult(success: false, message: "Invalid helper response")
            lock.lock()
            let waiter = waiters.removeValue(forKey: requestID)
            lock.unlock()
            waiter?.resume(returning: Result(success: result.success, message: result.message))
            respond(connection, status: 200, body: Data(#"{"ok":true}"#.utf8))
            return
        }
        respond(connection, status: 404, body: Data(#"{"error":"not_found"}"#.utf8))
    }

    private struct HelperResult: Codable {
        let success: Bool
        let message: String
    }

    private func respond(_ connection: NWConnection, status: Int, body: Data) {
        let text = "HTTP/1.1 \(status) OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var response = Data(text.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
}
