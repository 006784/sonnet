import SwiftUI

struct ProfileView: View {
    let profile: UserProfile
    let onSignOut: () -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: SonnetDimens.spacingL) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(SonnetColors.inkPale)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(SonnetTypography.title3)
                            .foregroundStyle(SonnetColors.textTitle)
                        if let email = profile.email {
                            Text(email)
                                .font(SonnetTypography.caption1)
                                .foregroundStyle(SonnetColors.textCaption)
                        }
                        Text(profile.loginMethod == .apple ? "Apple ID 登录" : "游客模式")
                            .font(SonnetTypography.caption2)
                            .foregroundStyle(SonnetColors.textHint)
                    }
                }
                .padding(.vertical, SonnetDimens.spacingS)
            }

            Section {
                Button(role: .destructive, action: onSignOut) {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("个人信息")
        .navigationBarTitleDisplayMode(.inline)
    }
}
