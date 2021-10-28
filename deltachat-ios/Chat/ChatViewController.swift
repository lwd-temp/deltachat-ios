import MapKit
import QuickLook
import UIKit
import InputBarAccessoryView
import AVFoundation
import DcCore
import SDWebImage

class ChatViewController: UITableViewController {
    var dcContext: DcContext
    private var draftMessage: DcMsg?
    let outgoingAvatarOverlap: CGFloat = 17.5
    let loadCount = 30
    let chatId: Int
    var messageIds: [Int] = []

    var msgChangedObserver: NSObjectProtocol?
    var incomingMsgObserver: NSObjectProtocol?
    var chatModifiedObserver: NSObjectProtocol?
    var ephemeralTimerModifiedObserver: NSObjectProtocol?
    // isDismissing indicates whether the ViewController is/was about to dismissed.
    // The VC can be dismissed by pressing back '<' or by a swipe-to-dismiss gesture.
    // The latter is cancelable and leads to viewWillAppear is called in case the gesture is cancelled
    // We need the flag to handle that special case correctly in viewWillAppear
    private var isDismissing = false
    private var isInitial = true
    private var ignoreInputBarChange = false
    private var isVisibleToUser: Bool = false
    private var keepKeyboard: Bool = false

    lazy var isGroupChat: Bool = {
        return dcContext.getChat(chatId: chatId).isGroup
    }()

    lazy var draft: DraftModel = {
        let draft = DraftModel(dcContext: dcContext, chatId: chatId)
        return draft
    }()

    // search related
    private var activateSearch: Bool = false
    private var searchMessageIds: [Int] = []
    private var searchResultIndex: Int = 0
    private var debounceTimer: Timer?

    lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.searchResultsUpdater = self
        searchController.searchBar.inputAccessoryView = messageInputBar
        searchController.searchBar.autocorrectionType = .yes
        searchController.searchBar.keyboardType = .default
        return searchController
    }()

    public lazy var searchAccessoryBar: ChatSearchAccessoryBar = {
        let view = ChatSearchAccessoryBar()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isEnabled = false
        return view
    }()

    /// The `InputBarAccessoryView` used as the `inputAccessoryView` in the view controller.
    open var messageInputBar = ChatInputBar()

    lazy var draftArea: DraftArea = {
        let view = DraftArea()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        view.inputBarAccessoryView = messageInputBar
        return view
    }()

    public lazy var editingBar: ChatEditingBar = {
        let view = ChatEditingBar()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public lazy var contactRequestBar: ChatContactRequestBar = {
        let chat = dcContext.getChat(chatId: chatId)
        let view = ChatContactRequestBar(useDeleteButton: chat.isGroup && !chat.isMailinglist)
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    open override var shouldAutorotate: Bool {
        return false
    }

    private weak var timer: Timer?

    lazy var navBarTap: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(chatProfilePressed))
    }()

    private var locationStreamingItem: UIBarButtonItem = {
        let indicator = LocationStreamingIndicator()
        return UIBarButtonItem(customView: indicator)
    }()

    private lazy var muteItem: UIBarButtonItem = {
        let imageView = UIImageView()
        imageView.tintColor = DcColors.defaultTextColor
        imageView.image =  #imageLiteral(resourceName: "volume_off").withRenderingMode(.alwaysTemplate)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        return UIBarButtonItem(customView: imageView)
    }()

    private lazy var ephemeralMessageItem: UIBarButtonItem = {
        let imageView = UIImageView()
        imageView.tintColor = DcColors.defaultTextColor
        imageView.image =  #imageLiteral(resourceName: "ephemeral_timer").withRenderingMode(.alwaysTemplate)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        return UIBarButtonItem(customView: imageView)
    }()

    private lazy var initialsBadge: InitialsBadge = {
        let badge: InitialsBadge
        badge = InitialsBadge(size: 28, accessibilityLabel: String.localized("menu_view_profile"))
        badge.setLabelFont(UIFont.systemFont(ofSize: 14))
        badge.accessibilityTraits = .button
        return badge
    }()

    private lazy var badgeItem: UIBarButtonItem = {
        return UIBarButtonItem(customView: initialsBadge)
    }()

    private lazy var contextMenu: ContextMenuProvider = {
        let copyItem = ContextMenuProvider.ContextMenuItem(
        title: String.localized("global_menu_edit_copy_desktop"),
        imageName: "doc.on.doc",
        action: #selector(BaseMessageCell.messageCopy),
        onPerform: { [weak self] indexPath in
                guard let self = self else { return }
                let id = self.messageIds[indexPath.row]
                let msg = self.dcContext.getMessage(id: id)

                let pasteboard = UIPasteboard.general
                if msg.type == DC_MSG_TEXT {
                    pasteboard.string = msg.text
                } else {
                    pasteboard.string = msg.summary(chars: 10000000)
                }
            }
        )

        let infoItem = ContextMenuProvider.ContextMenuItem(
            title: String.localized("info"),
            imageName: "info",
            action: #selector(BaseMessageCell.messageInfo),
            onPerform: { [weak self] indexPath in
                guard let self = self else { return }
                let msg = self.dcContext.getMessage(id: self.messageIds[indexPath.row])
                let msgViewController = MessageInfoViewController(dcContext: self.dcContext, message: msg)
                if let ctrl = self.navigationController {
                    ctrl.pushViewController(msgViewController, animated: true)
                }
            }
        )

        let deleteItem = ContextMenuProvider.ContextMenuItem(
            title: String.localized("delete"),
            imageName: "trash",
            isDestructive: true,
            action: #selector(BaseMessageCell.messageDelete),
            onPerform: { [weak self] indexPath in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.tableView.becomeFirstResponder()
                    let msg = self.dcContext.getMessage(id: self.messageIds[indexPath.row])
                    self.askToDeleteMessage(id: msg.id)
                }
            }
        )

        let forwardItem = ContextMenuProvider.ContextMenuItem(
            title: String.localized("forward"),
            imageName: "ic_forward_white_36pt",
            action: #selector(BaseMessageCell.messageForward),
            onPerform: { [weak self] indexPath in
                guard let self = self else { return }
                let msg = self.dcContext.getMessage(id: self.messageIds[indexPath.row])
                RelayHelper.sharedInstance.setForwardMessage(messageId: msg.id)
                self.navigationController?.popViewController(animated: true)
            }
        )

        let replyItem = ContextMenuProvider.ContextMenuItem(
            title: String.localized("notify_reply_button"),
            imageName: "ic_reply",
            action: #selector(BaseMessageCell.messageReply),
            onPerform: { indexPath in
                DispatchQueue.main.async { [weak self] in
                    self?.replyToMessage(at: indexPath)
                }
            }
        )

        let selectMoreItem = ContextMenuProvider.ContextMenuItem(
            title: String.localized("select_more"),
            imageName: "checkmark.circle",
            action: #selector(BaseMessageCell.messageSelectMore),
            onPerform: { indexPath in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let messageId = self.messageIds[indexPath.row]
                    self.setEditing(isEditing: true, selectedAtIndexPath: indexPath)
                }
            }
        )

        let dcChat = dcContext.getChat(chatId: chatId)
        let config = ContextMenuProvider()
        if #available(iOS 13.0, *), dcChat.canSend {
            let mainContextMenu = ContextMenuProvider.ContextMenuItem(submenuitems: [replyItem, forwardItem, infoItem, copyItem, deleteItem])
            config.setMenu([mainContextMenu, selectMoreItem])
        } else if dcChat.canSend {
            config.setMenu([forwardItem, infoItem, copyItem, deleteItem, selectMoreItem])
        } else {
            config.setMenu([forwardItem, infoItem, copyItem, deleteItem])
        }

        return config
    }()

    /// The `BasicAudioController` controll the AVAudioPlayer state (play, pause, stop) and update audio cell UI accordingly.
    private lazy var audioController = AudioController(dcContext: dcContext, chatId: chatId, delegate: self)

    var showCustomNavBar = true
    var highlightedMsg: Int?

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    var emptyStateView: EmptyStateLabel = {
        let view =  EmptyStateLabel()
        view.isHidden = true
        return view
    }()

    init(dcContext: DcContext, chatId: Int, highlightedMsg: Int? = nil) {
        self.dcContext = dcContext
        self.chatId = chatId
        self.highlightedMsg = highlightedMsg
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let dcChat = dcContext.getChat(chatId: chatId)
        self.tableView = ChatTableView(messageInputBar: messageInputBar)
        if !dcChat.canSend {
            messageInputBar.isHidden = true
        }
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.view = self.tableView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(TextMessageCell.self, forCellReuseIdentifier: "text")
        tableView.register(ImageTextCell.self, forCellReuseIdentifier: "image")
        tableView.register(FileTextCell.self, forCellReuseIdentifier: "file")
        tableView.register(InfoMessageCell.self, forCellReuseIdentifier: "info")
        tableView.register(AudioMessageCell.self, forCellReuseIdentifier: "audio")
        tableView.register(VideoInviteCell.self, forCellReuseIdentifier: "video_invite")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.contentInsetAdjustmentBehavior = .never
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.backButtonTitle = String.localized("chat")
        definesPresentationContext = true

        if !dcContext.isConfigured() {
            // TODO: display message about nothing being configured
            return
        }
        configureEmptyStateView()

        let dcChat = dcContext.getChat(chatId: chatId)
        if dcChat.canSend {
            configureUIForWriting()
        } else if dcChat.isContactRequest {
            configureContactRequestBar()
        }
        loadMessages()
    }

    private func configureUIForWriting() {
        configureMessageInputBar()
        draft.parse(draftMsg: dcContext.getDraft(chatId: chatId))
        messageInputBar.inputTextView.text = draft.text
        configureDraftArea(draft: draft, animated: false)
        tableView.allowsMultipleSelectionDuringEditing = true
    }

    private func getTopInsetHeight() -> CGFloat {
        let navigationBarHeight = navigationController?.navigationBar.bounds.height ?? 0
        if let root = UIApplication.shared.keyWindow?.rootViewController {
            return navigationBarHeight + root.view.safeAreaInsets.top
        }
        return UIApplication.shared.statusBarFrame.height + navigationBarHeight
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            // reload table
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      let appDelegate = UIApplication.shared.delegate as? AppDelegate
                else { return }
                
                if appDelegate.appIsInForeground() {
                    self.messageIds = self.getMessageIds()
                    self.reloadData()
                } else {
                    logger.warning("startTimer() must not be executed in background")
                }
            }
        }
    }

    public func activateSearchOnAppear() {
        activateSearch = true
        navigationItem.searchController = self.searchController
    }

    private func stopTimer() {
        if let timer = timer {
            timer.invalidate()
        }
        timer = nil
    }

    private func configureEmptyStateView() {
        emptyStateView.addCenteredTo(parentView: view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // this will be removed in viewWillDisappear
        navigationController?.navigationBar.addGestureRecognizer(navBarTap)
        if showCustomNavBar {
            updateTitle(chat: dcContext.getChat(chatId: chatId))
        }
        if !isDismissing {
            self.tableView.becomeFirstResponder()
            if activateSearch {
                activateSearch = false
                DispatchQueue.main.async { [weak self] in
                    self?.searchController.isActive = true
                }
                
            }
            var bottomInsets = self.messageInputBar.intrinsicContentSize.height + self.messageInputBar.keyboardHeight
            if UIApplication.shared.statusBarOrientation.isLandscape,
               let root = UIApplication.shared.keyWindow?.rootViewController {
                // in landscape we need to take safeAreaInsets into account, in portrait they're already part of the keyboard height
                bottomInsets += root.view.safeAreaInsets.bottom
            }
            self.tableView.contentInset = UIEdgeInsets(top: self.getTopInsetHeight(),
                                                       left: 0,
                                                       bottom: bottomInsets,
                                                       right: 0)

            if let msgId = self.highlightedMsg, self.messageIds.firstIndex(of: msgId) != nil {
                UIView.animate(withDuration: 0.1, delay: 0, options: .allowAnimatedContent, animations: { [weak self] in
                    self?.scrollToMessage(msgId: msgId, animated: false)
                }, completion: { [weak self] finished in
                    if finished {
                        guard let self = self else { return }
                        self.highlightedMsg = nil
                        self.isInitial = false
                        self.ignoreInputBarChange = false
                        self.messageInputBar.scrollDownButton.isHidden = self.isLastRowVisible()
                    }
                })
            } else {
                UIView.animate(withDuration: 0.1, delay: 0, options: .allowAnimatedContent, animations: { [weak self] in
                    guard let self = self else { return }
                    if self.isInitial {
                        self.scrollToLastUnseenMessage()
                    }
                }, completion: { [weak self] finished in
                    guard let self = self else { return }
                    if finished {
                        self.isInitial = false
                        self.ignoreInputBarChange = false
                    }
                })
            }
        }
        isDismissing = false


        if RelayHelper.sharedInstance.isForwarding() {
            askToForwardMessage()
        } else if RelayHelper.sharedInstance.isMailtoHandling() {
            messageInputBar.inputTextView.text = RelayHelper.sharedInstance.mailtoDraft
            RelayHelper.sharedInstance.finishMailto()
        }

        prepareContextMenu()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppStateRestorer.shared.storeLastActiveChat(chatId: chatId)

        // things that do not affect the chatview
        // and are delayed after the view is displayed
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.dcContext.marknoticedChat(chatId: self.chatId)
        }

        handleUserVisibility(isVisible: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // the navigationController will be used when chatDetail is pushed, so we have to remove that gestureRecognizer
        navigationController?.navigationBar.removeGestureRecognizer(navBarTap)
        isDismissing = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isDismissing = false
        ignoreInputBarChange = true
        AppStateRestorer.shared.resetLastActiveChat()
        handleUserVisibility(isVisible: false)
        audioController.stopAnyOngoingPlaying()
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            // logger.debug("chat observer: remove")
            removeObservers()
        } else {
            // logger.debug("chat observer: setup")
            setupObservers()
        }
     }

    private func setupObservers() {
        let nc = NotificationCenter.default
        msgChangedObserver = nc.addObserver(
            forName: dcNotificationChanged,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo {
                let dcChat = self.dcContext.getChat(chatId: self.chatId)
                if !dcChat.canSend {
                    // always refresh, as we can't check currently
                    self.refreshMessages()
                } else if let id = ui["message_id"] as? Int {
                    if id > 0 {
                        self.updateMessage(id)
                    } else {
                        // change might be a deletion
                        self.refreshMessages()
                    }
                }
                if self.showCustomNavBar {
                    self.updateTitle(chat: dcChat)
                }
            }
        }

        incomingMsgObserver = nc.addObserver(
            forName: dcNotificationIncoming,
            object: nil, queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo {
                if self.chatId == ui["chat_id"] as? Int {
                    if let id = ui["message_id"] as? Int {
                        if id > 0 {
                            self.insertMessage(self.dcContext.getMessage(id: id))
                        }
                    }
                    self.updateTitle(chat: self.dcContext.getChat(chatId: self.chatId))
                }
            }
        }

        chatModifiedObserver = nc.addObserver(
            forName: dcNotificationChatModified,
            object: nil, queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo, self.chatId == ui["chat_id"] as? Int {

            }
        }

        ephemeralTimerModifiedObserver = nc.addObserver(
            forName: dcEphemeralTimerModified,
            object: nil, queue: OperationQueue.main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.updateTitle(chat: self.dcContext.getChat(chatId: self.chatId))
        }

        nc.addObserver(self,
                       selector: #selector(applicationDidBecomeActive(_:)),
                       name: UIApplication.didBecomeActiveNotification,
                       object: nil)

        nc.addObserver(self,
                       selector: #selector(applicationWillResignActive(_:)),
                       name: UIApplication.willResignActiveNotification,
                       object: nil)
    }
    
    private func removeObservers() {
        let nc = NotificationCenter.default
        if let msgChangedObserver = self.msgChangedObserver {
            nc.removeObserver(msgChangedObserver)
        }
        if let incomingMsgObserver = self.incomingMsgObserver {
            nc.removeObserver(incomingMsgObserver)
        }
        if let chatModifiedObserver = self.chatModifiedObserver {
            nc.removeObserver(chatModifiedObserver)
        }
        if let ephemeralTimerModifiedObserver = self.ephemeralTimerModifiedObserver {
            nc.removeObserver(ephemeralTimerModifiedObserver)
        }

        nc.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        nc.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let lastSectionVisibleBeforeTransition = self.isLastRowVisible()
        coordinator.animate(
            alongsideTransition: { [weak self] _ in
                guard let self = self else { return }
                if self.showCustomNavBar {
                    self.navigationItem.setRightBarButton(self.badgeItem, animated: true)
                }
                if lastSectionVisibleBeforeTransition {
                    self.scrollToBottom(animated: false)
                }
            },
            completion: {[weak self] _ in
                guard let self = self else { return }
                self.updateTitle(chat: self.dcContext.getChat(chatId: self.chatId))
                if lastSectionVisibleBeforeTransition {
                    DispatchQueue.main.async { [weak self] in
                        self?.reloadData()
                        self?.scrollToBottom(animated: false)
                    }
                }
            }
        )
        super.viewWillTransition(to: size, with: coordinator)
    }


    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        if navigationController?.visibleViewController == self {
            handleUserVisibility(isVisible: true)
        }
    }

    @objc func applicationWillResignActive(_ notification: NSNotification) {
        if navigationController?.visibleViewController == self {
            handleUserVisibility(isVisible: false)
        }
    }
    
    func handleUserVisibility(isVisible: Bool) {
        isVisibleToUser = isVisible
        if isVisible {
            startTimer()
            markSeenMessagesInVisibleArea()
        } else {
            stopTimer()
            draft.save(context: dcContext)
        }
    }

    /// UITableView methods

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageIds.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        _ = handleUIMenu()
        messageInputBar.scrollDownButton.isHidden = isInitial || isLastRowVisible()

        let id = messageIds[indexPath.row]
        if id == DC_MSG_ID_DAYMARKER {
            let cell = tableView.dequeueReusableCell(withIdentifier: "info", for: indexPath) as? InfoMessageCell ?? InfoMessageCell()
            if messageIds.count > indexPath.row + 1 {
                var nextMessageId = messageIds[indexPath.row + 1]
                if nextMessageId == DC_MSG_ID_MARKER1 && messageIds.count > indexPath.row + 2 {
                    nextMessageId = messageIds[indexPath.row + 2]
                }

                let nextMessage = dcContext.getMessage(id: nextMessageId)
                cell.update(text: DateUtils.getDateString(date: nextMessage.sentDate))
            } else {
                cell.update(text: "ErrDaymarker")
            }
            return cell
        } else if id == DC_MSG_ID_MARKER1 {
            // unread messages marker
            let cell = tableView.dequeueReusableCell(withIdentifier: "info", for: indexPath) as? InfoMessageCell ?? InfoMessageCell()
            let freshMsgsCount = self.messageIds.count - (indexPath.row + 1)
            cell.update(text: String.localized(stringID: "chat_n_new_messages", count: freshMsgsCount))
            return cell
        }
        
        let message = dcContext.getMessage(id: id)
        if message.isInfo {
            let cell = tableView.dequeueReusableCell(withIdentifier: "info", for: indexPath) as? InfoMessageCell ?? InfoMessageCell()
            cell.update(text: message.text)
            return cell
        }

        let cell: BaseMessageCell
        switch Int32(message.type) {
        case DC_MSG_VIDEOCHAT_INVITATION:
            let videoInviteCell = tableView.dequeueReusableCell(withIdentifier: "video_invite", for: indexPath) as? VideoInviteCell ?? VideoInviteCell()
            videoInviteCell.update(dcContext: dcContext, msg: message)
            return videoInviteCell

        case DC_MSG_IMAGE, DC_MSG_GIF, DC_MSG_VIDEO, DC_MSG_STICKER:
            cell = tableView.dequeueReusableCell(withIdentifier: "image", for: indexPath) as? ImageTextCell ?? ImageTextCell()

        case DC_MSG_FILE:
            if message.isSetupMessage {
                cell = tableView.dequeueReusableCell(withIdentifier: "text", for: indexPath) as? TextMessageCell ?? TextMessageCell()
                message.text = String.localized("autocrypt_asm_click_body")
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: "file", for: indexPath) as? FileTextCell ?? FileTextCell()
            }

        case DC_MSG_AUDIO, DC_MSG_VOICE:
            let audioMessageCell: AudioMessageCell = tableView.dequeueReusableCell(withIdentifier: "audio",
                                                                                      for: indexPath) as? AudioMessageCell ?? AudioMessageCell()
            audioController.update(audioMessageCell, with: message.id)
            cell = audioMessageCell
        default:
            cell = tableView.dequeueReusableCell(withIdentifier: "text", for: indexPath) as? TextMessageCell ?? TextMessageCell()
        }

        var showAvatar = isGroupChat && !message.isFromCurrentSender
        var showName = isGroupChat
        if message.overrideSenderName != nil {
            showAvatar = !message.isFromCurrentSender
            showName = true
        }

        cell.baseDelegate = self
        cell.update(dcContext: dcContext,
                    msg: message,
                    messageStyle: configureMessageStyle(for: message, at: indexPath),
                    showAvatar: showAvatar,
                    showName: showName,
                    searchText: searchController.searchBar.text,
                    highlight: !searchMessageIds.isEmpty && message.id == searchMessageIds[searchResultIndex])

        return cell
    }

    public override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            markSeenMessagesInVisibleArea()
        }
    }

    public override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        markSeenMessagesInVisibleArea()
    }

    private func configureContactRequestBar() {
        messageInputBar.separatorLine.backgroundColor = DcColors.colorDisabled
        messageInputBar.setMiddleContentView(contactRequestBar, animated: false)
        messageInputBar.setLeftStackViewWidthConstant(to: 0, animated: false)
        messageInputBar.setRightStackViewWidthConstant(to: 0, animated: false)
        messageInputBar.padding = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        messageInputBar.setStackViewItems([], forStack: .top, animated: false)
    }

    private func configureDraftArea(draft: DraftModel, animated: Bool = true) {
        if searchController.isActive {
            messageInputBar.setMiddleContentView(searchAccessoryBar, animated: false)
            messageInputBar.setLeftStackViewWidthConstant(to: 0, animated: false)
            messageInputBar.setRightStackViewWidthConstant(to: 0, animated: false)
            messageInputBar.setStackViewItems([], forStack: .top, animated: false)
            messageInputBar.padding = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
            return
        }

        draftArea.configure(draft: draft)
        if draft.isEditing {
            messageInputBar.setMiddleContentView(editingBar, animated: false)
            messageInputBar.setLeftStackViewWidthConstant(to: 0, animated: false)
            messageInputBar.setRightStackViewWidthConstant(to: 0, animated: false)
            messageInputBar.padding = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        } else {
            messageInputBar.setMiddleContentView(messageInputBar.inputTextView, animated: false)
            messageInputBar.setLeftStackViewWidthConstant(to: 40, animated: false)
            messageInputBar.setRightStackViewWidthConstant(to: 40, animated: false)
            messageInputBar.padding = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 12)
        }
        messageInputBar.setStackViewItems([draftArea], forStack: .top, animated: animated)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
       let swipeAction = UISwipeActionsConfiguration(actions: [])
       return swipeAction
    }


    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let message = dcContext.getMessage(id: messageIds[indexPath.row])
        let dcChat = dcContext.getChat(chatId: chatId)
        if !dcChat.canSend || message.isInfo || message.type == DC_MSG_VIDEOCHAT_INVITATION {
            return nil
        }

        let action = UIContextualAction(style: .normal, title: nil,
                                        handler: { [weak self] (_, _, completionHandler) in
                                            self?.keepKeyboard = true
                                            self?.replyToMessage(at: indexPath)
                                            completionHandler(true)
                                        })
        if #available(iOS 13.0, *) {
            action.image = UIImage(named: traitCollection.userInterfaceStyle == .light ? "ic_reply_black" : "ic_reply")
            action.backgroundColor = DcColors.chatBackgroundColor
        } else {
            action.image = UIImage(named: "ic_reply_black")
            action.backgroundColor = .systemBlue
        }
        action.image?.accessibilityTraits = .button
        action.image?.accessibilityLabel = String.localized("menu_reply")
        let configuration = UISwipeActionsConfiguration(actions: [action])

        return configuration
    }

    func replyToMessage(at indexPath: IndexPath) {
        let message = dcContext.getMessage(id: self.messageIds[indexPath.row])
        self.draft.setQuote(quotedMsg: message)
        self.configureDraftArea(draft: self.draft)
        self.messageInputBar.inputTextView.becomeFirstResponder()
    }

    func markSeenMessagesInVisibleArea() {
        if isVisibleToUser,
           let indexPaths = tableView.indexPathsForVisibleRows {
                let visibleMessagesIds = indexPaths.map { UInt32(messageIds[$0.row]) }
                if !visibleMessagesIds.isEmpty {
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        self?.dcContext.markSeenMessages(messageIds: visibleMessagesIds)
                    }
                }
        }
    }
    
    func markSeenMessage(id: Int) {
        if isVisibleToUser {
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.dcContext.markSeenMessages(messageIds: [UInt32(id)])
            }
        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            handleEditingBar()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            handleEditingBar()
            return
        }
        let messageId = messageIds[indexPath.row]
        let message = dcContext.getMessage(id: messageId)
        if message.isSetupMessage {
            didTapAsm(msg: message, orgText: "")
        } else if message.type == DC_MSG_FILE ||
            message.type == DC_MSG_AUDIO ||
            message.type == DC_MSG_VOICE {
            showMediaGalleryFor(message: message)
        } else if message.type == DC_MSG_VIDEOCHAT_INVITATION {
            if let url = NSURL(string: message.getVideoChatUrl()) {
                UIApplication.shared.open(url as URL)
            }
        }
        _ = handleUIMenu()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        messageInputBar.inputTextView.layer.borderColor = DcColors.colorDisabled.cgColor
    }

    func configureMessageStyle(for message: DcMsg, at indexPath: IndexPath) -> UIRectCorner {

        var corners: UIRectCorner = []

        if message.isFromCurrentSender {
            corners.formUnion(.topLeft)
            corners.formUnion(.bottomLeft)
            corners.formUnion(.topRight)
        } else {
            corners.formUnion(.topRight)
            corners.formUnion(.bottomRight)
            corners.formUnion(.topLeft)
        }

        return corners
    }

    private func getBackgroundColor(for currentMessage: DcMsg) -> UIColor {
        return currentMessage.isFromCurrentSender ? DcColors.messagePrimaryColor : DcColors.messageSecondaryColor
    }

    private func updateTitle(chat: DcChat) {
        let titleView =  ChatTitleView()

        var subtitle = "ErrSubtitle"
        let chatContactIds = chat.getContactIds(dcContext)
        if chat.isMailinglist {
            subtitle = String.localized("mailing_list")
        } else if chat.isBroadcast {
            subtitle = String.localized(stringID: "n_recipients", count: chatContactIds.count)
        } else if chat.isGroup {
            subtitle = String.localized(stringID: "n_members", count: chatContactIds.count)
        } else if chat.isDeviceTalk {
            subtitle = String.localized("device_talk_subtitle")
        } else if chat.isSelfTalk {
            subtitle = String.localized("chat_self_talk_subtitle")
        } else if chatContactIds.count >= 1 {
            subtitle = dcContext.getContact(id: chatContactIds[0]).email
        }

        titleView.updateTitleView(title: chat.name, subtitle: subtitle)
        navigationItem.titleView = titleView

        if let image = chat.profileImage {
            initialsBadge.setImage(image)
        } else {
            initialsBadge.setName(chat.name)
            initialsBadge.setColor(chat.color)
        }
        initialsBadge.setVerified(chat.isProtected)

        var rightBarButtonItems = [badgeItem]
        if chat.isSendingLocations {
            rightBarButtonItems.append(locationStreamingItem)
        }
        if chat.isMuted {
            rightBarButtonItems.append(muteItem)
        }

        if dcContext.getChatEphemeralTimer(chatId: chat.id) > 0 {
            rightBarButtonItems.append(ephemeralMessageItem)
        }

        navigationItem.rightBarButtonItems = rightBarButtonItems
    }

    @objc
    private func refreshMessages() {
        self.messageIds = self.getMessageIds()
        let wasLastSectionVisible = self.isLastRowVisible()
        self.reloadData()
        if wasLastSectionVisible {
            self.scrollToBottom(animated: true)
        }
        self.showEmptyStateView(self.messageIds.isEmpty)
    }

    private func reloadData() {
        let selectredRows = tableView.indexPathsForSelectedRows
        tableView.reloadData()
        // There's an iOS bug, filling up the console output but which can be ignored: https://developer.apple.com/forums/thread/668295
        // [Assert] Attempted to call -cellForRowAtIndexPath: on the table view while it was in the process of updating its visible cells, which is not allowed.
        selectredRows?.forEach({ (selectedRow) in
            tableView.selectRow(at: selectedRow, animated: false, scrollPosition: .none)
        })
    }

    private func loadMessages() {

        // update message ids
        var msgIds = self.getMessageIds()
        let freshMsgsCount = self.dcContext.getUnreadMessages(chatId: self.chatId)
        if freshMsgsCount > 0 && msgIds.count >= freshMsgsCount {
            let index = msgIds.count - freshMsgsCount
            msgIds.insert(Int(DC_MSG_ID_MARKER1), at: index)
        }
        self.messageIds = msgIds

        self.showEmptyStateView(self.messageIds.isEmpty)

        self.reloadData()
    }

    private func isLastRowVisible() -> Bool {
        guard !messageIds.isEmpty else { return false }

        let lastIndexPath = IndexPath(item: messageIds.count - 1, section: 0)
        return tableView.indexPathsForVisibleRows?.contains(lastIndexPath) ?? false
    }
    
    private func scrollToBottom() {
        scrollToBottom(animated: true)
    }
    
    private func scrollToBottom(animated: Bool) {
        if !messageIds.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let numberOfRows = self.tableView.numberOfRows(inSection: 0)
                if numberOfRows > 0 {
                    self.tableView.scrollToRow(at: IndexPath(row: numberOfRows - 1, section: 0), at: .bottom, animated: animated)
                }
            }
        }
    }

    private func scrollToLastUnseenMessage() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let markerMessageIndex = self.messageIds.index(of: Int(DC_MSG_ID_MARKER1)) {
                let indexPath = IndexPath(row: markerMessageIndex, section: 0)
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
            } else {
                // scroll to bottom
                let numberOfRows = self.tableView.numberOfRows(inSection: 0)
                if numberOfRows > 0 {
                    self.tableView.scrollToRow(at: IndexPath(row: numberOfRows - 1, section: 0), at: .bottom, animated: false)
                }
            }
        }
    }

    private func scrollToMessage(msgId: Int, animated: Bool = true, scrollToText: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let index = self.messageIds.firstIndex(of: msgId) else {
                return
            }
            let indexPath = IndexPath(row: index, section: 0)

            if scrollToText {
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
                let cell = self.tableView.cellForRow(at: indexPath)
                if let messageCell = cell as? BaseMessageCell {
                    let textYPos = messageCell.getTextOffset(of: self.searchController.searchBar.text)
                    let currentYPos = self.tableView.contentOffset.y
                    let padding: CGFloat = 12
                    self.tableView.setContentOffset(CGPoint(x: 0,
                                                            y: textYPos +
                                                                currentYPos -
                                                                2 * UIFont.preferredFont(for: .body, weight: .regular).lineHeight -
                                                                padding),
                                                    animated: false)

                    return
                }
            }

            self.tableView.scrollToRow(at: indexPath, at: .top, animated: animated)
        }
    }

    private func showEmptyStateView(_ show: Bool) {
        if show {
            let dcChat = dcContext.getChat(chatId: chatId)
            if dcChat.isGroup {
                if dcChat.isBroadcast {
                    emptyStateView.text = String.localized("chat_new_broadcast_hint")
                } else if dcChat.isUnpromoted {
                    emptyStateView.text = String.localized("chat_new_group_hint")
                } else {
                    emptyStateView.text = String.localized("chat_no_messages")
                }
            } else if dcChat.isSelfTalk {
                emptyStateView.text = String.localized("saved_messages_explain")
            } else if dcChat.isDeviceTalk {
                emptyStateView.text = String.localized("device_talk_explain")
            } else {
                emptyStateView.text = String.localizedStringWithFormat(String.localized("chat_no_messages_hint"), dcChat.name, dcChat.name)
            }
            emptyStateView.isHidden = false
        } else {
            emptyStateView.isHidden = true
        }
    }
    
    private func getMessageIds() -> [Int] {
        return dcContext.getMessageIds(chatId: chatId)
    }

    @objc private func saveDraft() {
        draft.save(context: dcContext)
    }

    private func configureMessageInputBar() {
        messageInputBar.delegate = self
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.placeholder = String.localized("chat_input_placeholder")
        messageInputBar.separatorLine.backgroundColor = DcColors.colorDisabled
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.textColor = DcColors.defaultTextColor
        messageInputBar.backgroundView.backgroundColor = DcColors.chatBackgroundColor
        messageInputBar.backgroundColor = DcColors.chatBackgroundColor
        messageInputBar.inputTextView.backgroundColor = DcColors.inputFieldColor
        messageInputBar.inputTextView.placeholderTextColor = DcColors.placeholderColor
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 38)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 38)
        messageInputBar.inputTextView.layer.borderColor = DcColors.colorDisabled.cgColor
        messageInputBar.inputTextView.layer.borderWidth = 1.0
        messageInputBar.inputTextView.layer.cornerRadius = 13.0
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.scrollIndicatorInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        configureInputBarItems()
        messageInputBar.inputTextView.delegate = self
        if let inputTextView = messageInputBar.inputTextView as? ChatInputTextView {
            inputTextView.imagePasteDelegate = self
        }
        messageInputBar.onScrollDownButtonPressed = scrollToBottom
    }

    private func evaluateInputBar(draft: DraftModel) {
        messageInputBar.sendButton.isEnabled = draft.canSend()
    }

    private func configureInputBarItems() {

        messageInputBar.setLeftStackViewWidthConstant(to: 40, animated: false)
        messageInputBar.setRightStackViewWidthConstant(to: 40, animated: false)


        let sendButtonImage = UIImage(named: "paper_plane")?.withRenderingMode(.alwaysTemplate)
        messageInputBar.sendButton.image = sendButtonImage
        messageInputBar.sendButton.accessibilityLabel = String.localized("menu_send")
        messageInputBar.sendButton.accessibilityTraits = .button
        messageInputBar.sendButton.title = nil
        messageInputBar.sendButton.tintColor = UIColor(white: 1, alpha: 1)
        messageInputBar.sendButton.layer.cornerRadius = 20
        messageInputBar.middleContentViewPadding = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        // this adds a padding between textinputfield and send button
        messageInputBar.sendButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        messageInputBar.sendButton.setSize(CGSize(width: 40, height: 40), animated: false)
        messageInputBar.padding = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 12)
        messageInputBar.shouldManageSendButtonEnabledState = false

        let leftItems = [
            InputBarButtonItem()
                .configure {
                    $0.spacing = .fixed(0)
                    let clipperIcon = #imageLiteral(resourceName: "ic_attach_file_36pt").withRenderingMode(.alwaysTemplate)
                    $0.image = clipperIcon
                    $0.tintColor = DcColors.primary
                    $0.setSize(CGSize(width: 40, height: 40), animated: false)
                    $0.accessibilityLabel = String.localized("menu_add_attachment")
                    $0.accessibilityTraits = .button
            }.onSelected {
                $0.tintColor = UIColor.themeColor(light: .lightGray, dark: .darkGray)
            }.onDeselected {
                $0.tintColor = DcColors.primary
            }.onTouchUpInside { [weak self] _ in
                self?.clipperButtonPressed()
            }
        ]

        messageInputBar.setStackViewItems(leftItems, forStack: .left, animated: false)

        // This just adds some more flare
        messageInputBar.sendButton
            .onEnabled { item in
                UIView.animate(withDuration: 0.3, animations: {
                    item.backgroundColor = DcColors.primary
                })}
            .onDisabled { item in
                UIView.animate(withDuration: 0.3, animations: {
                    item.backgroundColor = DcColors.colorDisabled
                })}
    }

    @objc private func chatProfilePressed() {
        showChatDetail(chatId: chatId)
    }

    @objc private func clipperButtonPressed() {
        showClipperOptions()
    }

    private func showClipperOptions() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .safeActionSheet)
        let galleryAction = PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:))
        let cameraAction = PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:))
        let documentAction = UIAlertAction(title: String.localized("files"), style: .default, handler: documentActionPressed(_:))
        let voiceMessageAction = UIAlertAction(title: String.localized("voice_message"), style: .default, handler: voiceMessageButtonPressed(_:))
        let isLocationStreaming = dcContext.isSendingLocationsToChat(chatId: chatId)
        let locationStreamingAction = UIAlertAction(title: isLocationStreaming ? String.localized("stop_sharing_location") : String.localized("location"),
                                                    style: isLocationStreaming ? .destructive : .default,
                                                    handler: locationStreamingButtonPressed(_:))

        alert.addAction(cameraAction)
        alert.addAction(galleryAction)
        alert.addAction(documentAction)
        alert.addAction(voiceMessageAction)

        if let config = dcContext.getConfig("webrtc_instance"), !config.isEmpty {
            let videoChatInvitation = UIAlertAction(title: String.localized("videochat"), style: .default, handler: videoChatButtonPressed(_:))
            alert.addAction(videoChatInvitation)
        }

        if UserDefaults.standard.bool(forKey: "location_streaming") {
            alert.addAction(locationStreamingAction)
        }
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: {
            // unfortunately, voiceMessageAction.accessibilityHint does not work,
            // but this hack does the trick
            if UIAccessibility.isVoiceOverRunning {
                if let view = voiceMessageAction.value(forKey: "__representer") as? UIView {
                    view.accessibilityHint = String.localized("a11y_voice_message_hint_ios")
                }
            }
        })
    }

    private func confirmationAlert(title: String, actionTitle: String, actionStyle: UIAlertAction.Style = .default, actionHandler: @escaping ((UIAlertAction) -> Void), cancelHandler: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title,
                                      message: nil,
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: actionTitle, style: actionStyle, handler: actionHandler))

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: cancelHandler ?? { _ in
            self.dismiss(animated: true, completion: nil)
            }))
        present(alert, animated: true, completion: nil)
    }
    
    private func askToDeleteChat() {
        let title = String.localized(stringID: "ask_delete_chat", count: 1)
        confirmationAlert(title: title, actionTitle: String.localized("delete"), actionStyle: .destructive,
                          actionHandler: { [weak self] _ in
                            guard let self = self else { return }
                            // remove message observers early to avoid careless calls to dcContext methods
                            self.removeObservers()
                            self.dcContext.deleteChat(chatId: self.chatId)
                            self.navigationController?.popViewController(animated: true)
                          })
    }
    

    private func askToChatWith(email: String) {
        let contactId = self.dcContext.createContact(name: "", email: email)
        if dcContext.getChatIdByContactId(contactId: contactId) != 0 {
            self.dismiss(animated: true, completion: nil)
            let chatId = self.dcContext.createChatByContactId(contactId: contactId)
            self.showChat(chatId: chatId)
        } else {
            confirmationAlert(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), email),
                              actionTitle: String.localized("start_chat"),
                              actionHandler: { _ in
                                self.dismiss(animated: true, completion: nil)
                                let chatId = self.dcContext.createChatByContactId(contactId: contactId)
                                self.showChat(chatId: chatId)})
        }
    }

    private func askToDeleteMessage(id: Int) {
        self.askToDeleteMessages(ids: [id])
    }

    private func askToDeleteMessages(ids: [Int]) {
        let chat = dcContext.getChat(chatId: chatId)
        let title = chat.isDeviceTalk ?
            String.localized(stringID: "ask_delete_messages_simple", count: ids.count) :
            String.localized(stringID: "ask_delete_messages", count: ids.count)
        confirmationAlert(title: title, actionTitle: String.localized("delete"), actionStyle: .destructive,
                          actionHandler: { _ in
                            self.dcContext.deleteMessages(msgIds: ids)
                            if self.tableView.isEditing {
                                self.setEditing(isEditing: false)
                            }
                          })
    }

    private func askToForwardMessage() {
        let chat = dcContext.getChat(chatId: self.chatId)
        if chat.isSelfTalk {
            RelayHelper.sharedInstance.forward(to: self.chatId)
            refreshMessages()
        } else {
            confirmationAlert(title: String.localizedStringWithFormat(String.localized("ask_forward"), chat.name),
                              actionTitle: String.localized("menu_forward"),
                              actionHandler: { _ in
                                RelayHelper.sharedInstance.forward(to: self.chatId)
                                self.dismiss(animated: true, completion: nil)},
                              cancelHandler: { _ in
                                self.dismiss(animated: false, completion: nil)
                                self.navigationController?.popViewController(animated: true)})
        }
    }

    // MARK: - coordinator
    private func showChatDetail(chatId: Int) {
        let chat = dcContext.getChat(chatId: chatId)
        if !chat.isGroup {
            if let contactId = chat.getContactIds(dcContext).first {
                let contactDetailController = ContactDetailViewController(dcContext: dcContext, contactId: contactId)
                navigationController?.pushViewController(contactDetailController, animated: true)
            }
        } else {
            let groupChatDetailViewController = GroupChatDetailViewController(chatId: chatId, dcContext: dcContext)
            navigationController?.pushViewController(groupChatDetailViewController, animated: true)
        }
    }

    func showChat(chatId: Int, messageId: Int? = nil, animated: Bool = true) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.showChat(chatId: chatId, msgId: messageId, animated: animated, clearViewControllerStack: true)
        }
    }

    private func showDocumentLibrary() {
        mediaPicker?.showDocumentLibrary()
    }

    private func showVoiceMessageRecorder() {
        mediaPicker?.showVoiceRecorder()
    }

    private func showCameraViewController() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            self.mediaPicker?.showCamera()
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: {  [weak self] (granted: Bool) in
                guard let self = self else { return }
                if granted {
                    self.mediaPicker?.showCamera()
                } else {
                    self.showCameraPermissionAlert()
                }
            })
        }
    }
    
    private func showCameraPermissionAlert() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: String.localized("perm_required_title"),
                                          message: String.localized("perm_ios_explain_access_to_camera_denied"),
                                          preferredStyle: .alert)
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                alert.addAction(UIAlertAction(title: String.localized("open_settings"), style: .default, handler: { _ in
                        UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)}))
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .destructive, handler: nil))
            }
            self?.present(alert, animated: true, completion: nil)
        }
    }

    private func showPhotoVideoLibrary(delegate: MediaPickerDelegate) {
        mediaPicker?.showPhotoVideoLibrary()
    }

    private func showMediaGallery(currentIndex: Int, msgIds: [Int]) {
        let betterPreviewController = PreviewController(dcContext: dcContext, type: .multi(msgIds, currentIndex))
        let nav = UINavigationController(rootViewController: betterPreviewController)
        nav.modalPresentationStyle = .fullScreen
        navigationController?.present(nav, animated: true)
    }

    private func documentActionPressed(_ action: UIAlertAction) {
        showDocumentLibrary()
    }

    private func voiceMessageButtonPressed(_ action: UIAlertAction) {
        showVoiceMessageRecorder()
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        showCameraViewController()
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        showPhotoVideoLibrary(delegate: self)
    }

    private func locationStreamingButtonPressed(_ action: UIAlertAction) {
        let isLocationStreaming = dcContext.isSendingLocationsToChat(chatId: chatId)
        if isLocationStreaming {
            locationStreamingFor(seconds: 0)
        } else {
            let alert = UIAlertController(title: String.localized("title_share_location"), message: nil, preferredStyle: .safeActionSheet)
            addDurationSelectionAction(to: alert, key: "share_location_for_5_minutes", duration: Time.fiveMinutes)
            addDurationSelectionAction(to: alert, key: "share_location_for_30_minutes", duration: Time.thirtyMinutes)
            addDurationSelectionAction(to: alert, key: "share_location_for_one_hour", duration: Time.oneHour)
            addDurationSelectionAction(to: alert, key: "share_location_for_two_hours", duration: Time.twoHours)
            addDurationSelectionAction(to: alert, key: "share_location_for_six_hours", duration: Time.sixHours)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func videoChatButtonPressed(_ action: UIAlertAction) {
        let chat = dcContext.getChat(chatId: chatId)

        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("videochat_invite_user_to_videochat"), chat.name),
                                      message: String.localized("videochat_invite_user_hint"),
                                      preferredStyle: .alert)
        let cancel = UIAlertAction(title: String.localized("cancel"), style: .default, handler: nil)
        let ok = UIAlertAction(title: String.localized("ok"),
                               style: .default,
                               handler: { _ in
                                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                                    guard let self = self else { return }
                                    let messageId = self.dcContext.sendVideoChatInvitation(chatId: self.chatId)
                                    let inviteMessage = self.dcContext.getMessage(id: messageId)
                                    if let url = NSURL(string: inviteMessage.getVideoChatUrl()) {
                                        DispatchQueue.main.async {
                                            UIApplication.shared.open(url as URL)
                                        }
                                    }
                                }})
        alert.addAction(cancel)
        alert.addAction(ok)
        self.present(alert, animated: true, completion: nil)
    }

    private func addDurationSelectionAction(to alert: UIAlertController, key: String, duration: Int) {
        let action = UIAlertAction(title: String.localized(key), style: .default, handler: { _ in
            self.locationStreamingFor(seconds: duration)
        })
        alert.addAction(action)
    }

    private func locationStreamingFor(seconds: Int) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        appDelegate.locationManager.shareLocation(chatId: self.chatId, duration: seconds)
    }

    func updateMessage(_ messageId: Int) {
        if messageIds.firstIndex(where: { $0 == messageId }) != nil {
            reloadData()
        } else {
            // new outgoing message
            let msg = dcContext.getMessage(id: messageId)
            if msg.state != DC_STATE_OUT_DRAFT,
               msg.chatId == chatId {
                if let newMsgMarkerIndex = messageIds.index(of: Int(DC_MSG_ID_MARKER1)) {
                    messageIds.remove(at: newMsgMarkerIndex)
                }
                insertMessage(msg)
            }
        }
    }

    func insertMessage(_ message: DcMsg) {
        markSeenMessage(id: message.id)
        let wasLastSectionVisible = isLastRowVisible()
        messageIds.append(message.id)
        emptyStateView.isHidden = true

        reloadData()
        if wasLastSectionVisible || message.isFromCurrentSender {
            scrollToBottom(animated: true)
        }
    }

    private func sendTextMessage(text: String, quoteMessage: DcMsg?) {
        DispatchQueue.global().async {
            let message = self.dcContext.newMessage(viewType: DC_MSG_TEXT)
            message.text = text
            if let quoteMessage = quoteMessage {
                message.quoteMessage = quoteMessage
            }
            self.dcContext.sendMessage(chatId: self.chatId, message: message)
        }
    }

    private func stageDocument(url: NSURL) {
        keepKeyboard = true
        self.draft.setAttachment(viewType: DC_MSG_FILE, path: url.relativePath)
        self.configureDraftArea(draft: self.draft)
        self.messageInputBar.inputTextView.becomeFirstResponder()
    }

    private func stageVideo(url: NSURL) {
        keepKeyboard = true
        DispatchQueue.main.async {
            self.draft.setAttachment(viewType: DC_MSG_VIDEO, path: url.relativePath)
            self.configureDraftArea(draft: self.draft)
            self.messageInputBar.inputTextView.becomeFirstResponder()
        }
    }

    private func stageImage(url: NSURL) {
        keepKeyboard = true
        DispatchQueue.global().async { [weak self] in
            if let image = ImageFormat.loadImageFrom(url: url as URL) {
                self?.stageImage(image)
            }
        }
    }

    private func stageImage(_ image: UIImage) {
        DispatchQueue.global().async {
            if let pathInDocDir = ImageFormat.saveImage(image: image) {
                DispatchQueue.main.async {
                    if pathInDocDir.suffix(4).contains(".gif") {
                        self.draft.setAttachment(viewType: DC_MSG_GIF, path: pathInDocDir)
                    } else {
                        self.draft.setAttachment(viewType: DC_MSG_IMAGE, path: pathInDocDir)
                    }
                    self.configureDraftArea(draft: self.draft)
                    self.messageInputBar.inputTextView.becomeFirstResponder()
                }
            }
        }
    }

    private func sendImage(_ image: UIImage, message: String? = nil) {
        DispatchQueue.global().async {
            if let path = ImageFormat.saveImage(image: image) {
                self.sendAttachmentMessage(viewType: DC_MSG_IMAGE, filePath: path, message: message)
            }
        }
    }

    private func sendSticker(_ image: UIImage) {
        DispatchQueue.global().async {
            if let path = ImageFormat.saveImage(image: image) {
                self.sendAttachmentMessage(viewType: DC_MSG_STICKER, filePath: path, message: nil)
            }
        }
    }

    private func sendAttachmentMessage(viewType: Int32, filePath: String, message: String? = nil, quoteMessage: DcMsg? = nil) {
        let msg = dcContext.newMessage(viewType: viewType)
        msg.setFile(filepath: filePath)
        msg.text = (message ?? "").isEmpty ? nil : message
        if quoteMessage != nil {
            msg.quoteMessage = quoteMessage
        }
        dcContext.sendMessage(chatId: self.chatId, message: msg)
    }

    private func sendVoiceMessage(url: NSURL) {
        DispatchQueue.global().async {
            let msg = self.dcContext.newMessage(viewType: DC_MSG_VOICE)
            msg.setFile(filepath: url.relativePath, mimeType: "audio/m4a")
            self.dcContext.sendMessage(chatId: self.chatId, message: msg)
        }
    }

    // MARK: - Context menu
    private func prepareContextMenu() {
        UIMenuController.shared.menuItems = contextMenu.menuItems
        UIMenuController.shared.update()
    }

    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        let messageId = messageIds[indexPath.row]
        return !(dcContext.getMessage(id: messageId).isInfo || messageId == DC_MSG_ID_MARKER1 || messageId == DC_MSG_ID_DAYMARKER)
    }

    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return !tableView.isEditing && contextMenu.canPerformAction(action: action)
    }

    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        // handle standard actions here, but custom actions never trigger this. it still needs to be present for the menu to display, though.
        contextMenu.performAction(action: action, indexPath: indexPath)
    }

    // context menu for iOS 13+
    @available(iOS 13, *)
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let messageId = messageIds[indexPath.row]
        if tableView.isEditing || dcContext.getMessage(id: messageId).isInfo || messageId == DC_MSG_ID_MARKER1 || messageId == DC_MSG_ID_DAYMARKER {
            return nil
        }
        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                self?.contextMenu.actionProvider(indexPath: indexPath)
            }
        )
    }

    func showMediaGalleryFor(indexPath: IndexPath) {
        let messageId = messageIds[indexPath.row]
        let message = dcContext.getMessage(id: messageId)
        if message.type != DC_MSG_STICKER {
            showMediaGalleryFor(message: message)
        }
    }

    func showMediaGalleryFor(message: DcMsg) {

        let msgIds = dcContext.getChatMedia(chatId: chatId, messageType: Int32(message.type), messageType2: 0, messageType3: 0)
        let index = msgIds.firstIndex(of: message.id) ?? 0
        showMediaGallery(currentIndex: index, msgIds: msgIds)
    }

    private func didTapAsm(msg: DcMsg, orgText: String) {
        let inputDlg = UIAlertController(
            title: String.localized("autocrypt_continue_transfer_title"),
            message: String.localized("autocrypt_continue_transfer_please_enter_code"),
            preferredStyle: .alert)
        inputDlg.addTextField(configurationHandler: { (textField) in
            textField.placeholder = msg.setupCodeBegin + ".."
            textField.text = orgText
            textField.keyboardType = UIKeyboardType.numbersAndPunctuation // allows entering spaces; decimalPad would require a mask to keep things readable
        })
        inputDlg.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))

        let okAction = UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
            let textField = inputDlg.textFields![0]
            let modText = textField.text ?? ""
            let success = self.dcContext.continueKeyTransfer(msgId: msg.id, setupCode: modText)

            let alert = UIAlertController(
                title: String.localized("autocrypt_continue_transfer_title"),
                message: String.localized(success ? "autocrypt_continue_transfer_succeeded" : "autocrypt_bad_setup_code"),
                preferredStyle: .alert)
            if success {
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            } else {
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                let retryAction = UIAlertAction(title: String.localized("autocrypt_continue_transfer_retry"), style: .default, handler: { _ in
                    self.didTapAsm(msg: msg, orgText: modText)
                })
                alert.addAction(retryAction)
                alert.preferredAction = retryAction
            }
            self.navigationController?.present(alert, animated: true, completion: nil)
        })

        inputDlg.addAction(okAction)
        inputDlg.preferredAction = okAction // without setting preferredAction, cancel become shown *bold* as the preferred action
        navigationController?.present(inputDlg, animated: true, completion: nil)
    }

    func handleUIMenu() -> Bool {
        if UIMenuController.shared.isMenuVisible {
            UIMenuController.shared.setMenuVisible(false, animated: true)
            return true
        }
        return false
    }

    func handleSelection(indexPath: IndexPath) -> Bool {
        if tableView.isEditing {
            if tableView.indexPathsForSelectedRows?.contains(indexPath) ?? false {
                tableView.deselectRow(at: indexPath, animated: false)
            } else {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
            handleEditingBar()
            return true
        }
        return false
    }

    func handleEditingBar() {
        if let rows = tableView.indexPathsForSelectedRows,
           !rows.isEmpty {
            editingBar.isEnabled = true
        } else {
            editingBar.isEnabled = false
        }
    }

    func setEditing(isEditing: Bool, selectedAtIndexPath: IndexPath? = nil) {
        self.tableView.setEditing(isEditing, animated: true)
        self.draft.isEditing = isEditing
        self.configureDraftArea(draft: self.draft)
        if let indexPath = selectedAtIndexPath {
            _ = handleSelection(indexPath: indexPath)
        }
    }
}

