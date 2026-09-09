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
    private var heartbeatTimer: Timer?
    private var isVerifying = false

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
                revokeSession(reason: "License expired")
                return
            }
        } else {
            isLifetime = true
            expirationDate = nil
        }
        
        isActive = true
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
        if isActive {
            verifyCurrentSession { [weak self] valid in
                guard let self else { return }
                if valid {
                    self.message = "Ready to use"
                    self.startRealtimeHeartbeat()
                }
            }
        } else {
            message = "Key required - enter your access key"
        }
    }

    func startRealtimeHeartbeat() {
        stopRealtimeHeartbeat()
        guard isActive, rememberedKey() != nil else { return }
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.verifyCurrentSession()
            }
        }
    }

    func stopRealtimeHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }
        if let lastAttemptAt, Date().timeIntervalSince(lastAttemptAt) < 1 {
            message = "Please wait a moment before trying again"
            return
        }
        lastAttemptAt = Date()
        isBusy = true
        message = "Connecting to UDIN Server..."

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

                guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.isActive = false
                    self.message = "Invalid response from license server"
                    return
                }

                let success = json["success"] as? Bool ?? false
                let serverMessage = json["message"] as? String ?? "Unknown response"

                if success {
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
                    self.startRealtimeHeartbeat()
                } else {
                    self.revokeSession(reason: serverMessage)
                }
            }
        }.resume()
    }

    func verifyCurrentSession(completion: ((Bool) -> Void)? = nil) {
        guard let key = rememberedKey(), !isVerifying else {
            completion?(isActive)
            return
        }
        
        guard let endpoint = URL(string: "\(serverURL)/api/license/verify") else {
            completion?(isActive)
            return
        }
        
        isVerifying = true
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
            DispatchQueue.main.async {
                guard let self else { return }
                self.isVerifying = false

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 || httpResponse.statusCode == 403 {
                    var errorMsg = "Access revoked: License key has been deleted or disabled by admin."
                    if let data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let serverMsg = json["message"] as? String {
                        errorMsg = serverMsg
                    }
                    self.revokeSession(reason: errorMsg)
                    completion?(false)
                    return
                }

                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    if let exp = self.expirationDate, Date() > exp {
                        self.revokeSession(reason: "License expired")
                        completion?(false)
                    } else {
                        completion?(self.isActive)
                    }
                    return
                }

                let valid = json["valid"] as? Bool ?? false
                if !valid {
                    let serverMsg = json["message"] as? String ?? "License key is no longer valid."
                    self.revokeSession(reason: serverMsg)
                    completion?(false)
                } else {
                    if let plan = json["plan"] as? String {
                        self.planName = plan
                    }
                    if let lifetime = json["is_lifetime"] as? Bool {
                        self.isLifetime = lifetime
                    }
                    if let expiryDateStr = json["expiry_date"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let date = formatter.date(from: expiryDateStr) ?? ISO8601DateFormatter().date(from: expiryDateStr)
                        self.expirationDate = date
                        if let exp = date, Date() > exp {
                            self.revokeSession(reason: "License expired")
                            completion?(false)
                            return
                        }
                    }
                    self.isActive = true
                    completion?(true)
                }
            }
        }.resume()
    }

    func revokeSession(reason: String) {
        stopRealtimeHeartbeat()
        isActive = false
        message = reason
        expirationDate = nil
        isLifetime = false
        delete(keyAccount)
        delete(planAccount)
        delete(expiryAccount)
    }

    func rememberedKey() -> String? { string(for: keyAccount) }

    func refresh() {
        checkSavedState()
        message = isActive ? "Ready to use" : "Key required - enter your access key"
    }

    func deactivate() {
        revokeSession(reason: "Activation removed from this device")
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
