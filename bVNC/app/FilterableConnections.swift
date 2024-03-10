/**
 * Copyright (C) 2021- Morpheusly Inc. All rights reserved.
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

class FilterableConnections : ObservableObject {
    var allConnections: [Dictionary<String, String>]
    var filteredConnections: [Dictionary<String, String>]
    var stateKeeper: StateKeeper?
    var settings = UserDefaults.standard
    private var searchConnectionText = ""
    var connectionsVersion = -1
    var selectedFilteredConnectionIndex = -1
    var selectedUnfilteredConnectionIndex = -1
    var defaultSettings: Dictionary<String, String> = [:]
    var selectedConnection: Dictionary<String, String> = [:]
    var editedConnection: Dictionary<String, String> = [:]
    
    
    init(stateKeeper: StateKeeper?) {
        self.stateKeeper = stateKeeper
        let version = self.settings.integer(forKey: Constants.SAVED_CONNECTIONS_VERSION_KEY)
        self.connectionsVersion = version == 0 ? Constants.DEFAULT_CONNECTIONS_VERSION : version
        self.allConnections = []
        self.filteredConnections = self.allConnections
        self.loadConnections()
    }
    
    fileprivate func migrateConnections(_ connections: [[String : String]]) {
        while connectionsVersion < Constants.CURRENT_CONNECTIONS_VERSION {
            log_callback_str(message: "Migrating connections from version \(connectionsVersion) to version \(Constants.CURRENT_CONNECTIONS_VERSION)")
            deselectConnection()
            if connectionsVersion == 1 {
                moveCredentialsToSecureStorage(connections)
            }
            connectionsVersion += 1
            self.settings.set(connectionsVersion, forKey: Constants.SAVED_CONNECTIONS_VERSION_KEY)
        }
    }
    
    fileprivate func moveCredentialsToSecureStorage(_ connections: [[String : String]]) {
        connections.forEach { connection in
            saveConnection(connection: connection)
        }
    }
    
    fileprivate func loadCredentials(_ connections: [[String : String]]) {
        connections.forEach { connection in
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
            allConnections.append(connectionWithSshKey)
        }
    }
    
    func loadConnections() {
        self.defaultSettings = self.settings.object(
            forKey: Constants.SAVED_DEFAULT_SETTINGS_KEY) as? Dictionary<String, String> ?? [:]
        let connections = self.settings.array(
            forKey: Constants.SAVED_CONNECTIONS_KEY) as? [Dictionary<String, String>] ?? []
        self.allConnections = []
        migrateConnections(connections)
        loadCredentials(connections)
        self.filteredConnections = self.allConnections
        self.filterConnections()
    }
    
    fileprivate func getServer(_ address: String?, _ defaultAddress: String) -> String {
        return address ?? defaultAddress
    }
    
    fileprivate func getPort(_ port: String?, _ defaultPort: String) -> String {
        return port ?? defaultPort
    }
    
    fileprivate func getLoadQuery(
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
    
    private func loadCredentialsFromSecureStorage(
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
        let uniqueField = connection["screenShotFile"] ?? ""
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
    
    func connectionCount() -> Int {
        return self.filteredConnections.count
    }
    
    func setSearchConnectionText(searchConnectionText: String) {
        self.searchConnectionText = searchConnectionText
        self.filterConnections()
        if searchConnectionText == "" {
            self.stateKeeper?.showConnections()
        }
    }
    
    func getSearchConnectionText() -> String {
        return self.searchConnectionText
    }
    
    func buildTitle(connection: Dictionary<String, String>) -> String {
        let connectionName = connection["connectionName"] ?? ""
        if connectionName != "" {
            return connectionName
        } else {
            return buildGenericTitle(connection: connection)
        }
    }
    
    func buildGenericTitle(connection: Dictionary<String, String>) -> String {
        let defaultPort = Utils.getDefaultPort()
        var title = ""
        if connection["sshAddress"] != "" {
            let user = "\(connection["sshUser"] ?? "")"
            title = "SSH\t\(user)@\(connection["sshAddress"] ?? ""):\(connection["sshPort"] ?? "22")\n"
        }
        if Utils.isSpice() {
            var port = connection["tlsPort"]
            if port == nil || port == "-1" {
                port = connection["port"]
            }
            title += "SPICE\t\(connection["address"] ?? ""):\(port ?? defaultPort)"
        } else if Utils.isRdp() {
            title += "RDP\t\(connection["address"] ?? ""):\(connection["port"] ?? defaultPort)"
        } else {
            title += "VNC\t\(connection["address"] ?? ""):\(connection["port"] ?? defaultPort)"
        }
        return title
    }
    
    fileprivate func connectionMatchesSearchText(_ connection: [String : String]) -> Bool {
        let searchConnectionTextLowerCased = searchConnectionText.lowercased()
        return searchConnectionTextLowerCased == "" ||
        buildGenericTitle(connection: connection).lowercased().contains(searchConnectionTextLowerCased) ||
        buildTitle(connection: connection).lowercased().contains(searchConnectionTextLowerCased)
    }
    
    func filterConnections() {
        self.filteredConnections = allConnections.filter(
            { (connection) -> Bool in
                connectionMatchesSearchText(connection)
            })
    }
    
    func edit(connection: Dictionary<String, String>) -> Void {
        log_callback_str(message: #function)
        self.editedConnection = connection
        self.select(connection: connection)
    }
    
    func editDefaultSettings() -> Void {
        log_callback_str(message: #function)
        selectedFilteredConnectionIndex = Constants.DEFAULT_SETTINGS_FLAG
        selectedUnfilteredConnectionIndex = Constants.DEFAULT_SETTINGS_FLAG
        self.selectedConnection = defaultSettings
        self.editedConnection = defaultSettings
    }
    
    func select(connection: Dictionary<String, String>) -> Void {
        log_callback_str(message: #function)
        self.selectedConnection = connection
        self.selectedFilteredConnectionIndex = filteredConnections.firstIndex(of: connection) ?? -1
        self.selectedUnfilteredConnectionIndex = allConnections.firstIndex(of: connection) ?? -1
        log_callback_str(message: "\(#function): selectedUnfilteredConnectionIndex: \(selectedUnfilteredConnectionIndex)")
    }
    
    func get(at: Int) -> Dictionary<String, String> {
        return filteredConnections[at]
    }
    
    func removeSelected() -> Void {
        let selectedConnection = filteredConnections[selectedFilteredConnectionIndex]
        self.allConnections.removeAll { connection in
            selectedConnection == connection
        }
        self.filterConnections()
    }
    
    func saveConnections(connection: Dictionary<String, String>) {
        log_callback_str(message: "\(#function): selectedUnfilteredConnectionIndex: \(selectedUnfilteredConnectionIndex)")
        var copyOfConnection = connection
        if copyOfConnection["saveCredentials"] == "true" &&
            copyOfConnection["password"] != "" {
            saveCredentialsToSecureStorage(
                connection: connection,
                usernameField: "username",
                passwordField: "password",
                domainField: "domain",
                addressField: "address",
                portField: "port"
            )
        }
        if copyOfConnection["saveSshCredentials"] == "true" &&
            copyOfConnection["sshPass"] != "" {
            saveCredentialsToSecureStorage(
                connection: connection,
                usernameField: "sshUser",
                passwordField: "sshPass",
                domainField: nil,
                addressField: "sshAddress",
                portField: "sshPort"
            )
        }
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
        copyOfConnection["password"] = ""
        copyOfConnection["sshPass"] = ""
        copyOfConnection["sshPassphrase"] = ""
        copyOfConnection["sshPrivateKey"] = ""
        if selectedUnfilteredConnectionIndex >= 0 {
            self.allConnections[selectedUnfilteredConnectionIndex] = copyOfConnection
        }
        self.settings.set(self.allConnections, forKey: Constants.SAVED_CONNECTIONS_KEY)
        self.settings.set(self.defaultSettings, forKey: Constants.SAVED_DEFAULT_SETTINGS_KEY)
    }
    
    fileprivate func getSaveQuery(
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
    
    private func saveCredentialsToSecureStorage(
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
        guard let uniqueField = connection["screenShotFile"] else {
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
    
    func deselectConnection() {
        log_callback_str(message: "\(#function)")
        self.selectedFilteredConnectionIndex = -1
        self.selectedUnfilteredConnectionIndex = -1
        self.selectedConnection = [:]
        self.editedConnection = [:]
    }
    
    func addNewConnection(connectionName: String) {
        log_callback_str(message: "\(#function)")
        self.deselectConnection()
        self.copyConnectionIntoSelectedConnection(connection: self.defaultSettings, skipKeys: ["screenShotFile"])
        self.selectedConnection["connectionName"] = connectionName
    }
    
    func deleteCurrentConnection() {
        log_callback_str(message: "Deleting connection at index \(selectedFilteredConnectionIndex) and navigating to list of connections screen")
        // Do something only if we were not adding a new connection.
        if selectedFilteredConnectionIndex >= 0 {
            log_callback_str(message: "Deleting connection with index \(selectedFilteredConnectionIndex)")
            let screenShotFile = self.get(at: selectedFilteredConnectionIndex)["screenShotFile"]
            let deleteScreenshotResult = Utils.deleteFile(name: screenShotFile)
            log_callback_str(message: "Deleting connection screenshot \(deleteScreenshotResult)")
            self.removeSelected()
            self.deselectConnection()
            self.saveConnections(connection: selectedConnection)
        } else {
            log_callback_str(message: "We were adding a new connection, so not deleting anything")
        }
        self.stateKeeper?.showConnections()
    }
    
    func saveConnection(connection: Dictionary<String, String>) {
        // Negative index indicates we are adding a connection, otherwise we are editing one.
        if (selectedFilteredConnectionIndex == Constants.DEFAULT_SETTINGS_FLAG) {
            log_callback_str(message: "Saving default settings")
            self.defaultSettings = connection
        } else if (selectedFilteredConnectionIndex < 0) {
            log_callback_str(message: "Saving a new connection and navigating to list of connections")
            self.allConnections.append(connection)
        } else {
            log_callback_str(message: "Saving a connection at index \(self.selectedFilteredConnectionIndex) " +
                             "and navigating to list of connections")
            copyConnectionIntoSelectedConnection(connection: connection)
        }
        self.saveConnections(connection: selectedConnection)
        self.filterConnections()
        self.stateKeeper?.showConnections()
    }
    
    func copyConnectionIntoSelectedConnection(connection: Dictionary<String, String>, skipKeys: [String] = []) {
        connection.forEach() { setting in // Iterate through new settings to avoid losing e.g. ssh and x509 fingerprints
            if !skipKeys.contains(setting.key) {
                self.selectedConnection[setting.key] = setting.value
            }
        }
    }
    
    func selectedConnectionAllowsZoomingOrPanning(setting: String) -> Bool {
        return Bool(selectedConnection[setting] ?? "true") ?? true && !(self.stateKeeper?.macOs ?? false)
    }
    
    func saveImage(image: UIImage) -> Bool {
        log_callback_str(message: #function)
        guard let data = image.jpegData(compressionQuality: 1) ?? image.pngData() else {
            return false
        }
        guard let directory = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) as NSURL else {
            return false
        }
        do {
            let fileName = self.selectedConnection["screenShotFile"] ?? "default"
            log_callback_str(message: "\(#function): screenShotFile: \(fileName)")
            try data.write(to: directory.appendingPathComponent(String(fileName))!)
            self.saveConnections(connection: selectedConnection)
            if self.stateKeeper?.isAtConnectionsListPage() ?? true {
                self.stateKeeper?.showConnections()
            }
            return true
        } catch {
            log_callback_str(message: #function + error.localizedDescription)
            return false
        }
    }
    
    func findFirstByField(field: String, value: String) -> [String: String]? {
        let existing = self.allConnections.filter(
            { (connection) -> Bool in
                value == connection[field]
            }).first
        return existing
    }
    
    func findFirstByName(connectionName: String) -> [String: String]? {
        return findFirstByField(field: "connectionName", value: connectionName)
    }
    
    func findFirstByExternalIdAddressAndPort(externalId: String, address: String, port: String) -> [String: String]? {
        let existing = self.allConnections.filter(
            { (connection) -> Bool in
                externalId == connection["externalId"] &&
                address == connection["address"] &&
                port == connection["port"]
            }).first
        return existing
    }
}