// MARK: - BaseMessageCellDelegate
extension ChatViewController: BaseMessageCellDelegate {

    @objc func actionButtonTapped(indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }
        let msg = dcContext.getMessage(id: messageIds[indexPath.row])
        if msg.downloadState != DC_DOWNLOAD_DONE {
            dcContext.downloadFullMessage(id: msg.id)
        } else {
            let fullMessageViewController = FullMessageViewController(dcContext: dcContext, messageId: msg.id)
            navigationController?.pushViewController(fullMessageViewController, animated: true)
        }
    }

    @objc func quoteTapped(indexPath: IndexPath) {
        if handleSelection(indexPath: indexPath) { return }
        _ = handleUIMenu()
        let msg = dcContext.getMessage(id: messageIds[indexPath.row])
        if let quoteMsg = msg.quoteMessage {
            if self.chatId == quoteMsg.chatId {
                scrollToMessage(msgId: quoteMsg.id)
            } else {
                showChat(chatId: quoteMsg.chatId, messageId: quoteMsg.id, animated: false)
            }
        }
    }

    @objc func textTapped(indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }

        let message = dcContext.getMessage(id: messageIds[indexPath.row])
        if message.isSetupMessage {
            didTapAsm(msg: message, orgText: "")
        }
    }

    @objc func phoneNumberTapped(number: String, indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }
        let sanitizedNumber = number.filter("0123456789".contains)
        if let phoneURL = URL(string: "tel://\(sanitizedNumber)") {
            UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
        }
        logger.debug("phone number tapped \(sanitizedNumber)")
    }

    @objc func commandTapped(command: String, indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }
        logger.debug("command tapped \(command)")
    }

    @objc func urlTapped(url: URL, indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }
        if Utils.isEmail(url: url) {
            logger.debug("tapped on contact")
            let email = Utils.getEmailFrom(url)
            self.askToChatWith(email: email)
        } else {
            UIApplication.shared.open(url)
        }
    }

    @objc func imageTapped(indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }
        showMediaGalleryFor(indexPath: indexPath)
    }

    @objc func avatarTapped(indexPath: IndexPath) {
        let message = dcContext.getMessage(id: messageIds[indexPath.row])
        let contactDetailController = ContactDetailViewController(dcContext: dcContext, contactId: message.fromContactId)
        navigationController?.pushViewController(contactDetailController, animated: true)
    }
}

