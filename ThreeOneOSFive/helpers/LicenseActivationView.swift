import SwiftUI

struct LicenseActivationView: View {
    @ObservedObject var manager: LicenseManager
    @State private var key = ""
    @FocusState private var keyFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.stealthBg
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 40)

                            AppLogo(size: 88)
                                .shadow(color: AppTheme.emeraldActive.opacity(0.35), radius: 16, y: 6)
                                .padding(.bottom, 16)

                            Text("UDIN EXTERNAL")
                                .font(.system(size: 30, weight: .heavy, design: .default))
                                .tracking(2.5)
                                .foregroundStyle(.white)

                            Text("UDINXITER MARKETPLACE • v2.4.0")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.mutedText)
                                .padding(.top, 4)

                            VStack(spacing: 18) {
                                HStack(spacing: 10) {
                                    Image(systemName: manager.isBusy ? "arrow.triangle.2.circlepath" : "key.fill")
                                        .foregroundStyle(AppTheme.emeraldActive)
                                        .font(.system(size: 16, weight: .bold))
                                    Text(manager.isBusy ? "Authenticating Key…" : "Access Key Required")
                                        .font(.system(size: 15, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }

                                Text("Enter your UDIN access key to unlock the external bypass modules.")
                                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.subtext)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                TextField("Enter access key", text: $key)
                                    .focused($keyFocused)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .submitLabel(.done)
                                    .onSubmit { activate() }
                                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .frame(height: 50)
                                    .background(AppTheme.stealthInnerCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(AppTheme.stealthInnerBorder, lineWidth: 1)
                                    )
                                    .id("license-field")

                                Toggle("Remember key on this device", isOn: $manager.rememberKey)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.subtext)
                                    .tint(AppTheme.emeraldActive)

                                Button(action: activate) {
                                    HStack(spacing: 8) {
                                        Image(systemName: manager.isBusy ? "hourglass" : "checkmark.shield.fill")
                                        Text(manager.isBusy ? "AUTHENTICATING…" : "ACTIVATE ENGINE")
                                    }
                                    .font(.system(size: 13.5, weight: .black, design: .monospaced))
                                    .tracking(0.8)
                                    .foregroundStyle(Color(red: 0.05, green: 0.06, blue: 0.08))
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(AppTheme.emeraldActive, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .shadow(color: AppTheme.emeraldActive.opacity(0.3), radius: 10, y: 4)
                                }
                                .buttonStyle(.plain)
                                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isBusy)
                                .opacity(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                                if let message = manager.message {
                                    Text(message)
                                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.red.opacity(0.95))
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.stealthInnerCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }

                                if let contactOwner = manager.contactOwner,
                                   let contactURL = ownerURL(from: contactOwner) {
                                    Button("Contact Developer / Get Key") {
                                        UIApplication.shared.open(contactURL)
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.emeraldActive)
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(20)
                            .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.stealthCardBorder, lineWidth: 1))
                            .padding(.horizontal, 22)
                            .padding(.top, 24)
                            .id("activation-card")

                            Spacer(minLength: 42)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 28)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: keyFocused) { focused in
                        guard focused else { return }
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("activation-card", anchor: .center) }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func activate() {
        keyFocused = false
        manager.activate(key: key)
    }

    private func ownerURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        if trimmed.hasPrefix("@") {
            return URL(string: "https://t.me/" + String(trimmed.dropFirst()))
        }
        return URL(string: "https://t.me/" + trimmed)
    }
}
