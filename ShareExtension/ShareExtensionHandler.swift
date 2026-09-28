import UIKit
import UniformTypeIdentifiers
import StikJIT

final class ShareExtensionHandler: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        handleExtensionContext()
    }

    private func handleExtensionContext() {
        guard let extensionContext = extensionContext else {
            finish()
            return
        }

        guard let item = extensionContext.inputItems.first as? NSExtensionItem else {
            finish()
            return
        }

        guard let attachments = item.attachments else {
            finish()
            return
        }

        for provider in attachments {
            processProvider(provider)
        }
    }

    private func processProvider(_ provider: NSItemProvider) {
        if provider.hasItemConformingToTypeIdentifier(
            UTType.propertyList.identifier
        ) {
            provider.loadItem(
                forTypeIdentifier: UTType.propertyList.identifier,
                options: nil
            ) { [weak self] item, error in

                if let error {
                    NSLog(
                        "[DELvEK JIT] Failed to load property list: %@",
                        error.localizedDescription
                    )

                    DispatchQueue.main.async {
                        self?.finish()
                    }

                    return
                }

                guard
                    let values = item as? [String: Any]
                else {
                    NSLog("[DELvEK JIT] Invalid property list payload.")

                    DispatchQueue.main.async {
                        self?.finish()
                    }

                    return
                }

                self?.handlePayload(values)
            }

            return
        }

        DispatchQueue.main.async {
            self.finish()
        }
    }

    private func handlePayload(_ values: [String: Any]) {

        guard
            let pidValue = values["targetPID"] as? Int,
            let pid = Int32(exactly: pidValue),
            let pairingData = values["pairingData"] as? Data,
            let callbackURLString = values["callbackURL"] as? String,
            let callbackURL = URL(string: callbackURLString)
        else {
            NSLog("[DELvEK JIT] Invalid payload.")

            finish()
            return
        }

        let paths: StikJIT.DDIPaths

        if let ddiValue = values["ddiPaths"] as? [String: String] {
            paths = StikJIT.DDIPaths(
                developerDiskImagePath: ddiValue["developerDiskImagePath"] ?? "",
                developerDiskImageTrustCachePath:
                    ddiValue["developerDiskImageTrustCachePath"] ?? ""
            )
        } else {
            NSLog("[DELvEK JIT] Missing DDI paths.")

            finish()
            return
        }

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        do {
            try FileManager.default.createDirectory(
                at: tempDirectory,
                withIntermediateDirectories: true
            )

            let pairingFile = tempDirectory
                .appendingPathComponent("pairing_file.plist")

            try pairingData.write(
                to: pairingFile,
                options: [.atomic]
            )

            enableJIT(
                pid: pid,
                pairingFile: pairingFile,
                paths: paths,
                callbackURL: callbackURL
            )

        } catch {
            NSLog(
                "[DELvEK JIT] Failed preparing pairing file: %@",
                error.localizedDescription
            )

            finish()
        }
    }

    private func enableJIT(
        pid: Int32,
        pairingFile: URL,
        paths: StikJIT.DDIPaths,
        callbackURL: URL
    ) {

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in

            do {

                try StikJIT.enableJIT(
                    targetPID: pid,
                    pairingFile: pairingFile,
                    ddiPaths: paths,
                    script: .universal,
                    forceScript: false,
                    preparationProgress: { stage in

                        NSLog(
                            "[DELvEK JIT] %@",
                            String(describing: stage)
                        )
                    },
                    progress: { message in

                        NSLog(
                            "[DELvEK JIT] %@",
                            message
                        )
                    }
                )

                NSLog("[DELvEK JIT] JIT enabled successfully.")

                self?.sendCallback(
                    url: callbackURL,
                    success: true
                )

            } catch {

                NSLog(
                    "[DELvEK JIT] Failed to enable JIT: %@",
                    error.localizedDescription
                )

                self?.sendCallback(
                    url: callbackURL,
                    success: false
                )
            }

            DispatchQueue.main.async {
                self?.finish()
            }
        }
    }

    private func sendCallback(
        url: URL,
        success: Bool
    ) {

        var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )

        var queryItems = components?.queryItems ?? []

        queryItems.append(
            URLQueryItem(
                name: "success",
                value: success ? "1" : "0"
            )
        )

        components?.queryItems = queryItems

        guard let callbackURL = components?.url else {
            NSLog("[DELvEK JIT] Invalid callback URL.")
            return
        }

        DispatchQueue.main.async {

            self.extensionContext?.open(
                callbackURL,
                completionHandler: { success in

                    NSLog(
                        "[DELvEK JIT] Callback opened: %@",
                        success ? "YES" : "NO"
                    )
                }
            )
        }
    }

    private func finish() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(
                returningItems: nil,
                completionHandler: nil
            )
        }
    }
}
