import SwiftUI
import UIKit
import AVFoundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @State private var selectedTab = 0 // 0 = Home, 1 = Account
    @State private var showSettings = false
    @State private var showCleaner = false
    @StateObject private var patchStore = PatchProjectStore()
    @State private var patchOperationBusy = false
    @State private var patchMessage = "SYSTEM READY — SELECT A PATCH"
    @State private var aimBodyPackageEnabled = false
    @State private var aimChestPackageEnabled = false
    @State private var magicEnabled = false
    @State private var hyperBalamagicaEnabled = false

    var body: some View {
        ZStack {
            AppTheme.stealthBg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Fixed Header (UDIN + Settings)
                brandHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                // Scrollable Content
                ScrollView(showsIndicators: false) {
                    if selectedTab == 0 {
                        homeTabView
                            .transition(.opacity)
                    } else {
                        accountTabView
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 18)

                // Bottom Tab Bar
                bottomNavigationBar
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCleaner) {
            CleanerView()
        }
        .sheet(item: $patchStore.passwordRequest, onDismiss: patchStore.cancelUnlock) { _ in
            PatchUnlockPrompt(store: patchStore)
        }
        .onAppear {
            if patchStore.items.isEmpty {
                patchStore.reload()
            }
            syncPatchStates()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active, !patchOperationBusy else { return }
            syncPatchStates()
            patchMessage = "SYSTEM READY — SELECT A PATCH"
        }
    }

    // MARK: - Header
    private var brandHeader: some View {
        HStack {
            Text("UDIN")
                .font(.system(size: 32, weight: .heavy, design: .default))
                .tracking(2.0)
                .foregroundStyle(.white)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .background(AppTheme.stealthCard, in: Circle())
                    .overlay(Circle().stroke(AppTheme.stealthCardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open settings")
        }
    }

    // MARK: - Home Tab View
    private var homeTabView: some View {
        VStack(spacing: 18) {
            systemTelemetrySection
            modularPatchesSection
            systemStatusConsole
            gameLaunchSection
        }
        .padding(.top, 6)
        .padding(.bottom, 16)
    }

    // MARK: - System Telemetry Section
    private var systemTelemetrySection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.mutedText)
                        .frame(width: 6, height: 6)
                    Text("SYSTEM TELEMETRY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.subtext)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.emeraldActive)
                        .frame(width: 6, height: 6)
                        .shadow(color: AppTheme.emeraldActive.opacity(0.8), radius: 3)
                    Text("ONLINE  •  PROTECTED")
                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.emeraldActive)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.greenBadgeBg, in: Capsule())
                .overlay(Capsule().stroke(AppTheme.greenBadgeBorder, lineWidth: 0.8))
            }

            // 3-Column Telemetry Box
            HStack(spacing: 10) {
                telemetrySubBox(
                    topLabel: "iOS SYSTEM",
                    mainValue: AppInfo.osVersion,
                    bottomLabel: "VERSION"
                )
                telemetrySubBox(
                    topLabel: "DEVICE",
                    mainValue: AppInfo.displayMachineName,
                    bottomLabel: "MODEL"
                )
                telemetrySubBox(
                    topLabel: "BYPASS ENGINE",
                    mainValue: "ACTIVE",
                    bottomLabel: "STATUS"
                )
            }
            .padding(14)
            .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.stealthCardBorder, lineWidth: 1)
            )
        }
    }

    private func telemetrySubBox(topLabel: String, mainValue: String, bottomLabel: String) -> some View {
        VStack(spacing: 6) {
            Text(topLabel)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.mutedText)

            Text(mainValue)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(bottomLabel)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(AppTheme.stealthInnerCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.stealthInnerBorder, lineWidth: 1)
        )
    }

    // MARK: - Modular Patches Section
    private var modularPatchesSection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.mutedText)
                        .frame(width: 6, height: 6)
                    Text("MODULAR PATCHES")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.subtext)
                }

                Spacer()

                Text("4 AUTHENTIC MODULES")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.mutedText)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                StealthPatchCard(
                    title: "Aim Body",
                    subtitle: "Auto Hook • Body",
                    isEnabled: aimBodyPackageEnabled,
                    isBusy: patchOperationBusy
                ) {
                    togglePatch(packageFilename: "zryxiosbody.3105", state: $aimBodyPackageEnabled)
                }

                StealthPatchCard(
                    title: "Aim Chest",
                    subtitle: "Precision • Chest",
                    isEnabled: aimChestPackageEnabled,
                    isBusy: patchOperationBusy
                ) {
                    togglePatch(packageFilename: "zryxioschest.3105", state: $aimChestPackageEnabled)
                }

                StealthPatchCard(
                    title: "Magic Bullet",
                    subtitle: "Curved Aim • Wall",
                    isEnabled: magicEnabled,
                    isBusy: patchOperationBusy
                ) {
                    togglePatch(packageFilename: "zryxiosmagic.3105", state: $magicEnabled)
                }

                StealthPatchCard(
                    title: "144 FPS",
                    subtitle: "Extreme Unlock",
                    isEnabled: hyperBalamagicaEnabled,
                    isBusy: patchOperationBusy
                ) {
                    togglePatch(packageFilename: "zryxios144fps.3105", state: $hyperBalamagicaEnabled)
                }
            }
        }
    }

    // MARK: - Status Console Bar
    private var systemStatusConsole: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(patchMessage.localizedCaseInsensitiveContains("successful") || patchMessage.localizedCaseInsensitiveContains("ready") ? AppTheme.emeraldActive : AppTheme.mutedText)
                .frame(width: 6, height: 6)
                .shadow(color: AppTheme.emeraldActive.opacity(0.6), radius: 3)

            Text(patchOperationBusy ? "INJECTING PATCH MEMORY…" : patchMessage)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stealthCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Game Launch Section
    private var gameLaunchSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.mutedText)
                    .frame(width: 6, height: 6)
                Text("GAME LAUNCH")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.subtext)
                Spacer()
            }

            Button {
                openGame(scheme: "freefireth")
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.stealthPlayButton)
                            .frame(width: 48, height: 48)
                            .overlay(Circle().stroke(AppTheme.stealthPlayBorder, lineWidth: 1))

                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 1.5)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("FF NORMAL")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Optimal Config")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .padding(14)
                .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.stealthCardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Account Tab View
    private var accountTabView: some View {
        VStack(spacing: 18) {
            // Profile & License Section
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.mutedText)
                        .frame(width: 6, height: 6)
                    Text("USER PROFILE & LICENSE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.subtext)
                    Spacer()
                }

                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.stealthInnerCard)
                                .frame(width: 54, height: 54)
                                .overlay(Circle().stroke(AppTheme.emeraldActive.opacity(0.4), lineWidth: 1.2))

                            if let logoImg = UIImage(named: "UDINLogo") ?? UIImage(named: "ZRYXLogo") ?? UIImage(named: "AppIcon-1024") {
                                Image(uiImage: logoImg)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.badge.shield.checkmark.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(AppTheme.emeraldActive)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(licenseManager.planName.uppercased())
                                .font(.system(size: 14.5, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text(licenseManager.rememberedKey().map { "Key: \($0)" } ?? "Key: UDIN-AUTHORIZED")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.mutedText)
                                .lineLimit(1)
                        }

                        Spacer()

                        HStack(spacing: 5) {
                            Circle()
                                .fill(AppTheme.emeraldActive)
                                .frame(width: 6, height: 6)
                            Text("ACTIVE")
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                .foregroundStyle(AppTheme.emeraldActive)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(AppTheme.greenBadgeBg, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.greenBadgeBorder, lineWidth: 0.8))
                    }

                    Divider()
                        .background(AppTheme.stealthCardBorder)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("HARDWARE ID (HWID)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.mutedText)
                            Text(licenseManager.deviceHWID)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer()
                        Button {
                            UIPasteboard.general.string = licenseManager.deviceHWID
                        } label: {
                            Label("Copy HWID", systemImage: "doc.on.doc")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.emeraldActive)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.stealthInnerCard, in: Capsule())
                                .overlay(Capsule().stroke(AppTheme.emeraldActive.opacity(0.3), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                    }

                    if let exp = licenseManager.expirationDate {
                        Divider()
                            .background(AppTheme.stealthCardBorder)

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("LICENSE EXPIRATION")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.mutedText)
                                Text(exp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.emeraldActive)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.stealthCardBorder, lineWidth: 1))
            }

            // WhatsApp Official Channel
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.mutedText)
                        .frame(width: 6, height: 6)
                    Text("OFFICIAL COMMUNITY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.subtext)
                    Spacer()
                }

                Button {
                    guard let destination = URL(string: "https://whatsapp.com/channel/0029VbBz5Gj5Ui2QFktuvl0X") else { return }
                    UIApplication.shared.open(destination)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.greenBadgeBg)
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(AppTheme.greenBadgeBorder, lineWidth: 1))

                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(AppTheme.emeraldActive)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Official WhatsApp Channel")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("UDIN PROJECT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.emeraldActive)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    .padding(14)
                    .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.stealthCardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Account Actions Section
            VStack(spacing: 10) {
                Button {
                    showCleaner = true
                } label: {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.emeraldActive)
                        Text("Clean Cache & Temporary Memory")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.mutedText)
                    }
                    .padding(14)
                    .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.stealthCardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    licenseManager.deactivate()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.red.opacity(0.85))
                        Text("Deactivate / Reset License Key")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.red.opacity(0.9))
                        Spacer()
                    }
                    .padding(14)
                    .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.red.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 16)
    }

    // MARK: - Bottom Navigation Bar
    private var bottomNavigationBar: some View {
        HStack(spacing: 0) {
            // HOME Tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 0 }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "house")
                        .font(.system(size: 20, weight: selectedTab == 0 ? .bold : .medium))
                        .foregroundStyle(selectedTab == 0 ? .white : AppTheme.mutedText)

                    Text("HOME")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(selectedTab == 0 ? .white : AppTheme.mutedText)

                    Capsule()
                        .fill(selectedTab == 0 ? Color.white : Color.clear)
                        .frame(width: 44, height: 2.5)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ACCOUNT Tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 1 }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "person")
                        .font(.system(size: 20, weight: selectedTab == 1 ? .bold : .medium))
                        .foregroundStyle(selectedTab == 1 ? .white : AppTheme.mutedText)

                    Text("ACCOUNT")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(selectedTab == 1 ? .white : AppTheme.mutedText)

                    Capsule()
                        .fill(selectedTab == 1 ? Color.white : Color.clear)
                        .frame(width: 44, height: 2.5)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.stealthCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Logic & Handlers
    private func syncPatchStates() {
        aimBodyPackageEnabled = isPatchActive("zryxiosbody.3105")
        aimChestPackageEnabled = isPatchActive("zryxioschest.3105")
        magicEnabled = isPatchActive("zryxiosmagic.3105")
        hyperBalamagicaEnabled = isPatchActive("zryxios144fps.3105")
    }

    private func findItem(named packageFilename: String) -> PatchLibraryItem? {
        if let direct = patchStore.items.first(where: { $0.packageURL.lastPathComponent.caseInsensitiveCompare(packageFilename) == .orderedSame }) {
            return direct
        }
        let targetBase = (packageFilename as NSString).deletingPathExtension
        if let match = patchStore.items.first(where: { item in
            let base = item.packageURL.deletingPathExtension().lastPathComponent
            return base.caseInsensitiveCompare(targetBase) == .orderedSame
                || item.displayName.caseInsensitiveCompare(packageFilename) == .orderedSame
                || item.displayName.caseInsensitiveCompare(targetBase) == .orderedSame
        }) {
            return match
        }
        if let directItem = PatchProjectLibrary.loadDirect(named: packageFilename) {
            return directItem
        }
        return patchStore.items.first(where: { $0.project != nil }) ?? patchStore.items.first
    }

    private func isPatchActive(_ packageFilename: String) -> Bool {
        findItem(named: packageFilename)
            .flatMap { DevicePatchService.latestReceipt(projectID: $0.id) } != nil
    }

    private enum PatchActionResult {
        case applied
        case restored
        case unavailable(String)
    }

    private func setPatchState(for packageFilename: String, enabled: Bool) {
        switch packageFilename {
        case "zryxiosbody.3105": aimBodyPackageEnabled = enabled
        case "zryxioschest.3105": aimChestPackageEnabled = enabled
        case "zryxiosmagic.3105": magicEnabled = enabled
        case "zryxios144fps.3105": hyperBalamagicaEnabled = enabled
        default: break
        }
    }

    private func togglePatch(packageFilename: String, state: Binding<Bool>) {
        guard !patchOperationBusy else { return }
        if patchStore.items.isEmpty {
            patchStore.reload()
        }
        let item = findItem(named: packageFilename)
        let activeProject = item?.project ?? patchStore.items.first(where: { $0.project != nil })?.project
        guard let project = activeProject else {
            patchMessage = "ERROR — NO VALID PATCH"
            return
        }

        let projectID = item?.id ?? project.id
        let wasEnabled = state.wrappedValue
        patchOperationBusy = true
        patchMessage = "PROCESSING — \(packageFilename)"

        DispatchQueue.global(qos: .userInitiated).async {
            let result: PatchActionResult
            do {
                if wasEnabled {
                    guard let receipt = DevicePatchService.latestReceipt(projectID: projectID) else {
                        result = .unavailable("NO ACTIVE RECEIPT — NOTHING TO RESTORE")
                        DispatchQueue.main.async {
                            self.setPatchState(for: packageFilename, enabled: false)
                            self.patchMessage = "OFF — NO ACTIVE PATCH FOUND"
                            self.patchOperationBusy = false
                        }
                        return
                    }
                    try DevicePatchService.restore(receipt: receipt)
                    result = .restored
                } else {
                    _ = try DevicePatchService.apply(project: project)
                    result = .applied
                }
            } catch {
                result = .unavailable("FAILED — \(String(describing: error))")
            }

            DispatchQueue.main.async {
                switch result {
                case .applied:
                    self.setPatchState(for: packageFilename, enabled: true)
                    self.patchMessage = "Inject Successful — \(packageFilename)"
                    PatchAudioFeedback.bypassActivated()
                case .restored:
                    self.setPatchState(for: packageFilename, enabled: false)
                    self.patchMessage = "Restore Successful — \(packageFilename)"
                    PatchAudioFeedback.originalRestored()
                case .unavailable(let message):
                    self.patchMessage = message
                }
                self.patchOperationBusy = false
            }
        }
    }

    private func openGame(scheme: String) {
        guard let url = URL(string: "\(scheme)://") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            log("launch: \(scheme) success=\(success)")
        }
    }
}

