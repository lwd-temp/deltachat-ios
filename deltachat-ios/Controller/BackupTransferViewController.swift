import Foundation
import UIKit
import DcCore
import SDWebImageSVGKitPlugin

class BackupTransferViewController: UIViewController {

    private let dcContext: DcContext
    private let dcAccounts: DcAccounts
    private var dcBackupProvider: DcBackupProvider?

    private lazy var qrContentView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        view.accessibilityHint = String.localized("scan_to_transfer")
        return view
    }()

    private lazy var progressContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        view.layer.borderColor = DcColors.grey50.cgColor
        view.layer.borderWidth = 1
        view.backgroundColor = DcColors.defaultInverseColor.withAlphaComponent(0.5)
        return view
    }()

    private lazy var progress: UIActivityIndicatorView = {
        let progress = UIActivityIndicatorView(style: .white)
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()

    private lazy var blurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .light)
        let view = UIVisualEffectView(effect: blurEffect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("add_another_device")
        setupSubviews()
        // TODO: add some more hints about what is going on

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.dcAccounts.stopIo()
            self.dcBackupProvider = DcBackupProvider(self.dcContext)
            DispatchQueue.main.async {
                let image = self.getQrImage(svg: self.dcBackupProvider?.getQrSvg())
                self.qrContentView.image = image
                self.progress.stopAnimating()
                self.progressContainer.isHidden = true
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    self.dcBackupProvider?.wait()
                    // TODO: track events and show transfer progress
                    // TODO: once the QR code is scanned, it can disappear from the screen
                }
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        // TODO: this is too harsh, aborting should be done only when the user actively quits the viewController
        if dcBackupProvider != nil {
            dcContext.stopOngoingProcess()
            dcBackupProvider = nil
        }
        dcAccounts.startIo()
    }

    // MARK: - setup
    private func setupSubviews() {
        view.addSubview(qrContentView)
        view.addSubview(progressContainer)
        progressContainer.addSubview(blurView)
        progressContainer.addSubview(progress)
        let qrDefaultWidth = qrContentView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.75)
        qrDefaultWidth.priority = UILayoutPriority(500)
        qrDefaultWidth.isActive = true
        let qrMinWidth = qrContentView.widthAnchor.constraint(lessThanOrEqualToConstant: 260)
        qrMinWidth.priority = UILayoutPriority(999)
        qrMinWidth.isActive = true
        view.addConstraints([
            qrContentView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 1.05),
            qrContentView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            qrContentView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            progressContainer.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            progressContainer.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            progressContainer.constraintHeightTo(100),
            progressContainer.constraintWidthTo(100),
            progress.constraintCenterXTo(progressContainer),
            progress.constraintCenterYTo(progressContainer)
        ])
        blurView.fillSuperview()
        progressContainer.isHidden = false
        progress.startAnimating()
        view.backgroundColor = DcColors.defaultBackgroundColor
    }
    
    private func getQrImage(svg: String?) -> UIImage? {
        if let svg = svg {
            let svgData = svg.data(using: .utf8)
            return SDImageSVGKCoder.shared.decodedImage(with: svgData, options: [:])
        }
        return nil
    }

}


/// Does a best effort attempt to trigger the local network privacy alert.
///
/// It works by sending a UDP datagram to the discard service (port 9) of every
/// IP address associated with a broadcast-capable interface. This should
/// trigger the local network privacy alert, assuming the alert hasn’t already
/// been displayed for this app.
///
/// This code takes a ‘best effort’. It handles errors by ignoring them. As
/// such, there’s guarantee that it’ll actually trigger the alert.
///
/// - note: iOS devices don’t actually run the discard service. I’m using it
/// here because I need a port to send the UDP datagram to and port 9 is
/// always going to be safe (either the discard service is running, in which
/// case it will discard the datagram, or it’s not, in which case the TCP/IP
/// stack will discard it).
///
/// There should be a proper API for this (r. 69157424).
///
/// For more background on this, see [Triggering the Local Network Privacy Alert](https://developer.apple.com/forums/thread/663768).
/// [via https://developer.apple.com/forums/thread/663768 ]
func triggerLocalNetworkPrivacyAlert() {
    let sock4 = socket(AF_INET, SOCK_DGRAM, 0)
    guard sock4 >= 0 else { return }
    defer { close(sock4) }
    let sock6 = socket(AF_INET6, SOCK_DGRAM, 0)
    guard sock6 >= 0 else { return }
    defer { close(sock6) }

    let addresses = addressesOfDiscardServiceOnBroadcastCapableInterfaces()
    var message = [UInt8]("!".utf8)
    for address in addresses {
        address.withUnsafeBytes { buf in
            let sa = buf.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            let saLen = socklen_t(buf.count)
            let sock = sa.pointee.sa_family == AF_INET ? sock4 : sock6
            _ = sendto(sock, &message, message.count, MSG_DONTWAIT, sa, saLen)
        }
    }
}

/// Returns the addresses of the discard service (port 9) on every
/// broadcast-capable interface.
///
/// Each array entry is contains either a `sockaddr_in` or `sockaddr_in6`.
private func addressesOfDiscardServiceOnBroadcastCapableInterfaces() -> [Data] {
    var addrList: UnsafeMutablePointer<ifaddrs>?
    let err = getifaddrs(&addrList)
    guard err == 0, let start = addrList else { return [] }
    defer { freeifaddrs(start) }
    return sequence(first: start, next: { $0.pointee.ifa_next })
        .compactMap { i -> Data? in
            guard
                (i.pointee.ifa_flags & UInt32(bitPattern: IFF_BROADCAST)) != 0,
                let sa = i.pointee.ifa_addr
            else { return nil }
            var result = Data(UnsafeRawBufferPointer(start: sa, count: Int(sa.pointee.sa_len)))
            switch CInt(sa.pointee.sa_family) {
            case AF_INET:
                result.withUnsafeMutableBytes { buf in
                    let sin = buf.baseAddress!.assumingMemoryBound(to: sockaddr_in.self)
                    sin.pointee.sin_port = UInt16(9).bigEndian
                }
            case AF_INET6:
                result.withUnsafeMutableBytes { buf in
                    let sin6 = buf.baseAddress!.assumingMemoryBound(to: sockaddr_in6.self)
                    sin6.pointee.sin6_port = UInt16(9).bigEndian
                }
            default:
                return nil
            }
            return result
        }
}
