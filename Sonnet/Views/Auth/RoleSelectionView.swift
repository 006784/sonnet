import SwiftUI
import SwiftData

struct RoleSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(DataService.self) private var dataService

    var onComplete: (() -> Void)? = nil

    @State private var selectedRole: UserRole? = nil
    @State private var appeared = false

    var body: some View {
        ZStack {
            SonnetColors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── 顶部文案 ──────────────────────────────────
                VStack(spacing: SonnetDimens.spacingS) {
                    Text(onComplete == nil ? "切换你的身份" : "选择你的身份")
                        .font(SonnetTypography.title2)
                        .foregroundStyle(SonnetColors.ink)

                    Text(onComplete == nil ? "新的角色会影响首页结构与功能入口" : "我们会为你定制专属功能")
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textCaption)
                }
                .padding(.top, 56)
                .padding(.bottom, SonnetDimens.spacingXXL)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -12)

                // ── 角色卡片列表 ──────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: SonnetDimens.spacingM) {
                        ForEach(Array(UserRole.allCases.enumerated()), id: \.offset) { idx, role in
                            roleCard(role)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 24)
                                .animation(
                                    SonnetMotion.spring.delay(Double(idx) * 0.07),
                                    value: appeared
                                )
                        }
                    }
                    .padding(.horizontal, SonnetDimens.spacingXL)
                    .padding(.bottom, 120)
                }

                Spacer(minLength: 0)
            }

            // ── 底部按钮 ──────────────────────────────────────
            VStack {
                Spacer()
                confirmButton
                    .padding(.horizontal, SonnetDimens.spacingXXL)
                    .padding(.bottom, 48)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            selectedRole = appState.selectedRole
            withAnimation(SonnetMotion.spring) { appeared = true }
        }
    }

    // MARK: - 角色卡片

    @ViewBuilder
    private func roleCard(_ role: UserRole) -> some View {
        let isSelected = selectedRole == role

        SonnetCard {
            HStack(spacing: SonnetDimens.spacingL) {
                // 图标容器
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? SonnetColors.ink : SonnetColors.inkWash)
                        .frame(width: 48, height: 48)
                    Image(systemName: role.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white : SonnetColors.ink)
                }
                .animation(SonnetMotion.spring, value: isSelected)

                // 文案
                VStack(alignment: .leading, spacing: 3) {
                    Text(role.displayName)
                        .font(SonnetTypography.bodyBold)
                        .foregroundStyle(SonnetColors.textTitle)
                    Text(role.tagline)
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textCaption)
                }

                Spacer()

                // 选中指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? SonnetColors.ink : SonnetColors.textHint)
                    .animation(SonnetMotion.spring, value: isSelected)
            }
            .padding(.horizontal, 18)
            .frame(height: 72)
        }
        .overlay(
            RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge)
                .stroke(isSelected ? SonnetColors.ink : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(SonnetMotion.spring, value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(SonnetMotion.springFast) {
                selectedRole = role
            }
            HapticManager.selection()
        }
    }

    // MARK: - 确认按钮

    private var confirmButton: some View {
        InkButton(
            title: selectedRole == nil
                ? "请选择身份"
                : (onComplete == nil ? "保存身份 · \(selectedRole!.displayName)" : "开始使用 · \(selectedRole!.displayName)"),
            action: confirmSelection,
            style: .primary
        )
        .disabled(selectedRole == nil)
        .opacity(selectedRole == nil ? 0.5 : 1)
        .animation(SonnetMotion.spring, value: selectedRole)
    }

    private func confirmSelection() {
        guard let role = selectedRole else { return }
        HapticManager.success()
        appState.saveRole(role)
        if role == .student {
            dataService.seedStudentCategories()
        }
        withAnimation(SonnetMotion.easeInOut) {
            if let onComplete {
                onComplete()
            } else {
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RoleSelectionView()
        .environment(AppState())
        .environment(DataService(modelContext: try! ModelContainer(
            for: Category.self, configurations: .init(isStoredInMemoryOnly: true)
        ).mainContext))
}