// MARK: - Stealth Patch Card Component
private struct StealthPatchCard: View {
    let title: String
    let subtitle: String
    let isEnabled: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(subtitle)
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.mutedText)
                            .lineLimit(1)
                    }

                    Spacer()

                    StealthToggleSwitch(isOn: isEnabled)
                }

                // Bottom Tap Action Bar
                HStack {
                    Text(isEnabled ? "TAP TO RESTORE" : "TAP TO INJECT")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(isEnabled ? AppTheme.emeraldActive : AppTheme.subtext)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isEnabled ? AppTheme.emeraldActive : AppTheme.mutedText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppTheme.stealthInnerCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.stealthInnerBorder, lineWidth: 1)
                )
            }
            .padding(14)
            .background(AppTheme.stealthCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isEnabled ? AppTheme.emeraldActive.opacity(0.35) : AppTheme.stealthCardBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.6 : 1)
        .accessibilityLabel("\(title), \(subtitle), \(isEnabled ? "Active" : "Off")")
    }
}

// MARK: - Stealth Toggle Switch Component
private struct StealthToggleSwitch: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Color(red: 0.25, green: 0.08, blue: 0.10) : Color(red: 0.12, green: 0.13, blue: 0.17))
                .frame(width: 38, height: 22)
                .overlay(
                    Capsule()
                        .stroke(isOn ? AppTheme.emeraldActive.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                )

            Circle()
                .fill(isOn ? AppTheme.emeraldActive : Color(red: 0.45, green: 0.48, blue: 0.55))
                .frame(width: 16, height: 16)
                .padding(.horizontal, 3)
                .shadow(color: isOn ? AppTheme.emeraldActive.opacity(0.6) : Color.clear, radius: 4)
        }
        .animation(.easeInOut(duration: 0.22), value: isOn)
    }
}

// MARK: - Audio Feedback (English Voice)
private enum PatchAudioFeedback {
    private static let synthesizer = AVSpeechSynthesizer()
    static func bypassActivated() { speak("Bypass activated") }
    static func originalRestored() { speak("Bypass deactivated") }
    private static func speak(_ message: String) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: [])
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: message)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        utterance.voice = voices.first(where: {
            ($0.language.hasPrefix("en-US") || $0.language.hasPrefix("en-GB") || $0.language.hasPrefix("en")) && $0.gender == .female
        }) ?? voices.first(where: {
            $0.language.hasPrefix("en")
        }) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.05
        utterance.volume = 0.90
        synthesizer.speak(utterance)
    }
}

// MARK: - Password Prompt
private struct PatchUnlockPrompt: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Package password", text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in store.clearUnlockError() }
                    if let errorKey = store.unlockErrorKey {
                        Text(AppLanguage.english.text(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Enter the password once to unlock this UDIN EXTERNAL IOS package on this device.")
                }
            }
            .navigationTitle("Unlock package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Unlock", action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}
