import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.blue.gradient)
                    .frame(width: 100, height: 100)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 32)

            Text(String(localized: "future_reminder"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 8)

            Text(String(localized: "onboarding_subtitle"))
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 48)

            VStack(spacing: 24) {
                OnboardingFeatureRow(
                    icon: "mappin.and.ellipse",
                    color: .blue,
                    title: String(localized: "onboarding_feature_location_title"),
                    description: String(localized: "onboarding_feature_location_description")
                )
                OnboardingFeatureRow(
                    icon: "bell.fill",
                    color: .orange,
                    title: String(localized: "onboarding_feature_notification_title"),
                    description: String(localized: "onboarding_feature_notification_description")
                )
                OnboardingFeatureRow(
                    icon: "lock.fill",
                    color: .green,
                    title: String(localized: "onboarding_feature_privacy_title"),
                    description: String(localized: "onboarding_feature_privacy_description")
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                hasSeenOnboarding = true
            } label: {
                Text(String(localized: "get_started"))
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
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
