import SwiftUI
import AuthenticationServices

@Observable
final class AuthViewModel: NSObject {
    var isLoading: Bool = false
    var error: String?

    var authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    func continueAsGuest() {
        authService.continueAsGuest()
    }
}

extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            authService.signInWithApple(credential: credential)
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        self.error = error.localizedDescription
    }
}
