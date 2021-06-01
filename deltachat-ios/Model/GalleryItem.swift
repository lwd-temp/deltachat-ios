import UIKit
import DcCore
import SDWebImage

class GalleryItem: ContextMenuItem {

    var onImageLoaded: ((UIImage?) -> Void)?

    var msg: DcMsg

    var fileUrl: URL? {
        return msg.fileURL
    }

    var thumbnailImage: UIImage? {
        willSet {
            onImageLoaded?(newValue)
        }
    }

    var showPlayButton: Bool {
        switch msg.viewtype {
        case .video:
            return true
        default:
            return false
        }
    }

    init(msgId: Int) {
        self.msg = DcMsg(id: msgId)

        if let key = msg.fileURL?.absoluteString, let image = ThumbnailCache.shared.restoreImage(key: key) {
            self.thumbnailImage = image
        } else {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard let viewtype = msg.viewtype, let url = msg.fileURL else {
            return
        }
        switch viewtype {
        case .image:
            if url.pathExtension == "webp" {
                loadAsyncSDImageThumbnail(from: url)
            } else {
                loadAsyncUIImageThumbnail(from: url)
            }
        case .video:
            loadVideoThumbnail(from: url)
        case .gif:
            loadAsyncSDImageThumbnail(from: url)
        default:
            safe_fatalError("unsupported viewtype - viewtype \(viewtype) not supported.")
        }
    }

    private func loadAsyncUIImageThumbnail(from url: URL) {
        DispatchQueue.global(qos: .userInteractive).async {
            guard let imageData = try? Data(contentsOf: url) else {
                return
            }
            let image = UIImage(data: imageData)
            DispatchQueue.main.async { [weak self] in
                    self?.thumbnailImage = image
            }
        }
    }

    private func loadAsyncSDImageThumbnail(from url: URL) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let image = SDAnimatedImage(contentsOfFile: url.path)
            DispatchQueue.main.async { [weak self] in
                    self?.thumbnailImage = image
            }
        }
    }

    private func loadVideoThumbnail(from url: URL) {
        DispatchQueue.global(qos: .userInteractive).async {
            let thumbnailImage = DcUtils.generateThumbnailFromVideo(url: url)
            DispatchQueue.main.async { [weak self] in
                self?.thumbnailImage = thumbnailImage
                if let image = thumbnailImage {
                    ThumbnailCache.shared.storeImage(image: image, key: url.absoluteString)
                }
            }
        }
    }
}
