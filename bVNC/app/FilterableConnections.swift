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
    var selectedFilteredConnectionIndex = -1
    var selectedUnfilteredConnectionIndex = -1
    var defaultSettings: Dictionary<String, String> = [:]
    var selectedConnection: Dictionary<String, String> = [:]
    var editedConnection: Dictionary<String, String> = [:]
    
    
    init(stateKeeper: StateKeeper?) {
        self.stateKeeper = stateKeeper
        self.allConnections = []
        self.filteredConnections = self.allConnections
        self.loadConnections()
    }
    
    func loadConnections() {
        self.defaultSettings = self.settings.object(
            forKey: Constants.SAVED_DEFAULT_SETTINGS_KEY) as? Dictionary<String, String> ?? [:]
        self.allConnections = self.settings.array(
            forKey: Constants.SAVED_CONNECTIONS_KEY) as? [Dictionary<String, String>] ?? []
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
    
    func saveConnections() {
        log_callback_str(message: "\(#function): selectedUnfilteredConnectionIndex: \(selectedUnfilteredConnectionIndex)")
        var copyOfSelectedConnection = selectedConnection
        if (copyOfSelectedConnection["saveSshCredentials"] == "false") {
            copyOfSelectedConnection["sshPass"] = ""
        }
        if (copyOfSelectedConnection["saveCredentials"] == "false") {
            copyOfSelectedConnection["password"] = ""
        }
        if selectedUnfilteredConnectionIndex >= 0 {
            self.allConnections[selectedUnfilteredConnectionIndex] = copyOfSelectedConnection
        }
        self.settings.set(self.allConnections, forKey: Constants.SAVED_CONNECTIONS_KEY)
        self.settings.set(self.defaultSettings, forKey: Constants.SAVED_DEFAULT_SETTINGS_KEY)
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
            self.saveConnections()
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
        self.saveConnections()
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
