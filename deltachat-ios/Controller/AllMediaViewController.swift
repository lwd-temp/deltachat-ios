import UIKit
import DcCore

class AllMediaViewController: UIPageViewController {
    private let dcContext: DcContext
    private var selectedIndex: Int = 0

    private lazy var segmentControl: UISegmentedControl = {
        let control = UISegmentedControl(
            items: [String.localized("images_and_videos"),
                    dcContext.hasWebxdc(chatId: 0) ? String.localized("files_and_webxdx_apps") : String.localized("files")]
        )
        control.tintColor = DcColors.primary
        control.addTarget(self, action: #selector(segmentControlChanged), for: .valueChanged)
        control.selectedSegmentIndex = 0
        return control
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        navigationItem.titleView = segmentControl

        setViewControllers(
            [makeGalleryViewController()],
            direction: .forward,
            animated: true,
            completion: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        // viewWillAppear() is on called on section change, not on main-tab change
        super.viewWillAppear(animated)

    }

    override func viewWillDisappear(_ animated: Bool) {
        // viewWillDisappear() is on called on section change, not on main-tab change
        super.viewWillDisappear(animated)
    }

    // MARK: - actions
    @objc private func segmentControlChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            setViewControllers([makeGalleryViewController()], direction: .reverse, animated: true, completion: nil)
        } else {
            setViewControllers([makeFilesViewController()], direction: .forward, animated: true, completion: nil)
        }
    }

    // MARK: - factory
    private func makeGalleryViewController() -> UIViewController {
        let allMedia = dcContext.getChatMedia(chatId: 0, messageType: DC_MSG_IMAGE, messageType2: DC_MSG_GIF, messageType3: DC_MSG_VIDEO)
        return GalleryViewController(context: dcContext, chatId: 0, mediaMessageIds: allMedia.reversed())
    }

    private func makeFilesViewController() -> UIViewController {
        let allMedia = dcContext.getChatMedia(chatId: 0, messageType: DC_MSG_FILE, messageType2: DC_MSG_AUDIO, messageType3: DC_MSG_WEBXDC)
        return DocumentGalleryController(context: dcContext, chatId: 0, fileMessageIds: allMedia.reversed(), hasWebxdc: false)
    }
}

// MARK: - UIPageViewControllerDataSource, UIPageViewControllerDelegate
extension AllMediaViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController is GalleryViewController {
            return nil
        }
        return makeGalleryViewController()
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if viewController is GalleryViewController {
            return makeFilesViewController()
        }
        return nil
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            if previousViewControllers.first is GalleryViewController {
                segmentControl.selectedSegmentIndex = 1
            } else {
                segmentControl.selectedSegmentIndex = 0
            }
        }
    }
}
