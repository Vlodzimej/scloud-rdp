//
//  FilterableConnections.swift
//  bVNC
//
//  Created by Iordan Iordanov on 2022-12-05.
//  Copyright © 2022 iordan iordanov. All rights reserved.
//

import Foundation

class FilterableConnections {
    var allConnections: [Dictionary<String, String>]
    var filteredConnections: [Dictionary<String, String>]
    var stateKeeper: StateKeeper?
    var settings = UserDefaults.standard
    private var searchConnectionText = ""
    var selectedFilteredConnectionIndex = -1
    var selectedUnfilteredConnectionIndex = -1
    var selectedConnection: Dictionary<String, String> = [:]
    var editedConnection: Dictionary<String, String> = [:]
    
    
    init(stateKeeper: StateKeeper?) {
        self.stateKeeper = stateKeeper
        self.allConnections = self.settings.array(forKey: "connections") as? [Dictionary<String, String>] ?? []
        self.filteredConnections = self.allConnections
    }
    
    func connectionCount() -> Int {
        return self.filteredConnections.count
    }
    
    func setSearchConnectionText(searchConnectionText: String) {
        self.searchConnectionText = searchConnectionText
        self.filterConnections()
    }
    
    func getSearchConnectionText() -> String {
        return self.searchConnectionText
    }
    
    func buildTitle(connection: Dictionary<String, String>) -> String {
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
    
    func filterConnections() {
        self.filteredConnections = allConnections.filter({ (connection) -> Bool in searchConnectionText == "" || buildTitle(connection: connection).contains(searchConnectionText)})
        if searchConnectionText == "" {
            self.stateKeeper?.showConnections()
        }
    }
    
    func edit(connection: Dictionary<String, String>) -> Void {
        self.editedConnection = connection
        self.select(connection: connection)
    }
    
    func select(connection: Dictionary<String, String>) -> Void {
        self.selectedConnection = connection
        self.selectedFilteredConnectionIndex = filteredConnections.firstIndex(of: connection) ?? -1
        self.selectedUnfilteredConnectionIndex = allConnections.firstIndex(of: connection) ?? -1
    }
    
    func get(at: Int) -> Dictionary<String, String> {
        return filteredConnections[at]
    }
    
    func removeSelected() -> Void {
        var selectedConnection = filteredConnections[selectedFilteredConnectionIndex]
        self.allConnections.removeAll { connection in
            selectedConnection == connection
        }
        self.filterConnections()
    }
    
    func saveConnections() {
        log_callback_str(message: "saveConnections")
        if selectedUnfilteredConnectionIndex >= 0 {
            self.allConnections[selectedUnfilteredConnectionIndex] = selectedConnection
        }
        self.settings.set(self.allConnections, forKey: "connections")
    }
    
    func deselectConnection() {
        self.selectedFilteredConnectionIndex = -1
        self.selectedUnfilteredConnectionIndex = -1
        self.selectedConnection = [:]
    }
    
    func deleteCurrentConnection() {
        log_callback_str(message: "Deleting connection at index \(selectedFilteredConnectionIndex) and navigating to list of connections screen")
        // Do something only if we were not adding a new connection.
        if selectedFilteredConnectionIndex >= 0 {
            log_callback_str(message: "Deleting connection with index \(selectedFilteredConnectionIndex)")
            let screenShotFile = self.get(at: selectedFilteredConnectionIndex)["screenShotFile"]!
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
        if (selectedFilteredConnectionIndex < 0) {
            log_callback_str(message: "Saving a new connection and navigating to list of connections")
            self.allConnections.append(connection)
        } else {
            log_callback_str(message: "Saving a connection at index \(self.selectedFilteredConnectionIndex) and navigating to list of connections")
            connection.forEach() { setting in // Iterate through new settings to avoid losing e.g. ssh and x509 fingerprints
                self.selectedConnection[setting.key] = setting.value
            }
        }
        self.saveConnections()
        self.filterConnections()
        self.stateKeeper?.showConnections()
    }
    
    func selectedConnectionAllowsZoomingOrPanning(setting: String) -> Bool {
        return Bool(selectedConnection[setting] ?? "true") ?? true && !(self.stateKeeper?.macOs ?? false)
    }
}
