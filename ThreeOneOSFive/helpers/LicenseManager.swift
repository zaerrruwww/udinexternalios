import Combine
import Foundation
import Security
import UIKit

@MainActor
final class LicenseManager: ObservableObject {
    static let defaultServerURL = "https://udinexternalios.vercel.app"

    @Published private(set) var expirationDate: Date?
    @Published private(set) var planName: String = "VIP Access"
    @Published private(set) var isLifetime: Bool = false
    @Published private(set) var isActive = false
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var contactOwner: String? = "https://whatsapp.com/channel/0029VbBz5Gj5Ui2QFktuvl0X"
    @Published var rememberKey = true

    private let service = "com.udinexternal.ios.activation"
    private let keyAccount = "license-key"
    private let planAccount = "license-plan"
    private let expiryAccount = "license-expiry"
    private var lastAttemptAt: Date?
    private var heartbeatCancellable: AnyCancellable?

    var deviceHWID: String {
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            return vendorId
        }
        return "HWID-\(AppInfo.displayMachineName)-UDIN"
    }

    var serverURL: String {
        UserDefaults.standard.string(forKey: "udin_custom_server_url") ?? Self.defaultServerURL
    }

    init() {
        checkSavedState()
    }

    private func checkSavedState() {
        guard let savedKey = string(for: keyAccount) else {
            isActive = false
            stopHeartbeat()
            return
        }
        
        if let savedPlan = string(for: planAccount) {
            planName = savedPlan
        }
        if let expiryStr = string(for: expiryAccount),
           let timeInterval = Double(expiryStr) {
            let exp = Date(timeIntervalSince1970: timeInterval)
            expirationDate = exp
            isLifetime = false
            if Date() > exp {
                isActive = false
                message = "License has expired"
                stopHeartbeat()
                return
            }
        } else {
            isLifetime = true
            expirationDate = nil
        }
        
        isActive = true
        startHeartbeat()
    }

    var hasRememberedKey: Bool {
        guard let _ = string(for: keyAccount) else { return false }
        if let exp = expirationDate, Date() > exp {
            return false
        }
        return true
    }

    func beginLaunchSession() {
        checkSavedState()
        message = isActive ? "Ready to use" : "Key required — enter your access key"
        
        if isActive, let key = rememberedKey() {
            silentVerify(key: key)
        }
    }

    func startHeartbeat() {
        heartbeatCancellable?.cancel()
        heartbeatCancellable = Timer.publish(every: 8.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isActive, let key = self.rememberedKey() else { return }
                self.silentVerify(key: key)
            }
    }

    func stopHeartbeat() {
        heartbeatCancellable?.cancel()
        heartbeatCancellable = nil
    }

    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty, !isBusy else { return }
        if let lastAttemptAt, Date().timeIntervalSince(lastAttemptAt) < 1 {
            message = "Please wait a moment before trying again"
            return
        }
        lastAttemptAt = Date()
        isBusy = true
        message = "Connecting to UDIN Server…"

        guard let endpoint = URL(string: "\(serverURL)/api/license/activate") else {
            isBusy = false
            isActive = false
            message = "Invalid license server URL"
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "key": trimmed,
            "hwid": deviceHWID,
            "device_model": AppInfo.displayMachineName,
            "os_version": AppInfo.osVersion
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false

                if let error {
                    self.isActive = false
                    self.message = "Connection error: \(error.localizedDescription)"
                    return
                }

                let httpResponse = response as? HTTPURLResponse
                let statusCode = httpResponse?.statusCode ?? 200

                guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.isActive = false
                    self.message = "Invalid response from server (Status \(statusCode))"
                    return
                }

                let success = json["success"] as? Bool ?? false
                let serverMessage = json["message"] as? String ?? "Activation response received"

                if success && statusCode == 200 {
                    self.isActive = true
                    let plan = json["plan"] as? String ?? "VIP Access"
                    let lifetime = json["is_lifetime"] as? Bool ?? false
                    self.planName = plan
                    self.isLifetime = lifetime

                    if let expiryDateStr = json["expiry_date"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let date = formatter.date(from: expiryDateStr) ?? ISO8601DateFormatter().date(from: expiryDateStr)
                        self.expirationDate = date
                        if let timestamp = date?.timeIntervalSince1970 {
                            self.save(String(timestamp), for: self.expiryAccount)
                        }
                    } else {
                        self.expirationDate = nil
                        self.delete(self.expiryAccount)
                    }

                    self.message = serverMessage
                    if self.rememberKey {
                        self.save(trimmed, for: self.keyAccount)
                        self.save(plan, for: self.planAccount)
                    }
                    self.startHeartbeat()
                } else {
                    self.isActive = false
                    self.message = serverMessage
                    self.stopHeartbeat()
                }
            }
        }.resume()
    }

    func silentVerify(key: String) {
        guard let endpoint = URL(string: "\(serverURL)/api/license/verify") else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 6

        let body: [String: Any] = [
            "key": key,
            "hwid": deviceHWID
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 200

            DispatchQueue.main.async {
                // If server explicitly rejects (Key deleted = 404, Key banned = 403, Unauthorized = 401)
                if statusCode == 401 || statusCode == 403 || statusCode == 404 {
                    var errorReason = "License revoked or deleted by admin"
                    if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let msg = json["message"] as? String {
                        errorReason = msg
                    }
                    self.revokeAccess(reason: errorReason)
                    return
                }

                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

                let valid = json["valid"] as? Bool ?? false
                if !valid {
                    let msg = json["message"] as? String ?? "License revoked by server"
                    self.revokeAccess(reason: msg)
                } else {
                    if let plan = json["plan"] as? String {
                        self.planName = plan
                    }
                    if let lifetime = json["is_lifetime"] as? Bool {
                        self.isLifetime = lifetime
                    }
                }
            }
        }.resume()
    }

    private func revokeAccess(reason: String) {
        isActive = false
        message = reason
        delete(keyAccount)
        delete(planAccount)
        delete(expiryAccount)
        stopHeartbeat()
    }

    func rememberedKey() -> String? { string(for: keyAccount) }

    func refresh() {
        checkSavedState()
        message = isActive ? "Ready to use" : "Key required — enter your access key"
    }

    func deactivate() {
        delete(keyAccount)
        delete(planAccount)
        delete(expiryAccount)
        isActive = false
        expirationDate = nil
        message = "Activation removed from this device"
        stopHeartbeat()
    }

    private func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save(_ value: String, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
