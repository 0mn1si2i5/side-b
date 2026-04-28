import SwiftUI
import UIKit

@MainActor
private final class ArtworkImageMemoryCache {
    static let shared = ArtworkImageMemoryCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 160
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

struct CachedArtworkImage: View {
    let url: URL?
    var placeholderFontSize: CGFloat = 24

    @State private var image: UIImage?
    @State private var loadedURL: URL?

    var body: some View {
        Group {
            if let image, loadedURL == url {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: placeholderFontSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
        .clipped()
    }

    private func loadImage() async {
        guard let url else {
            image = nil
            loadedURL = nil
            return
        }

        if let cachedImage = ArtworkImageMemoryCache.shared.image(for: url) {
            image = cachedImage
            loadedURL = url
            return
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 20

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let loadedImage = UIImage(data: data) else { return }

            ArtworkImageMemoryCache.shared.insert(loadedImage, for: url)
            image = loadedImage
            loadedURL = url
        } catch {
            image = nil
            loadedURL = nil
        }
    }
}