// MARK: - MediaPickerDelegate
extension ChatViewController: MediaPickerDelegate {
    func onVideoSelected(url: NSURL) {
        stageVideo(url: url)
    }

    func onImageSelected(url: NSURL) {
        stageImage(url: url)
    }

    func onImageSelected(image: UIImage) {
        stageImage(image)
    }

    func onVoiceMessageRecorded(url: NSURL) {
        sendVoiceMessage(url: url)
    }

    func onDocumentSelected(url: NSURL) {
        stageDocument(url: url)
    }

}

// MARK: - MessageInputBarDelegate
extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        keepKeyboard = true
        let trimmedText = text.replacingOccurrences(of: "\u{FFFC}", with: "", options: .literal, range: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let filePath = draft.attachment, let viewType = draft.viewType {
            switch viewType {
            case DC_MSG_GIF, DC_MSG_IMAGE, DC_MSG_FILE, DC_MSG_VIDEO:
                self.sendAttachmentMessage(viewType: viewType, filePath: filePath, message: trimmedText, quoteMessage: draft.quoteMessage)
            default:
                logger.warning("Unsupported viewType for drafted messages.")
            }
        } else if inputBar.inputTextView.images.isEmpty {
            self.sendTextMessage(text: trimmedText, quoteMessage: draft.quoteMessage)
        } else {
            // only 1 attachment allowed for now, thus it takes the first one
            self.sendImage(inputBar.inputTextView.images[0], message: trimmedText)
        }
        inputBar.inputTextView.text = String()
        inputBar.inputTextView.attributedText = nil
        draftArea.cancel()
    }

    func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {
        draft.text = text
        evaluateInputBar(draft: draft)
    }

    func inputBar(_ inputBar: InputBarAccessoryView, didChangeIntrinsicContentTo size: CGSize) {
        if isDismissing {
            return
        }
        var bottomInsets = size.height + messageInputBar.keyboardHeight
        if UIApplication.shared.statusBarOrientation.isLandscape,
           let root = UIApplication.shared.keyWindow?.rootViewController {
            // in landscape we need to take safeAreaInsets into account, in portrait they're already part of the keyboard height
            bottomInsets += root.view.safeAreaInsets.bottom
        }
        self.tableView.contentInset = UIEdgeInsets(top: self.getTopInsetHeight(),
                                                   left: 0,
                                                   bottom: bottomInsets,
                                                   right: 0)
        if isLastRowVisible() && !tableView.isDragging && !tableView.isDecelerating  && highlightedMsg == nil && !ignoreInputBarChange {
            scrollToBottom()
        }
    }
}

