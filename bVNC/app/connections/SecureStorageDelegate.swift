/**
 * Copyright (C) 2024- Morpheusly Inc. All rights reserved.
 *
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this software; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
 * USA.
 */

import Foundation

class SecureStorageDelegate {
    
    static func loadCredentialsForConnection(connection: [String : String]) -> [String : String] {
        var newConnection = loadCredentialsFromSecureStorage(connection: connection, passwordField: "password")
        newConnection = loadCredentialsFromSecureStorage(connection: newConnection, passwordField: "sshPass")
        newConnection = loadCredentialsFromSecureStorage(connection: newConnection, passwordField: "sshPassphrase")
        newConnection = loadCredentialsFromSecureStorage(connection: newConnection, passwordField: "sshPrivateKey")
        newConnection = loadCredentialsFromSecureStorage(connection: newConnection, passwordField: "rdpGatewayPass")
        return newConnection
    }
    
    static func saveCredentialsForConnection(connection: [String: String]) -> [String: String] {
        var copyOfConnection = connection
        if copyOfConnection["saveCredentials"] == "true" // User wants to save credentials
            || copyOfConnection["password"] == "" { // User may be deleting a password
            saveCredentials(
                connection: connection,
                usernameField: "username",
                passwordField: "password",
                addressField: "address",
                portField: "port"
            )
        }
        copyOfConnection["password"] = ""
        
        let sshServerNotEmpty = copyOfConnection["sshAddress"] != ""
        if (sshServerNotEmpty &&
            (copyOfConnection["saveSshCredentials"] == "true"
             || copyOfConnection["sshPass"] == "")) { // User may be deleting the password
            saveCredentials(
                connection: connection,
                usernameField: "sshUser",
                passwordField: "sshPass",
                addressField: "sshAddress",
                portField: "sshPort"
            )
        }
        copyOfConnection["sshPass"] = ""
        
        if sshServerNotEmpty {
            saveCredentials(
                connection: connection,
                usernameField: "sshUser",
                passwordField: "sshPassphrase",
                addressField: "sshAddress",
                portField: "sshPort"
            )
            saveCredentials(
                connection: connection,
                usernameField: "sshUser",
                passwordField: "sshPrivateKey",
                addressField: "sshAddress",
                portField: "sshPort"
            )
        }
        copyOfConnection["sshPassphrase"] = ""
        copyOfConnection["sshPrivateKey"] = ""

        if copyOfConnection["saveCredentials"] == "true"
            || copyOfConnection["rdpGatewayPass"] == "" { // User may be deleting the password
            saveCredentials(
                connection: connection,
                usernameField: "rdpGatewayUser",
                passwordField: "rdpGatewayPass",
                addressField: "rdpGatewayAddress",
                portField: "rdpGatewayPort"
            )
        }
        copyOfConnection["rdpGatewayPass"] = ""
        return copyOfConnection
    }
    
    static func deleteCredentialsForConnection(connection: [String: String]) {
        deleteCredentials(connection: connection, passwordField: "password")
        deleteCredentials(connection: connection, passwordField: "sshPass")
        deleteCredentials(connection: connection, passwordField: "sshPassphrase")
        deleteCredentials(connection: connection, passwordField: "sshPrivateKey")
        deleteCredentials(connection: connection, passwordField: "rdpGatewayPass")
    }
    
    static private func deleteCredentials(connection: Dictionary<String, String>, passwordField: String) {
        guard let uniqueField = connection["id"] else {
            log_callback_str(message: "\(#function) Not saving credentials for connection with no unique ID")
            return
        }
        let account = getAccount(passwordField, uniqueField)
        let query: [String: Any] = getBaseQuery(account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else {
            log_callback_str(message: "\(#function) Error \(SecCopyErrorMessageString(status, nil)!) deleting \(account) credentials from secure storage")
            return
        }
        log_callback_str(message: "\(#function) Success deleting \(account) credentials from secure storage")
    }
    
    static private func saveCredentials(
        connection: Dictionary<String, String>,
        usernameField: String,
        passwordField: String,
        addressField: String,
        portField: String
    ) {
        let username = (connection[usernameField] ?? "")
        let server = getServer(connection[addressField], Utils.getDefaultAddress())
        let port = getPort(connection[portField], Utils.getDefaultSshPort())
        let password = (connection[passwordField] ?? "").data(using: String.Encoding.utf8)!
        guard let uniqueField = connection["id"] else {
            log_callback_str(message: "\(#function) Not saving credentials for connection with no unique ID")
            return
        }
        let account = getAccount(passwordField, uniqueField)
        let query: [String: Any] = getSaveQuery(account, username, server, port, password)
        deleteCredentials(connection: connection, passwordField: passwordField)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            log_callback_str(message: "\(#function) Error \(SecCopyErrorMessageString(status, nil)!) saving \(account) credentials in secure storage")
            return
        }
        log_callback_str(message: "\(#function) Success saving \(account) credentials in secure storage")
    }
        
    static private func loadCredentialsFromSecureStorage(connection: Dictionary<String, String>, passwordField: String) -> Dictionary<String, String> {
        var copyOfConnection = connection
        let uniqueField = connection["id"] ?? ""
        let account = getAccount(passwordField, uniqueField)
        let query: [String: Any] = getLoadQuery(account)
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess && status != errSecItemNotFound else {
            //log_callback_str(message: "\(#function) Could not load \(account) credentials due to: \(SecCopyErrorMessageString(status, nil)!)")
            copyOfConnection[passwordField] = ""
            return connection
        }
        let passwordData = item![kSecValueData as String] as? Data
        let password = String(data: passwordData!, encoding: String.Encoding.utf8)
        copyOfConnection[passwordField] = password
        //log_callback_str(message: "\(#function) Success loading \(account) credentials from secure storage")
        return copyOfConnection
    }
    
    static private func getBaseQuery(_ account: (String)) -> [String : Any] {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ] as [String : Any]
        return query
    }
    
    static private func getSaveQuery(
        _ account: (String), _ user: String, _ server: String, _ port: String, _ password: Data
    ) -> [String : Any] {
        var query = getBaseQuery(account)
        query[kSecValueData as String] = password
        query[kSecAttrLabel as String] = getLabel(Utils.bundleID, user, server, port)
        return query
    }
    
    static private func getLoadQuery(_ account: (String)) -> [String : Any] {
        var query = getBaseQuery(account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        return query
    }
    
    static private func getServer(_ address: String?, _ defaultAddress: String) -> String {
        return address ?? defaultAddress
    }
    
    static private func getPort(_ port: String?, _ defaultPort: String) -> String {
        return port ?? defaultPort
    }
    
    fileprivate static func getAccount(_ passwordField: String, _ uniqueField: String) -> String {
        return passwordField + "/" + uniqueField
    }

    fileprivate static func getLabel(_ appId: String, _ user: String, _ address: String, _ port: String) -> String {
        let userAtOrEmpty = user != "" ? user + "@" : ""
        return appId + ": " + userAtOrEmpty + address + ":" + port
    }

}
