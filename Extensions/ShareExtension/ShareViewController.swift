import UIKit
import Social
import UniformTypeIdentifiers

/// Share extension controller receiving archives from system share sheets and handing them to Unpack via the App Group inbox.
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
        processSharedItems()
    }

    private func processSharedItems() {
        guard let extensionContext = extensionContext,
              let item = extensionContext.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments, !attachments.isEmpty else {
            completeRequest()
            return
        }

        let appGroupID = "group.com.unpack.app"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            completeRequest()
            return
        }

        let inboxURL = containerURL.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)

        let dispatchGroup = DispatchGroup()

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier("public.item") {
                dispatchGroup.enter()
                provider.loadFileRepresentation(forTypeIdentifier: "public.item") { tempURL, error in
                    defer { dispatchGroup.leave() }
                    if let tempURL = tempURL {
                        let destURL = inboxURL.appendingPathComponent(tempURL.lastPathComponent)
                        try? FileManager.default.removeItem(at: destURL)
                        try? FileManager.default.copyItem(at: tempURL, to: destURL)
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.openMainApp()
            self?.completeRequest()
        }
    }

    private func openMainApp() {
        guard let url = URL(string: "unpack://import-inbox") else { return }
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = responder?.next
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