// MARK: - DraftPreviewDelegate
extension ChatViewController: DraftPreviewDelegate {
    func onCancelQuote() {
        keepKeyboard = true
        draft.setQuote(quotedMsg: nil)
        configureDraftArea(draft: draft)
    }

    func onCancelAttachment() {
        keepKeyboard = true
        draft.setAttachment(viewType: nil, path: nil, mimetype: nil)
        configureDraftArea(draft: draft)
        evaluateInputBar(draft: draft)
    }

    func onAttachmentAdded() {
        evaluateInputBar(draft: draft)
    }

    func onAttachmentTapped() {
        if let attachmentPath = draft.attachment {
            let attachmentURL = URL(fileURLWithPath: attachmentPath, isDirectory: false)
            let previewController = PreviewController(dcContext: dcContext, type: .single(attachmentURL))
            if #available(iOS 13.0, *), draft.viewType == DC_MSG_IMAGE || draft.viewType == DC_MSG_VIDEO {
                previewController.setEditing(true, animated: true)
                previewController.delegate = self
            }
            let nav = UINavigationController(rootViewController: previewController)
            nav.modalPresentationStyle = .fullScreen
            navigationController?.present(nav, animated: true)
        }
    }
}

// MARK: - ChatEditingDelegate
extension ChatViewController: ChatEditingDelegate {
    func onDeletePressed() {
        if let rows = tableView.indexPathsForSelectedRows {
            let messageIdsToDelete = rows.compactMap { messageIds[$0.row] }
            askToDeleteMessages(ids: messageIdsToDelete)
        }
    }

