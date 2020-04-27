import UIKit
import Social
import DcCore
import MobileCoreServices


class ShareViewController: SLComposeServiceViewController {

    class SimpleLogger: Logger {
        func verbose(_ message: String) {
            print("ShareViewController", "verbose", message)
        }

        func debug(_ message: String) {
            print("ShareViewController", "debug", message)
        }

        func info(_ message: String) {
            print("ShareViewController", "info", message)
        }

        func warning(_ message: String) {
            print("ShareViewController", "warning", message)
        }

        func error(_ message: String) {
            print("ShareViewController", "error", message)
        }
    }

    let logger = SimpleLogger()
    let dcContext = DcContext.shared
    var selectedChatId: Int?
    var selectedChat: DcChat?
    let dbHelper = DatabaseHelper()
    lazy var shareAttachment: ShareAttachment = {
        return ShareAttachment(inputItems: self.extensionContext?.inputItems)
    }()

    var messages: [DcMsg] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        // workaround for iOS13 bug
        if #available(iOS 13.0, *) {
            _ = NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { (_) in
                if let layoutContainerView = self.view.subviews.last {
                    layoutContainerView.frame.size.height += 10
                }
            }
        }
        createMessages()
    }

    override func presentationAnimationDidFinish() {
        if dbHelper.currentDatabaseLocation == dbHelper.sharedDbFile {
            dcContext.logger = self.logger
            dcContext.openDatabase(dbFile: dbHelper.sharedDbFile)
            selectedChatId = dcContext.getChatIdByContactId(contactId: Int(DC_CONTACT_ID_SELF))
            if let chatId = selectedChatId {
                selectedChat = dcContext.getChat(chatId: chatId)
            }
            reloadConfigurationItems()
        } else {
            cancel()
        }
    }

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return  !(contentText?.isEmpty ?? true) || !self.shareAttachment.isEmpty
    }

    private func setupNavigationBar() {
        guard let item = navigationController?.navigationBar.items?.first else { return }
        let button = UIBarButtonItem(
            title: String.localized("menu_send"),
            style: .done,
            target: self,
            action: #selector(appendPostTapped))
        item.rightBarButtonItem? = button
        item.titleView = UIImageView(image: UIImage(named: "ic_chat")?.scaleDownImage(toMax: 26))
    }

    /// Invoked when the user wants to post.
    @objc
    private func appendPostTapped() {
        if let chatId = self.selectedChatId {
            if !self.contentText.isEmpty {
                if messages.count == 1 {
                    messages[0].text?.append(self.contentText)
                } else {
                    let message = DcMsg(viewType: DC_MSG_TEXT)
                    message.text = self.contentText
                    messages.insert(message, at: 0)
                }
            }
            let chatListController = SendingController(chatId: chatId, dcMsgs: messages, dcContext: dcContext)
            chatListController.delegate = self
            self.pushConfigurationViewController(chatListController)
        }
    }

    private func createMessages() {
        for item in shareAttachment.image {
            item.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { data, error in
                let result: UIImage?
                switch data {
                case let image as UIImage:
                    result = image
                case let data as Data:
                    result = UIImage(data: data)
                case let url as URL:
                    result = UIImage(contentsOfFile: url.path)
                default:
                    self.dcContext.logger?.debug("Unexpected data: \(type(of: data))")
                    result = nil
                }
                if let result = result, let compressedImage = result.dcCompress() {
                    let pixelSize = compressedImage.imageSizeInPixel()
                    let path = DcUtils.saveImage(image: compressedImage)
                    let msg = DcMsg(viewType: DC_MSG_IMAGE)
                    msg.setFile(filepath: path, mimeType: "image/jpeg")
                    msg.setDimension(width: pixelSize.width, height: pixelSize.height)
                    self.messages.append(msg)
                }
            }
        }
    }

    func quit() {
        if dbHelper.currentDatabaseLocation == dbHelper.sharedDbFile {
            dcContext.closeDatabase()
        }

        // Inform the host that we're done, so it un-blocks its UI.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        logger.debug("configurationItems")
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.

        let item = SLComposeSheetConfigurationItem()
        item?.title = String.localized("forward_to")
        item?.value = selectedChat?.name
        logger.debug("configurationItems chat name: \(String(describing: selectedChat?.name))")
        item?.tapHandler = {
            let chatListController = ChatListController(dcContext: self.dcContext, chatListDelegate: self)
            self.pushConfigurationViewController(chatListController)
        }

        return [item as Any]
    }

    override func didSelectCancel() {
        quit()
    }
}

extension ShareViewController: ChatListDelegate {
    func onChatSelected(chatId: Int) {
        selectedChatId = chatId
        selectedChat = dcContext.getChat(chatId: chatId)
        reloadConfigurationItems()
        popConfigurationViewController()
    }
}

extension ShareViewController: SendingControllerDelegate {
    func onSendingAttemptFinished() {
        DispatchQueue.main.async {
            self.popConfigurationViewController()
            self.quit()
        }
    }
}
