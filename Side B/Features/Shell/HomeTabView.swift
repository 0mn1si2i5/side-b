import SwiftUI

struct HomeTabView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Side B")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("跨平台音乐分享，让朋友听到你喜欢的歌")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .navigationTitle("首页")
    }
}
