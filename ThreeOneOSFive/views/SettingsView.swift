import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("voiceFeedbackEnabled") private var voiceFeedbackEnabled = true
    @AppStorage("udin_custom_server_url") private var customServerURL = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.stealthBg
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Brand Info
                        VStack(spacing: 6) {
                            Text("UDIN EXTERNAL IOS")
                                .font(.system(size: 20, weight: .heavy, design: .default))
                                .tracking(1.5)
                                .foregroundStyle(.white)

                            Text("Cyber Stealth Edition • v2.4.0 (Build 3105)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.mutedText)
                        }
                        .padding(.top, 10)

                        // Section 1: Engine & Exploit
                        settingsGroup(title: "BYPASS ENGINE & EXPLOIT") {
                            VStack(spacing: 12) {
                                settingsRow(label: "Bypass Engine Status", value: "ACTIVE (Online)", isHighlight: true)
                                Divider().background(AppTheme.stealthInnerBorder)
                                settingsRow(label: "Kernel Exploit Mode", value: appState.isSupported ? "kexploit (Sandbox Verified)" : "Unsupported", isHighlight: false)
                                Divider().background(AppTheme.stealthInnerBorder)
                                settingsRow(label: "Memory Hooking", value: "Clean Direct Patch", isHighlight: false)
                            }
                        }

                        // Section 2: Sound & Haptics
                        settingsGroup(title: "FEEDBACK & ANNOUNCEMENTS") {
                            VStack(spacing: 12) {
                                Toggle(isOn: $voiceFeedbackEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("English Voice Synthesizer")
                                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("Speaks status when injecting or restoring")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(AppTheme.mutedText)
                                    }
                                }
                                .tint(AppTheme.emeraldActive)

                                Divider().background(AppTheme.stealthInnerBorder)

                                Toggle(isOn: $hapticsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Haptic Feedback")
                                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("Vibrate on button tap and injection")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(AppTheme.mutedText)
                                    }
                                }
                                .tint(AppTheme.emeraldActive)
                            }
                        }

                        // Section 3: Device Info
                        settingsGroup(title: "DEVICE ENVIRONMENT") {
                            VStack(spacing: 12) {
                                settingsRow(label: "Device Model", value: AppInfo.displayMachineName, isHighlight: false)
                                Divider().background(AppTheme.stealthInnerBorder)
                                settingsRow(label: "iOS Version", value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))", isHighlight: false)
                                Divider().background(AppTheme.stealthInnerBorder)
                                settingsRow(label: "Platform Architecture", value: AppInfo.machineName, isHighlight: false)
                            }
                        }

                        // Section 4: License Server Endpoint
                        settingsGroup(title: "LICENSE SERVER ENDPOINT") {
                            VStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Custom Server Host (Optional)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppTheme.mutedText)
                                    TextField("https://udinexternalios.vercel.app", text: $customServerURL)
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .padding(.horizontal, 12)
                                        .frame(height: 40)
                                        .background(AppTheme.stealthInnerCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.stealthInnerBorder, lineWidth: 1))
                                }
                                Text("Default is active. Change only if hosting a custom Web Admin backend.")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                        }

                        // Section 5: Credits & Community
                        settingsGroup(title: "CREDITS & COMMUNITY") {
                            VStack(spacing: 12) {
                                settingsRow(label: "Developed By", value: "zaeruw", isHighlight: true)
                                Divider().background(AppTheme.stealthInnerBorder)
                                Button {
                                    if let url = URL(string: "https://whatsapp.com/channel/0029VbBz5Gj5Ui2QFktuvl0X") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    HStack {
                                        Text("WhatsApp Channel")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(AppTheme.subtext)
                                        Spacer()
                                        Text("UDIN PROJECT")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(AppTheme.emeraldActive)
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(AppTheme.emeraldActive)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.emeraldActive)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(AppTheme.mutedText).frame(width: 5, height: 5)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.subtext)
            }
            .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(14)
            .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.stealthCardBorder, lineWidth: 1)
            )
        }
    }

    private func settingsRow(label: String, value: String, isHighlight: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.subtext)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isHighlight ? AppTheme.emeraldActive : Color.white)
        }
    }
}
