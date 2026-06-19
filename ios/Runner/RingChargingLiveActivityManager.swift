import ActivityKit
import Foundation

@available(iOS 16.2, *)
enum RingChargingLiveActivityManager {
  private static var currentActivity: Activity<RingChargingAttributes>?

  static func sync(isCharging: Bool, battery: Int, ringName: String = "스마트링") {
    if isCharging {
      startOrUpdate(battery: battery, ringName: ringName)
    } else {
      endAll()
    }
  }

  private static func startOrUpdate(battery: Int, ringName: String) {
    let state = RingChargingAttributes.ContentState(battery: battery, isCharging: true)
    if let activity = currentActivity {
      Task {
        await activity.update(ActivityContent(state: state, staleDate: nil))
      }
      return
    }

    let auth = ActivityAuthorizationInfo()
    guard auth.areActivitiesEnabled else { return }

    let attributes = RingChargingAttributes(ringName: ringName)
    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: state, staleDate: nil),
        pushType: nil
      )
      currentActivity = activity
    } catch {
      NSLog("[RingChargingLiveActivity] request failed: \(error.localizedDescription)")
    }
  }

  static func endAll() {
    guard let activity = currentActivity else { return }
    let finalState = RingChargingAttributes.ContentState(
      battery: activity.content.state.battery,
      isCharging: false
    )
    Task {
      await activity.end(
        ActivityContent(state: finalState, staleDate: nil),
        dismissalPolicy: .default
      )
    }
    currentActivity = nil
  }
}
