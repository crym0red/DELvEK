
import SwiftUI
import UIKit
import StikJIT

final class ShareExtensionHandler: UIViewController, NSExtensionRequestHandling {
    private let viewModel = ShareExtensionViewModel()
    private var host: UIHostingController<ShareExtensionRootView>?
    private let jitQueue = DispatchQueue(label: "com.delvek.stikjit.helper", qos: .userInitiated)

    override func viewDidLoad() {
        super.viewDidLoad()
        let root = ShareExtensionRootView(viewModel: viewModel, extensionContext: extensionContext)
        let host = UIHostingController(rootView: root)
        self.host = host
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        viewModel.loadPayload(from: extensionContext)
    }

    override func beginRequest(with context: NSExtensionContext) {
        if let info = context.inputItems.first as? NSExtensionItem,
           let values = info.userInfo,
           values["delvekJIT"] as? Bool == true {
            runJIT(values: values, context: context)
            return
        }
        viewModel.loadPayload(from: context)
    }

    private func runJIT(values: [AnyHashable: Any], context: NSExtensionContext) {
        guard #available(iOS 17.4, *) else {
            if let callback = (values["callbackURL"] as? String).flatMap(URL.init(string:)) {
                postAndWait(false, "Built-in JIT requires iOS 17.4 or later.", callbackURL: callback)
            }
            context.completeRequest(returningItems: nil)
            return
        }
        guard let pid = values["targetPID"] as? Int,
              let pairingData = values["pairingData"] as? Data,
              let callbackURLString = values["callbackURL"] as? String,
              let callbackURL = URL(string: callbackURLString) else {
            if let callback = (values["callbackURL"] as? String).flatMap(URL.init(string:)) {
                postAndWait(false, "JIT helper received incomplete request data.", callbackURL: callback)
            }
            context.completeRequest(returningItems: nil)
            return
        }

        jitQueue.async { [weak self] in
            guard let self else { return }
            let fm = FileManager.default
            let library = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            let root = library.appendingPathComponent("StikJIT", isDirectory: true)
            let paths = DDIPaths.default(in: root)
            let temp = fm.temporaryDirectory.appendingPathComponent("pairing-\(UUID().uuidString).plist")
            do {
                try fm.createDirectory(at: root, withIntermediateDirectories: true)
                try pairingData.write(to: temp, options: .atomic)
                try StikJIT.enableJIT(
                    targetPID: pid,
                    pairingFile: temp,
                    ddiPaths: paths,
                    script: .universal,
                    forceScript: false,
                    preparationProgress: { stage in NSLog("[DELvEK JIT] %@", String(describing: stage)) },
                    progress: { message in NSLog("[DELvEK JIT] %@", message) }
                )
                try? fm.removeItem(at: temp)
                self.postAndWait(true, "JIT enabled and verified for PID \(pid).", callbackURL: callbackURL)
            } catch {
                try? fm.removeItem(at: temp)
                self.postAndWait(false, error.localizedDescription, callbackURL: callbackURL)
            }
            context.completeRequest(returningItems: nil)
        }
    }

    private func postAndWait(_ success: Bool, _ message: String, callbackURL: URL) {
        var request = URLRequest(url: callbackURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["success": success, "message": message])
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, _, _ in semaphore.signal() }.resume()
        _ = semaphore.wait(timeout: .now() + 10)
    }

}