    func onForwardPressed() {
        if let rows = tableView.indexPathsForSelectedRows {
            let messageIdsToForward = rows.compactMap { messageIds[$0.row] }
            RelayHelper.sharedInstance.setForwardMessages(messageIds: messageIdsToForward)
            self.navigationController?.popViewController(animated: true)
        }
    }

    func onCancelPressed() {
        setEditing(isEditing: false)
    }
}

// MARK: - ChatSearchDelegate
extension ChatViewController: ChatSearchDelegate {
    func onSearchPreviousPressed() {
        logger.debug("onSearch Previous Pressed")
        if searchResultIndex == 0 && !searchMessageIds.isEmpty {
            searchResultIndex = searchMessageIds.count - 1
        } else {
            searchResultIndex -= 1
        }
        scrollToMessage(msgId: searchMessageIds[searchResultIndex], animated: true, scrollToText: true)
        searchAccessoryBar.updateSearchResult(sum: self.searchMessageIds.count, position: searchResultIndex + 1)
        self.reloadData()
    }

    func onSearchNextPressed() {
        logger.debug("onSearch Next Pressed")
        if searchResultIndex == searchMessageIds.count - 1 {
            searchResultIndex = 0
        } else {
            searchResultIndex += 1
        }
        scrollToMessage(msgId: searchMessageIds[searchResultIndex], animated: true, scrollToText: true)
        searchAccessoryBar.updateSearchResult(sum: self.searchMessageIds.count, position: searchResultIndex + 1)
        self.reloadData()
    }
}

