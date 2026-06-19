import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct RingChargingLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RingChargingAttributes.self) { context in
      HStack(spacing: 8) {
        Image(systemName: "bolt.fill")
          .foregroundStyle(.green)
        VStack(alignment: .leading, spacing: 2) {
          Text(context.attributes.ringName)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("충전 중 · \(context.state.battery)%")
            .font(.headline)
        }
      }
      .padding(.horizontal, 12)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "bolt.circle.fill")
            .foregroundStyle(.green)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("\(context.state.battery)%")
            .font(.title2)
            .bold()
        }
        DynamicIslandExpandedRegion(.center) {
          Text("충전 중")
        }
      } compactLeading: {
        Image(systemName: "bolt.fill")
          .foregroundStyle(.green)
      } compactTrailing: {
        Text("\(context.state.battery)%")
          .font(.caption2)
      } minimal: {
        Image(systemName: "bolt.fill")
          .foregroundStyle(.green)
      }
    }
  }
}

@available(iOS 16.2, *)
@main
struct RingChargingWidgetBundle: WidgetBundle {
  var body: some Widget {
    RingChargingLiveActivityWidget()
  }
}
