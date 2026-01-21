import SwiftUI
import UserNotifications

struct ScoreView: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("المستوى \(store.level)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(store.totalXP) نقطة")
                        .foregroundColor(.secondary)
                }

                ProgressGraphCard(points: store.progressHistory)

                VStack(alignment: .leading, spacing: 8) {
                    Text("التقدم نحو المستوى التالي")
                        .font(.headline)
                    ProgressView(value: store.levelProgress)
                        .tint(AamalTheme.gold)
                    Text("تبقى \(store.xpToNextLevel) نقطة")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 6) {
                    Text("سلسلة الإنجاز")
                        .font(.headline)
                    Text("\(store.streak) أيام")
                        .font(.title3)
                        .foregroundColor(AamalTheme.emerald)
                }

                if !store.badges.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("الأوسمة")
                            .font(.headline)
                        ForEach(store.badges, id: \.self) { badge in
                            Text(badge)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AamalTheme.emerald.opacity(0.12))
                                .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: scheduleNotification) {
                    Text("تفعيل التذكيرات")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AamalTheme.emerald)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(AamalTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("التقدم")
    }


private struct ProgressGraphCard: View {
    let points: [ProgressPoint]

    private var lineColor: Color {
        guard points.count >= 2 else { return AamalTheme.emerald }
        let last = points[points.count - 1].value
        let previous = points[points.count - 2].value
        return last >= previous ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("منحنى التقدم")
                .font(.headline)

            GeometryReader { geometry in
                let values = points.map { $0.value }
                let maxValue = values.max() ?? 1
                let minValue = values.min() ?? 0
                let range = max(maxValue - minValue, 0.001)

                Path { path in
                    guard points.count > 1 else { return }

                    for index in points.indices {
                        let x = geometry.size.width * CGFloat(index) / CGFloat(points.count - 1)
                        let normalized = (points[index].value - minValue) / range
                        let y = geometry.size.height * (1 - CGFloat(normalized))

                        if index == points.startIndex {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.5))
                )
            }
            .frame(height: 140)

            Text(lineColor == .green ? "اتجاه صاعد" : "اتجاه هابط")
                .font(.caption)
                .foregroundColor(lineColor)
        }
        .aamalCard()
    }
}
    func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "حافظ على سلسلة الإنجاز"
                content.body = "لا تنسَ إكمال مهامك اليوم."
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true)
                let request = UNNotificationRequest(identifier: "taskReminder", content: content, trigger: trigger)

                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling notification: \(error.localizedDescription)")
                    }
                }
            } else {
                print("Notifications not granted")
            }
        }
    }
}