// MARK: UISearchResultUpdating
extension ChatViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        logger.debug("searchbar: \(String(describing: searchController.searchBar.text))")
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
            let searchText = searchController.searchBar.text ?? ""
            DispatchQueue.global(qos: .userInteractive).async {
                let resultIds = self.dcContext.searchMessages(chatId: self.chatId, searchText: searchText)
                DispatchQueue.main.async { [weak self] in

                guard let self = self else { return }
                    self.searchMessageIds = resultIds
                    self.searchResultIndex = self.searchMessageIds.isEmpty ? 0 : self.searchMessageIds.count - 1
                    self.searchAccessoryBar.isEnabled = !resultIds.isEmpty
                    self.searchAccessoryBar.updateSearchResult(sum: self.searchMessageIds.count, position: self.searchResultIndex + 1)

                    if let lastId = resultIds.last {
                        self.scrollToMessage(msgId: lastId, animated: true, scrollToText: true)
                    }
                    self.reloadData()
                }
            }
        }
    }
}

// MARK: - UISearchBarDelegate
extension ChatViewController: UISearchBarDelegate {

    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        configureDraftArea(draft: draft)
        return true
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        configureDraftArea(draft: draft)
        tableView.becomeFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchController.isActive = false
        configureDraftArea(draft: draft)
        tableView.becomeFirstResponder()
        navigationItem.searchController = nil
        reloadData()
    }
}

