import SwiftUI

/// Simple NSCache-based image cache for scroll performance.
/// Avoids re-decoding image data on every cell reuse.
final class ImageCacheService {
    static let shared = ImageCacheService()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

/// A cached async image view that uses ImageCacheService.
struct CachedAsyncImage: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
            } else {
                Color.gatherSecondaryBackground
                    .overlay {
                        ProgressView()
                            .tint(Color.gatherSecondaryText)
                    }
                    .task {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        // Check cache first
        if let cached = ImageCacheService.shared.image(for: url) {
            self.image = cached
            return
        }

        // Download
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }
            ImageCacheService.shared.setImage(uiImage, for: url)
            await MainActor.run {
                self.image = uiImage
            }
        } catch {
            // Silently fail — placeholder remains visible
        }
    }
}
