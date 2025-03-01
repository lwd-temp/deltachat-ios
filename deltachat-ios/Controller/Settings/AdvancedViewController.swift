import UIKit
import DcCore
import Intents

internal final class AdvancedViewController: UITableViewController, ProgressAlertHandler {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case autocryptPreferences
        case sendAutocryptMessage
        case manageKeys
        case experimentalFeatures
        case videoChat
        case viewLog
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts

    private let externalPathDescr = "File Sharing/Delta Chat"

    // MARK: - ProgressAlertHandler
    weak var progressAlert: UIAlertController?
    var progressObserver: NSObjectProtocol?

    // MARK: - cells
    private lazy var autocryptSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = dcContext.e2eeEnabled
        switchControl.addTarget(self, action: #selector(handleAutocryptPreferencesToggle(_:)), for: .valueChanged)
        return switchControl
    }()

    private lazy var autocryptPreferencesCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.autocryptPreferences.rawValue
        cell.textLabel?.text = String.localized("autocrypt_prefer_e2ee")
        cell.accessoryView = autocryptSwitch
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var sendAutocryptMessageCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.sendAutocryptMessage.rawValue
        cell.actionTitle = String.localized("autocrypt_send_asm_title")
        return cell
    }()

    private lazy var manageKeysCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.manageKeys.rawValue
        cell.actionTitle = String.localized("pref_manage_keys")
        return cell
    }()

    lazy var sentboxWatchCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_watch_sent_folder"),
            on: dcContext.getConfigBool("sentbox_watch"),
            action: { cell in
                self.dcAccounts.stopIo()
                self.dcContext.setConfigBool("sentbox_watch", cell.isOn)
                self.dcAccounts.startIo()
        })
    }()

    lazy var sendCopyToSelfCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_send_copy_to_self"),
            on: dcContext.getConfigBool("bcc_self"),
            action: { cell in
                self.dcContext.setConfigBool("bcc_self", cell.isOn)
        })
    }()

    lazy var mvboxMoveCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_auto_folder_moves"),
            on: dcContext.getConfigBool("mvbox_move"),
            action: { cell in
                self.dcAccounts.stopIo()
                self.dcContext.setConfigBool("mvbox_move", cell.isOn)
                self.dcAccounts.startIo()
        })
    }()

    lazy var onlyFetchMvboxCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_only_fetch_mvbox_title"),
            on: dcContext.getConfigBool("only_fetch_mvbox"),
            action: { cell in
                if cell.isOn {
                    let alert = UIAlertController(title: String.localized("pref_only_fetch_mvbox_title"),
                        message: String.localized("pref_imap_folder_warn_disable_defaults"),
                        preferredStyle: .safeActionSheet)
                    alert.addAction(UIAlertAction(title: String.localized("perm_continue"), style: .destructive, handler: { _ in
                        self.dcAccounts.stopIo()
                        self.dcContext.setConfigBool("only_fetch_mvbox", true)
                        self.dcAccounts.startIo()
                    }))
                    alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
                        cell.uiSwitch.setOn(false, animated: true)
                    }))
                    self.navigationController?.present(alert, animated: true, completion: nil)
                } else {
                    self.dcAccounts.stopIo()
                    self.dcContext.setConfigBool("only_fetch_mvbox", false)
                    self.dcAccounts.startIo()
                }
        })
    }()

    private lazy var experimentalFeaturesCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.experimentalFeatures.rawValue
        cell.actionTitle = String.localized("pref_experimental_features")
        return cell
    }()

    private lazy var videoChatInstanceCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.videoChat.rawValue
        cell.textLabel?.text = String.localized("videochat_instance")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var viewLogCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.viewLog.rawValue
        cell.textLabel?.text = String.localized("pref_view_log")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        let autocryptSection = SectionConfigs(
            headerTitle: String.localized("autocrypt"),
            footerTitle: String.localized("autocrypt_explain"),
            cells: [autocryptPreferencesCell, manageKeysCell, sendAutocryptMessageCell]
        )
        let folderSection = SectionConfigs(
            headerTitle: String.localized("pref_imap_folder_handling"),
            footerTitle: String.localized("pref_only_fetch_mvbox_explain"),
            cells: [sentboxWatchCell, sendCopyToSelfCell, mvboxMoveCell, onlyFetchMvboxCell])
        let miscSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: nil,
            cells: [experimentalFeaturesCell, videoChatInstanceCell])
        let viewLogSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: nil,
            cells: [viewLogCell])
        return [autocryptSection, folderSection, miscSection, viewLogSection]
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        self.dcAccounts = dcAccounts
        super.init(style: .grouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_advanced")
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateCells()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addProgressAlertListener(dcAccounts: dcAccounts, progressName: dcNotificationImexProgress) { [weak self] in
            guard let self = self else { return }
            self.progressAlert?.dismiss(animated: true)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let nc = NotificationCenter.default
        if let backupProgressObserver = self.progressObserver {
            nc.removeObserver(backupProgressObserver)
        }
    }

    // MARK: - UITableViewDelegate + UITableViewDatasource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath), let cellTag = CellTags(rawValue: cell.tag) else {
            safe_fatalError()
            return
        }
        tableView.deselectRow(at: indexPath, animated: false)

        switch cellTag {
        case .autocryptPreferences: break
        case .sendAutocryptMessage: sendAutocryptSetupMessage()
        case .manageKeys: showManageKeysDialog()
        case .experimentalFeatures: showExperimentalDialog()
        case .videoChat: showVideoChatInstance()
        case .viewLog: showLogViewController()
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }

    // MARK: - actions
    @objc private func handleAutocryptPreferencesToggle(_ sender: UISwitch) {
        dcContext.e2eeEnabled = sender.isOn
    }

    private func sendAutocryptSetupMessage() {
        let askAlert = UIAlertController(title: String.localized("autocrypt_send_asm_explain_before"), message: nil, preferredStyle: .safeActionSheet)
        askAlert.addAction(UIAlertAction(title: String.localized("autocrypt_send_asm_title"), style: .default, handler: { _ in
                let sc = self.dcContext.initiateKeyTransfer()
                guard var sc = sc else {
                    return
                }
                if sc.count == 44 {
                    // format setup code to the typical 3 x 3 numbers
                    sc = sc.substring(0, 4) + "  -  " + sc.substring(5, 9) + "  -  " + sc.substring(10, 14) + "  -\n\n" +
                        sc.substring(15, 19) + "  -  " + sc.substring(20, 24) + "  -  " + sc.substring(25, 29) + "  -\n\n" +
                        sc.substring(30, 34) + "  -  " + sc.substring(35, 39) + "  -  " + sc.substring(40, 44)
                }

                let text = String.localized("autocrypt_send_asm_explain_after") + "\n\n" + sc
                let showAlert = UIAlertController(title: text, message: nil, preferredStyle: .alert)
                showAlert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                self.present(showAlert, animated: true, completion: nil)
        }))
        askAlert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(askAlert, animated: true, completion: nil)
    }

    private func showLogViewController() {
        let controller = LogViewController(dcContext: dcContext)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showExperimentalDialog() {
        let alert = UIAlertController(title: String.localized("pref_experimental_features"), message: nil, preferredStyle: .safeActionSheet)

        let broadcastLists = UserDefaults.standard.bool(forKey: "broadcast_lists")
        alert.addAction(UIAlertAction(title: (broadcastLists ? "✔︎ " : "") + String.localized("broadcast_lists"),
                                      style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            UserDefaults.standard.set(!broadcastLists, forKey: "broadcast_lists")
            if !broadcastLists {
                let alert = UIAlertController(title: "Thanks for trying out the experimental feature 🧪 \"Broadcast Lists\"!",
                                              message: "You can now create new \"Broadcast Lists\" from the \"New Chat\" dialog\n\n"
                                                + "In case you are using more than one device, broadcast lists are currently not synced between them\n\n"
                                                + "If you want to quit the experimental feature, you can disable it at \"Settings / Advanced\".",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                self.navigationController?.present(alert, animated: true, completion: nil)
            }
        }))

        let locationStreaming = UserDefaults.standard.bool(forKey: "location_streaming")
        let title = (locationStreaming ? "✔︎ " : "") + String.localized("pref_on_demand_location_streaming")
        alert.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            UserDefaults.standard.set(!locationStreaming, forKey: "location_streaming")
            if !locationStreaming {
                let alert = UIAlertController(title: "Thanks for trying out the experimental feature 🧪 \"Location streaming\"",
                                              message: "You will find a corresponding option in the attach menu (the paper clip) of each chat now.\n\n"
                                                + "If you want to quit the experimental feature, you can disable it at \"Settings / Advanced\".",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                self.navigationController?.present(alert, animated: true, completion: nil)
            } else if self.dcContext.isSendingLocationsToChat(chatId: 0) {
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                    return
                }
                appDelegate.locationManager.disableLocationStreamingInAllChats()
            }
        }))

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func showManageKeysDialog() {
        let alert = UIAlertController(title: String.localized("pref_manage_keys"), message: nil, preferredStyle: .safeActionSheet)

        alert.addAction(UIAlertAction(title: String.localized("pref_managekeys_export_secret_keys"), style: .default, handler: { _ in
            let msg = String.localizedStringWithFormat(String.localized("pref_managekeys_export_explain"), self.externalPathDescr)
            let alert = UIAlertController(title: String.localized("pref_managekeys_export_secret_keys"), message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                self.startImex(what: DC_IMEX_EXPORT_SELF_KEYS)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }))

        alert.addAction(UIAlertAction(title: String.localized("pref_managekeys_import_secret_keys"), style: .default, handler: { _ in
            let msg = String.localizedStringWithFormat(String.localized("pref_managekeys_import_explain"), self.externalPathDescr)
            let alert = UIAlertController(title: String.localized("pref_managekeys_import_secret_keys"), message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                self.startImex(what: DC_IMEX_IMPORT_SELF_KEYS)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }))

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func presentError(message: String) {
        let error = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        error.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel))
        present(error, animated: true)
    }

    private func startImex(what: Int32, passphrase: String? = nil) {
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if !documents.isEmpty {
            showProgressAlert(title: String.localized(what==DC_IMEX_IMPORT_SELF_KEYS ? "pref_managekeys_import_secret_keys" : "pref_managekeys_export_secret_keys"), dcContext: dcContext)
            DispatchQueue.main.async {
                self.dcAccounts.stopIo()
                self.dcContext.imex(what: what, directory: documents[0], passphrase: passphrase)
            }
        } else {
            logger.error("document directory not found")
        }
    }

    // MARK: - updates
    private func updateCells() {
        videoChatInstanceCell.detailTextLabel?.text = VideoChatInstanceViewController.getValString(val: dcContext.getConfig("webrtc_instance") ?? "")
    }

    // MARK: - coordinator
    private func showVideoChatInstance() {
        let videoInstanceController = VideoChatInstanceViewController(dcContext: dcContext)
        navigationController?.pushViewController(videoInstanceController, animated: true)
    }
}
