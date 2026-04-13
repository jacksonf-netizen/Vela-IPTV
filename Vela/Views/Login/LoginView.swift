import SwiftUI

struct AddProviderView: View {
    @ObservedObject var authVM: AuthViewModel
    let isSheet: Bool

    @State private var isHoveringButton = false
    @FocusState private var focusedField: ProviderField?

    enum ProviderField { case name, server, username, password }

    var body: some View {
        ZStack {
            // MARK: – Abstract Vela Theme
            VelaThemeView()

            VStack(spacing: 0) {
                if !isSheet { Spacer() }

                // MARK: – Branding
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.velaGradient)
                            .frame(width: isSheet ? 56 : 80, height: isSheet ? 56 : 80)
                            .shadow(color: Color.appAccent.opacity(0.4), radius: 20, x: 0, y: 10)
                        
                        Image(systemName: "v.square.fill")
                            .font(.system(size: isSheet ? 32 : 44, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 4) {
                        Text(isSheet ? "New Provider" : "Vela IPTV")
                            .font(.system(size: isSheet ? 24 : 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(isSheet ? "Expand your stream library" : "Native. Premium. IPTV.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
                .padding(.bottom, isSheet ? 32 : 48)

                // MARK: – The Glassmorphic Credentials Card
                VStack(spacing: 18) {
                    StyledInputField(
                        icon: "tag.fill",
                        placeholder: "Display Name (e.g. My Streams)",
                        text: $authVM.newProviderName,
                        isSecure: false
                    )
                    .focused($focusedField, equals: .name)
                    .onSubmit { focusedField = .server }

                    StyledInputField(
                        icon: "server.rack",
                        placeholder: "Server URL (http://...)",
                        text: $authVM.newServerURL,
                        isSecure: false
                    )
                    .focused($focusedField, equals: .server)
                    .onSubmit { focusedField = .username }

                    StyledInputField(
                        icon: "person.crop.circle.fill",
                        placeholder: "Account Username",
                        text: $authVM.newUsername,
                        isSecure: false
                    )
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }

                    StyledInputField(
                        icon: "key.fill",
                        placeholder: "Account Password",
                        text: $authVM.newPassword,
                        isSecure: true
                    )
                    .focused($focusedField, equals: .password)
                    .onSubmit { Task { await authVM.addProvider() } }

                    if let error = authVM.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(Color.appLiveRed)
                            Text(error)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.appLiveRed)
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if isSheet {
                        HStack(spacing: 16) {
                            Button("Cancel") {
                                authVM.resetForm()
                                authVM.isShowingAddProvider = false
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

                            addButton
                        }
                    } else {
                        addButton
                    }
                }
                .padding(32)
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(LinearGradient(
                                    colors: [.white.opacity(0.15), .clear],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ), lineWidth: 1)
                        )
                )
                .frame(width: 460)
                .shadow(color: .black.opacity(0.3), radius: 50, x: 0, y: 20)

                if !isSheet { Spacer() }

                Text("All credentials stored locally")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color.appTextSecondary.opacity(0.4))
                    .tracking(1.0)
                    .padding(.vertical, 32)
            }
        }
        .onAppear { authVM.resetForm(); focusedField = .name }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: authVM.errorMessage)
    }

    private var isFormValid: Bool {
        !authVM.newServerURL.isEmpty && !authVM.newUsername.isEmpty && !authVM.newPassword.isEmpty
    }

    private var addButton: some View {
        Button { Task { await authVM.addProvider() } } label: {
            ZStack {
                if authVM.isLoading {
                    VelaSpinner(size: 22, lineWidth: 3)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Add Account")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isFormValid ? AnyShapeStyle(Color.velaGradient) : AnyShapeStyle(Color.white.opacity(0.1)))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(isHoveringButton && isFormValid ? 1.02 : 1.0)
            .shadow(color: isFormValid ? Color.appAccent.opacity(isHoveringButton ? 0.5 : 0.3) : .clear,
                    radius: isHoveringButton ? 15 : 8)
        }
        .buttonStyle(.plain)
        .onHover { isHoveringButton = $0 }
        .disabled(authVM.isLoading || !isFormValid)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringButton)
        .animation(.easeInOut, value: isFormValid)
    }
}

// MARK: - Reusable styled input field (Apple Modern)

struct StyledInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? Color.white : Color.appAccent)
                .frame(width: 24)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .focused($isFocused)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(isFocused ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isFocused ? Color.white.opacity(0.3) : (isHovering ? Color.white.opacity(0.15) : Color.white.opacity(0.06)),
                            lineWidth: 1
                        )
                )
        )
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovering || isFocused)
    }
}