// MARK: - UISearchControllerDelegate
extension ChatViewController: UISearchControllerDelegate {
    func didPresentSearchController(_ searchController: UISearchController) {
        DispatchQueue.main.async { [weak self] in
            self?.searchController.searchBar.becomeFirstResponder()
        }
    }
}

// MARK: - ChatContactRequestBar
extension ChatViewController: ChatContactRequestDelegate {
    func onAcceptRequest() {
        dcContext.acceptChat(chatId: chatId)
        let chat = dcContext.getChat(chatId: chatId)
        if chat.isMailinglist {
            messageInputBar.isHidden = true
        } else {
            configureUIForWriting()
        }
    }

    func onBlockRequest() {
        dcContext.blockChat(chatId: chatId)
        self.navigationController?.popViewController(animated: true)
    }
    
    func onDeleteRequest() {
        self.askToDeleteChat()
    }
}

// MARK: - QLPreviewControllerDelegate
extension ChatViewController: QLPreviewControllerDelegate {
    @available(iOS 13.0, *)
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        return .updateContents
    }

    func previewController(_ controller: QLPreviewController, didUpdateContentsOf previewItem: QLPreviewItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.draftArea.reload(draft: self.draft)
        }
    }
}

// MARK: - AudioControllerDelegate
extension ChatViewController: AudioControllerDelegate {
    func onAudioPlayFailed() {
        let alert = UIAlertController(title: String.localized("error"),
                                      message: String.localized("cannot_play_unsupported_file_type"),
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: - UITextViewDelegate
extension ChatViewController: UITextViewDelegate {
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        if keepKeyboard {
            DispatchQueue.main.async { [weak self] in
                self?.messageInputBar.inputTextView.becomeFirstResponder()
            }
            keepKeyboard = false
            return false
        }
        return true
    }
}

// MARK: - ChatInputTextViewPasteDelegate
extension ChatViewController: ChatInputTextViewPasteDelegate {
    func onImagePasted(image: UIImage) {
        sendSticker(image)
    }
}
