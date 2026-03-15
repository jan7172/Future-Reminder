import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.blue.gradient)
                    .frame(width: 100, height: 100)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 32)

            // Title
            Text("Future Reminder")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 8)

            Text("Reminders that trigger when\nyou arrive – not just at a fixed time.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 48)

            // Features
            VStack(spacing: 24) {
                OnboardingFeatureRow(
                    icon: "mappin.and.ellipse",
                    color: .blue,
                    title: "Location Triggers",
                    description: "Set any place as a trigger for your reminder."
                )
                OnboardingFeatureRow(
                    icon: "bell.fill",
                    color: .orange,
                    title: "Automatic Notifications",
                    description: "Get notified the moment you arrive."
                )
                OnboardingFeatureRow(
                    icon: "lock.fill",
                    color: .green,
                    title: "100% Private",
                    description: "All data stays on your device. No cloud, no tracking."
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Button
            Button {
                hasSeenOnboarding = true
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
