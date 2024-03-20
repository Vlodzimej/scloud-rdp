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
        let connectionWithCredentials = loadCredentialsFromSecureStorage(
            connection: connection,
            usernameField: "username",
            passwordField: "password",
            domainField: "domain",
            addressField: "address",
            portField: "port"
        )
        let connectionWithSshPassword = loadCredentialsFromSecureStorage(
            connection: connectionWithCredentials,
            usernameField: "sshUser",
            passwordField: "sshPass",
            domainField: nil,
            addressField: "sshAddress",
            portField: "sshPort"
        )
        let connectionWithSshPassphrase = loadCredentialsFromSecureStorage(
            connection: connectionWithSshPassword,
            usernameField: "sshUser",
            passwordField: "sshPassphrase",
            domainField: nil,
            addressField: "sshAddress",
            portField: "sshPort"
        )
        let connectionWithSshKey = loadCredentialsFromSecureStorage(
            connection: connectionWithSshPassphrase,
            usernameField: "sshUser",
            passwordField: "sshPrivateKey",
            domainField: nil,
            addressField: "sshAddress",
            portField: "sshPort"
        )
        return connectionWithSshKey
    }
    
    static func saveCredentialsForConnection(connection: [String: String]) -> [String: String] {
        var copyOfConnection = connection
        if copyOfConnection["saveCredentials"] == "true" {
            saveCredentialsToSecureStorage(
                connection: connection,
                usernameField: "username",
                passwordField: "password",
                domainField: "domain",
                addressField: "address",
                portField: "port"
            )
        }
        copyOfConnection["password"] = ""
        
        if copyOfConnection["saveSshCredentials"] == "true" {
            saveCredentialsToSecureStorage(
                connection: connection,
                usernameField: "sshUser",
                passwordField: "sshPass",
                domainField: nil,
                addressField: "sshAddress",
                portField: "sshPort"
            )
        }
        copyOfConnection["sshPass"] = ""
        
        if copyOfConnection["sshPassphrase"] != "" {
            saveCredentialsToSecureStorage(
                connection: connection,
                usernameField: "sshUser",
                passwordField: "sshPassphrase",
                domainField: nil,
                addressField: "sshAddress",
                portField: "sshPort"
            )
        }
        copyOfConnection["sshPassphrase"] = ""
        
        if copyOfConnection["sshPrivateKey"] != "" {
            saveCredentialsToSecureStorage(
                connection: connection,
                usernameField: "sshUser",
                passwordField: "sshPrivateKey",
                domainField: nil,
                addressField: "sshAddress",
                portField: "sshPort"
            )
        }
        copyOfConnection["sshPrivateKey"] = ""
        return connection
    }
    
    static private func saveCredentialsToSecureStorage(
        connection: Dictionary<String, String>,
        usernameField: String,
        passwordField: String,
        domainField: String?,
        addressField: String,
        portField: String
    ) {
        let username = (connection[usernameField] ?? "")
        let domain = domainField != nil ? (connection[domainField!] ?? "") : ""
        let server = getServer(connection[addressField], Utils.getDefaultAddress())
        let port = getPort(connection[portField], Utils.getDefaultSshPort())
        let password = (connection[passwordField] ?? "").data(using: String.Encoding.utf8)!
        guard let uniqueField = connection["id"] else {
            log_callback_str(message: "\(#function) Not saving credentials for connection with no unique ID")
            return
        }
        let account = username + "@" + server + "/" + passwordField + "/" + uniqueField
        let query: [String: Any] = getSaveQuery(account, server, port, uniqueField, passwordField, password, domain)
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            log_callback_str(message: "\(#function) Error \(SecCopyErrorMessageString(status, nil)!) saving \(account) credentials in secure storage")
            return
        }
        log_callback_str(message: "\(#function) Success saving \(account) credentials in secure storage")
    }
    
    static private func loadCredentialsFromSecureStorage(
        connection: Dictionary<String, String>,
        usernameField: String,
        passwordField: String,
        domainField: String?,
        addressField: String,
        portField: String
    ) -> Dictionary<String, String> {
        var copyOfConnection = connection
        let username = (connection[usernameField] ?? "")
        let domain = domainField != nil ? (connection[domainField!] ?? "") : ""
        let server = getServer(connection[addressField], Utils.getDefaultAddress())
        let port = getPort(connection[portField], Utils.getDefaultPort())
        let uniqueField = connection["id"] ?? ""
        let account = username + "@" + server + "/" + passwordField + "/" + uniqueField
        let query: [String: Any] = getLoadQuery(account, server, port, uniqueField, passwordField, domain)
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess && status != errSecItemNotFound else {
            log_callback_str(message: "\(#function) Could not load \(account) credentials due to: \(SecCopyErrorMessageString(status, nil)!)")
            return connection
        }
        let passwordData = item![kSecValueData as String] as? Data
        let password = String(data: passwordData!, encoding: String.Encoding.utf8)
        copyOfConnection[passwordField] = password
        log_callback_str(message: "\(#function) Success loading \(account) credentials from secure storage")
        return copyOfConnection
    }
    
    static private func getSaveQuery(
        _ account: (String),
        _ server: String,
        _ port: String,
        _ uniqueField: String,
        _ passwordField: String,
        _ password: Data,
        _ domain: (String)
    ) -> [String : Any] {
        let query = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccount as String: account,
            kSecAttrServer as String: server,
            kSecAttrPort as String: port,
            kSecValueData as String: password,
            kSecAttrSecurityDomain as String: domain
        ] as [String : Any]
        return query
    }
    
    static private func getLoadQuery(
        _ account: (String),
        _ server: String,
        _ port: String,
        _ uniqueField: String,
        _ passwordField: String,
        _ domain: String
    ) -> [String : Any] {
        return [kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: server,
                kSecAttrPort as String: port,
                kSecAttrAccount as String: account,
                kSecAttrSecurityDomain as String: domain,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecReturnAttributes as String: true,
                kSecReturnData as String: true]
    }
    
    static private func getServer(_ address: String?, _ defaultAddress: String) -> String {
        return address ?? defaultAddress
    }
    
    static private func getPort(_ port: String?, _ defaultPort: String) -> String {
        return port ?? defaultPort
    }
}
