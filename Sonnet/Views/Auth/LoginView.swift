import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var viewModel: AuthViewModel

    init(authService: AuthService) {
        _viewModel = State(wrappedValue: AuthViewModel(authService: authService))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            VStack(spacing: SonnetDimens.spacingM) {
                Image(systemName: "book.pages")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(SonnetColors.ink)

                Text("Sonnet")
                    .font(SonnetTypography.largeTitle)
                    .foregroundStyle(SonnetColors.textTitle)

                Text("十四行诗 · 记下生活每一笔")
                    .font(SonnetTypography.subheadline)
                    .foregroundStyle(SonnetColors.textCaption)
            }

            Spacer()

            // 登录区
            VStack(spacing: SonnetDimens.spacingM) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        if let cred = auth.credential as? ASAuthorizationAppleIDCredential {
                            viewModel.authService.signInWithApple(credential: cred)
                        }
                    case .failure:
                        break
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium))

                Button {
                    viewModel.continueAsGuest()
                } label: {
                    Text("游客模式继续")
                        .font(SonnetTypography.subheadline)
                        .foregroundStyle(SonnetColors.textCaption)
                        .underline()
                }
            }
            .padding(.horizontal, SonnetDimens.spacingXXL)
            .padding(.bottom, 48)
        }
        .background(SonnetColors.paper)
    }
}
