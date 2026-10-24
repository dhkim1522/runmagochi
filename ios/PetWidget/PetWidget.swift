// 홈 화면 위젯(iOS, F29, 결정 0037). 앱이 그려 App Group 에 둔 그림(pet_image)을 보여 준다.
// Xcode 에서 Widget Extension 타깃으로 연결해야 빌드된다: ios/PetWidget/README.md.
import SwiftUI
import WidgetKit

private let appGroup = "group.com.dhkim1522.runmagochi"

struct PetEntry: TimelineEntry {
    let date: Date
    let image: UIImage?
}

struct PetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry { PetEntry(date: Date(), image: nil) }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        // 그림은 앱이 바뀔 때마다 다시 그려 보내고 reloadAllTimelines 로 갱신한다.
        completion(Timeline(entries: [load()], policy: .never))
    }

    private func load() -> PetEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        let path = defaults?.string(forKey: "pet_image")
        let image = path.flatMap { UIImage(contentsOfFile: $0) }
        return PetEntry(date: Date(), image: image)
    }
}

struct PetWidgetView: View {
    let entry: PetEntry

    var body: some View {
        if let image = entry.image {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Text("런마고치").font(.headline)
        }
    }
}

struct PetWidget: Widget {
    // 앱(Dart)의 petWidgetIosName 과 같아야 한다.
    let kind = "PetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetProvider()) { entry in
            if #available(iOS 17.0, *) {
                PetWidgetView(entry: entry).containerBackground(.clear, for: .widget)
            } else {
                PetWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("런마고치")
        .description("캐릭터와 다음 레벨까지 거리를 홈 화면에서 봐요")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct PetWidgetBundle: WidgetBundle {
    var body: some Widget { PetWidget() }
}
