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

        guard let attachments = item.attachments, !attachments.isEmpty else {
            finish()
            return
        }

        for provider in attachments {
            processProvider(provider)
        }
    }

    private func processProvider(_ provider: NSItemProvider) {
        let propertyListType = UTType.propertyList.identifier

        guard provider.hasItemConformingToTypeIdentifier(propertyListType) else {
            NSLog("[DELvEK JIT] Unsupported extension item.")
            finish()
            return
        }

        provider.loadItem(
            forTypeIdentifier: propertyListType,
            options: nil
        ) { [weak self] item, error in

            if let error {
                NSLog(
                    "[DELvEK JIT] Failed to load property list: %@",
                    error.localizedDescription
                )

                self?.finish()
                return
            }

            guard let values = self?.dictionary(from: item) else {
                NSLog("[DELvEK JIT] Invalid property list payload.")
                self?.finish()
                return
            }

            self?.handlePayload(values)
        }
    }

    private func dictionary(from item: NSSecureCoding?) -> [String: Any]? {
        if let dictionary = item as? [String: Any] {
            return dictionary
        }

        if let dictionary = item as? NSDictionary {
            return dictionary as? [String: Any]
        }

        if let data = item as? Data {
            do {
                let object = try PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                )

                return object as? [String: Any]
            } catch {
                NSLog(
                    "[DELvEK JIT] Failed to decode property list: %@",
                    error.localizedDescription
                )
            }
        }

        return nil
    }

    private func handlePayload(_ values: [String: Any]) {
        guard
            let pidValue = values["targetPID"] as? Int,
            let pid = Int32(exactly: pidValue),
            let pairingData = values["pairingData"] as? Data,
            let callbackURLString = values["callbackURL"] as? String,
            let callbackURL = URL(string: callbackURLString)
        else {
            NSLog("[DELvEK JIT] Invalid JIT payload.")
            finish()
            return
        }

        let paths: DDIPaths

        let ddiDictionary: [String: Any]?

        if let dictionary = values["ddiPaths"] as? [String: Any] {
            ddiDictionary = dictionary
        } else if let dictionary = values["ddiPaths"] as? NSDictionary {
            ddiDictionary = dictionary as? [String: Any]
        } else {
            ddiDictionary = nil
        }

        guard let ddi = ddiDictionary else {
            NSLog("[DELvEK JIT] Missing DDI paths.")
            finish()
            return
        }

        let imagePath =
            (ddi["imagePath"] as? String) ??
            (ddi["developerDiskImagePath"] as? String)

        let trustcachePath =
            (ddi["trustcachePath"] as? String) ??
            (ddi["developerDiskImageTrustCachePath"] as? String)

        let manifestPath =
            (ddi["manifestPath"] as? String) ??
            (ddi["developerDiskImageManifestPath"] as? String)

        guard
            let imagePath,
            !imagePath.isEmpty,
            let trustcachePath,
            !trustcachePath.isEmpty,
            let manifestPath,
            !manifestPath.isEmpty
        else {
            NSLog("[DELvEK JIT] Incomplete DDI paths.")
            finish()
            return
        }

        paths = DDIPaths(
            imagePath: imagePath,
            trustcachePath: trustcachePath,
            manifestPath: manifestPath,
            cryptexInfoPath:
                (ddi["cryptexInfoPath"] as? String) ?? "",
            rootHashPath:
                (ddi["rootHashPath"] as? String) ?? ""
        )

        let temporaryDirectory =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "DELvEK-JIT",
                    isDirectory: true
                )
                .appendingPathComponent(
                    UUID().uuidString,
                    isDirectory: true
                )

        do {
            try FileManager.default.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let pairingFile =
                temporaryDirectory
                    .appendingPathComponent("pairing_file.plist")

            try pairingData.write(
                to: pairingFile,
                options: [.atomic]
            )

            NSLog(
                "[DELvEK JIT] Target PID: %d",
                pid
            )

            NSLog(
                "[DELvEK JIT] Developer disk image: %@",
                paths.imagePath
            )

            NSLog(
                "[DELvEK JIT] Developer disk image trust cache: %@",
                paths.trustcachePath
            )

            NSLog(
                "[DELvEK JIT] Developer disk image manifest: %@",
                paths.manifestPath
            )

            NSLog(
                "[DELvEK JIT] Cryptex info: %@",
                paths.cryptexInfoPath
            )

            NSLog(
                "[DELvEK JIT] Root hash: %@",
                paths.rootHashPath
            )

            enableJIT(
                pid: pid,
                pairingFile: pairingFile,
                paths: paths,
                callbackURL: callbackURL,
                temporaryDirectory: temporaryDirectory
            )

        } catch {
            NSLog(
                "[DELvEK JIT] Failed preparing pairing data: %@",
                error.localizedDescription
            )

            finish()
        }
    }

    private func enableJIT(
        pid: Int32,
        pairingFile: URL,
        paths: DDIPaths,
        callbackURL: URL,
        temporaryDirectory: URL
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
                            "[DELvEK JIT] Preparation: %@",
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

                NSLog(
                    "[DELvEK JIT] JIT enabled successfully."
                )

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

            do {
                try FileManager.default.removeItem(
                    at: temporaryDirectory
                )
            } catch {
                NSLog(
                    "[DELvEK JIT] Temporary cleanup failed: %@",
                    error.localizedDescription
                )
            }

            self?.finish()
        }
    }

    private func sendCallback(
        url: URL,
        success: Bool
    ) {
        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            NSLog("[DELvEK JIT] Invalid callback URL.")
            return
        }

        var queryItems = components.queryItems ?? []

        queryItems.removeAll {
            $0.name == "success"
        }

        queryItems.append(
            URLQueryItem(
                name: "success",
                value: success ? "1" : "0"
            )
        )

        components.queryItems = queryItems

        guard let callbackURL = components.url else {
            NSLog("[DELvEK JIT] Failed to construct callback URL.")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.open(
                callbackURL,
                completionHandler: { opened in
                    NSLog(
                        "[DELvEK JIT] Callback opened: %@",
                        opened ? "YES" : "NO"
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
