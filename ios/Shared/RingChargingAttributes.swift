import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct RingChargingAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var battery: Int
    var isCharging: Bool
  }

  var ringName: String
}
