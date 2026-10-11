import ActivityKit
import SwiftUI
import WidgetKit

@main
struct NexRondaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ConvoyLiveActivityWidget()
    }
}

// Live Activities pipe required by live_activities plugin
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState
    public struct ContentState: Codable, Hashable {
        var appGroupId: String?
        var updateId: Double?
    }
    var id: UUID = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

let sharedDefault = UserDefaults(suiteName: "group.com.nexkod.nexronda")

struct ConvoyLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            let defaults = sharedDefault ?? UserDefaults.standard
            let roomName = defaults.string(forKey: context.attributes.prefixedKey("roomName")) ?? "Convoy Ride"
            let activeSpeaker = defaults.string(forKey: context.attributes.prefixedKey("activeSpeaker")) ?? ""
            let isMuted = defaults.bool(forKey: context.attributes.prefixedKey("isMuted"))
            let isSos = defaults.bool(forKey: context.attributes.prefixedKey("isSos"))
            
            return DynamicIsland {
                // Expanded Dynamic Island (When user holds/long-presses the Dynamic Island)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "motorcycle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isSos ? .red : Color(red: 0/255, green: 168/255, blue: 204/255))
                        Text(roomName)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 6) {
                        if isMuted {
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        }
                    }
                    .padding(.trailing, 8)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if isSos {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.white)
                                Text("SOS EMERGENCY ALERT")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(8)
                        } else if !activeSpeaker.isEmpty {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Speaking: \(activeSpeaker)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        } else {
                            Text("Intercom Active • Ready to talk")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text("Tap to return")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact Dynamic Island Leading Pill
                Image(systemName: "motorcycle")
                    .foregroundColor(isSos ? .red : Color(red: 0/255, green: 168/255, blue: 204/255))
                    .font(.system(size: 12, weight: .bold))
            } compactTrailing: {
                // Compact Dynamic Island Trailing Pill
                if isSos {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 11))
                } else if !activeSpeaker.isEmpty {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                        .font(.system(size: 11, weight: .bold))
                } else if isMuted {
                    Image(systemName: "mic.slash.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 11))
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .font(.system(size: 11))
                }
            } minimal: {
                Image(systemName: "motorcycle")
                    .foregroundColor(isSos ? .red : Color(red: 0/255, green: 168/255, blue: 204/255))
            }
        }
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let defaults = sharedDefault ?? UserDefaults.standard
        let roomName = defaults.string(forKey: context.attributes.prefixedKey("roomName")) ?? "Convoy Ride"
        let activeSpeaker = defaults.string(forKey: context.attributes.prefixedKey("activeSpeaker")) ?? ""
        let isMuted = defaults.bool(forKey: context.attributes.prefixedKey("isMuted"))
        let isSos = defaults.bool(forKey: context.attributes.prefixedKey("isSos"))
        
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSos ? Color.red : Color(red: 30/255, green: 41/255, blue: 59/255))
                    .frame(width: 44, height: 44)
                Image(systemName: isSos ? "exclamationmark.triangle.fill" : "motorcycle")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(roomName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                if isSos {
                    Text("EMERGENCY SOS ACTIVE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                } else if !activeSpeaker.isEmpty {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Speaking: \(activeSpeaker)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                } else {
                    Text(isMuted ? "Muted" : "Voice Intercom Connected")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .foregroundColor(isMuted ? .red : Color(red: 16/255, green: 185/255, blue: 129/255))
                    .font(.system(size: 18))
            }
        }
        .padding(14)
        .background(Color(red: 15/255, green: 23/255, blue: 42/255))
    }
}
