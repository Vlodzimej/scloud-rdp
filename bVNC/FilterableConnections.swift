//
//  FilterableConnections.swift
//  bVNC
//
//  Created by Iordan Iordanov on 2022-12-05.
//  Copyright © 2022 iordan iordanov. All rights reserved.
//

import Foundation

class FilterableConnections : ObservableObject {
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
        self.allConnections = []
        self.filteredConnections = self.allConnections
        self.loadConnections()
    }
    
    func loadConnections() {
        self.allConnections = self.settings.array(forKey: "connections") as? [Dictionary<String, String>] ?? []
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
    }
    
    func edit(connection: Dictionary<String, String>) -> Void {
        log_callback_str(message: #function)
        self.editedConnection = connection
        self.select(connection: connection)
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
        if selectedUnfilteredConnectionIndex >= 0 {
            self.allConnections[selectedUnfilteredConnectionIndex] = selectedConnection
        }
        self.settings.set(self.allConnections, forKey: "connections")
    }
    
    func deselectConnection() {
        log_callback_str(message: "\(#function)")
        self.selectedFilteredConnectionIndex = -1
        self.selectedUnfilteredConnectionIndex = -1
        self.selectedConnection = [:]
        self.editedConnection = [:]
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
        self.deselectConnection()
        self.stateKeeper?.showConnections()
    }
    
    func selectedConnectionAllowsZoomingOrPanning(setting: String) -> Bool {
        return Bool(selectedConnection[setting] ?? "true") ?? true && !(self.stateKeeper?.macOs ?? false)
    }
    
    func saveImage(image: UIImage) -> Bool {
        log_callback_str(message: #function)
        guard let data = image.jpegData(compressionQuality: 1) ?? image.pngData() else {
            return false
        }
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
            return false
        }
        do {
            let fileName = self.selectedConnection["screenShotFile"] ?? "default"
            log_callback_str(message: "\(#function): fileName: \(fileName)")
            try data.write(to: directory.appendingPathComponent(String(fileName))!)
            self.saveConnections()
            self.stateKeeper?.showConnections()
            return true
        } catch {
            log_callback_str(message: #function + error.localizedDescription)
            return false
        }
    }
}
