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
    var selectedConnectionId = Constants.UNSELECTED_SETTINGS_ID
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
    
    fileprivate func migrateConnections(_ connections: [[String : String]]) -> [[String : String]]  {
        var newConnections = connections
        while connectionsVersion < Constants.CURRENT_CONNECTIONS_VERSION {
            log_callback_str(message: "Migrating connections from version \(connectionsVersion) to version \(Constants.CURRENT_CONNECTIONS_VERSION)")
            deselectConnection()
            if connectionsVersion <= 1 {
                newConnections = migrateIdAndMoveCredentialsToSecureStorage(connections)
                connectionsVersion = 2
            }
            self.allConnections = newConnections
            self.saveConnections()
            self.settings.set(connectionsVersion, forKey: Constants.SAVED_CONNECTIONS_VERSION_KEY)
        }
        return newConnections
    }
    
    fileprivate func migrateIdAndMoveCredentialsToSecureStorage(
        _ connections: [[String : String]]
    ) -> [[String : String]] {
        var newConnections: [[String : String]] = []
        connections.forEach { connection in
            let id = connection["screenShotFile"]
            log_callback_str(message: "\(#function) connection id \(id ?? "")")
            var copyOfConnectionCopyForSavingCredentialsPurposes = connection
            var copyOfConnectionMigratedWithCredentialsRetained = connection
            copyOfConnectionCopyForSavingCredentialsPurposes["id"] = id
            copyOfConnectionMigratedWithCredentialsRetained["id"] = id
            _ = SecureStorageDelegate.saveCredentialsForConnection(
                connection: copyOfConnectionCopyForSavingCredentialsPurposes
            )
            newConnections.append(copyOfConnectionMigratedWithCredentialsRetained)
        }
        return newConnections
    }
    
    fileprivate func loadCredentialsForAllConnections(_ connections: [[String : String]]) -> [[String : String]] {
        log_callback_str(message: #function)
        var newConnections: [[String : String]] = []
        for connection in connections {
            let connectionWithCredentials = SecureStorageDelegate.loadCredentialsForConnection(
                connection: connection
            )
            newConnections.append(connectionWithCredentials)
        }
        return newConnections
    }
    
    fileprivate func saveCredentials(_ connections: [[String : String]]) -> [[String : String]] {
        var newConnections: [[String : String]] = []
        connections.forEach { connection in
            let newConnection = connection
            let connectionWithoutCredentials = SecureStorageDelegate.saveCredentialsForConnection(
                connection: newConnection
            )
            newConnections.append(connectionWithoutCredentials)
        }
        return newConnections
    }
    
    func loadConnections() {
        self.defaultSettings = self.settings.object(
            forKey: Constants.SAVED_DEFAULT_SETTINGS_KEY) as? Dictionary<String, String> ?? [:]
        self.allConnections = self.settings.array(
            forKey: Constants.SAVED_CONNECTIONS_KEY) as? [Dictionary<String, String>] ?? []
        self.allConnections = migrateConnections(self.allConnections)
        self.allConnections = loadCredentialsForAllConnections(self.allConnections)
        self.filteredConnections = self.allConnections
        self.filterConnections()
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
        selectedConnectionId = Constants.DEFAULT_SETTINGS_ID
        selectedFilteredConnectionIndex = Constants.DEFAULT_SETTINGS_FLAG
        selectedUnfilteredConnectionIndex = Constants.DEFAULT_SETTINGS_FLAG
        self.selectedConnection = defaultSettings
        self.editedConnection = defaultSettings
    }
    
    fileprivate func getConnectionId(_ connection: [String : String]) -> String {
        return connection["id"] ?? Constants.UNSELECTED_SETTINGS_ID
    }
    
    func select(connection: Dictionary<String, String>) -> Void {
        log_callback_str(message: #function)
        self.selectedConnection = connection
        self.selectedConnectionId = getConnectionId(connection)
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
    
    func overwriteOneConnectionAndSaveConnections(
        connection: Dictionary<String, String>
    ) {
        log_callback_str(message: "\(#function): selectedUnfilteredConnectionIndex: \(selectedUnfilteredConnectionIndex)")
        _ = SecureStorageDelegate.saveCredentialsForConnection(connection: connection)
        
        log_callback_str(message: "\(#function): after saving credentials, original connection: \(connection)")

        if selectedUnfilteredConnectionIndex >= 0 {
            self.allConnections[selectedUnfilteredConnectionIndex] = connection
        }
        if selectedConnectionId != Constants.UNSELECTED_SETTINGS_ID {
            self.replaceConnectionById(
                id: selectedConnectionId, connection: connection, connections: self.allConnections
            )
        }
        saveConnections()
        saveDefaultSettings()
    }
    
    func saveConnections() {
        log_callback_str(message: "\(#function)")
        let connections = saveCredentials(self.allConnections)
        self.settings.set(connections, forKey: Constants.SAVED_CONNECTIONS_KEY)
    }
    
    func saveDefaultSettings() {
        log_callback_str(message: "\(#function)")
        self.settings.set(self.defaultSettings, forKey: Constants.SAVED_DEFAULT_SETTINGS_KEY)
    }
    
    fileprivate func replaceConnectionById(
        id: String,
        connection: Dictionary<String, String>,
        connections: [Dictionary<String, String>]
    ) {
        let indexFound = connections.firstIndex(where: { $0["id"] == id }) ?? -1
        if indexFound >= 0 {
            self.allConnections[indexFound] = connection
        }
    }
    
    func deselectConnection() {
        log_callback_str(message: "\(#function)")
        self.selectedConnectionId = Constants.UNSELECTED_SETTINGS_ID
        self.selectedFilteredConnectionIndex = -1
        self.selectedUnfilteredConnectionIndex = -1
        self.selectedConnection = [:]
        self.editedConnection = [:]
    }
    
    func addNewConnection(connectionName: String) {
        log_callback_str(message: "\(#function)")
        self.deselectConnection()
        self.copyConnectionIntoSelectedConnection(connection: self.defaultSettings, skipKeys: ["id"])
        self.selectedConnection["connectionName"] = connectionName
    }
    
    func deleteCurrentConnection() {
        log_callback_str(message: "Deleting connection at index \(selectedFilteredConnectionIndex) and navigating to list of connections screen")
        // Do something only if we were not adding a new connection.
        if selectedFilteredConnectionIndex >= 0 {
            log_callback_str(message: "Deleting connection with index \(selectedFilteredConnectionIndex)")
            let connection = self.get(at: selectedFilteredConnectionIndex)
            let screenShotFile = connection["id"]
            let deleteScreenshotResult = Utils.deleteFile(name: screenShotFile)
            log_callback_str(message: "Deleting connection screenshot result: \(deleteScreenshotResult)")
            SecureStorageDelegate.deleteCredentialsForConnection(connection: connection)
            self.removeSelected()
            self.deselectConnection()
            self.saveConnections()
        } else {
            log_callback_str(message: "We were adding a new connection, so not deleting anything")
        }
        self.stateKeeper?.showConnections()
    }
    
    func overwriteOneConnectionAndNavigate(connection: Dictionary<String, String>) {
        // Negative index indicates we are adding a connection, otherwise we are editing one.
        if (selectedFilteredConnectionIndex == Constants.DEFAULT_SETTINGS_FLAG) {
            log_callback_str(message: "\(#function) Saving default settings")
            self.defaultSettings = connection
        } else if (selectedFilteredConnectionIndex < 0) {
            log_callback_str(message: "\(#function) Saving a new connection")
            self.allConnections.append(connection)
        } else {
            log_callback_str(message: "\(#function) Saving connection at index \(self.selectedFilteredConnectionIndex)")
            copyConnectionIntoSelectedConnection(connection: connection)
        }
        self.overwriteOneConnectionAndSaveConnections(connection: connection)
        self.filterConnections()
        log_callback_str(message: "\(#function) Navigating to list of connections")
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
            let fileName = self.selectedConnection["id"] ?? Constants.DEFAULT_SETTINGS_ID
            log_callback_str(message: "\(#function): screenShotFile: \(fileName)")
            try data.write(to: directory.appendingPathComponent(String(fileName))!)
            self.saveConnections()
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
