//
//  ConnectionListPage.swift
//  bVNC
//
//  Created by iordan iordanov on 2024-02-24.
//  Copyright © 2024 iordan iordanov. All rights reserved.
//

import Foundation
import SwiftUI

struct ConnectionsListPage : View {
    @ObservedObject var stateKeeper: StateKeeper
    @State var searchConnectionText: String
    @State var connections: [Dictionary<String, String>]
    
    func connect(index: Int) {
        if self.stateKeeper.currentPage != "connectionInProgress" {
            self.stateKeeper.currentPage = "connectionInProgress"
            let connection = self.elementAt(index: index)
            let requiresVpn = connection["requiresVpn"] == "true"
            if requiresVpn && !self.stateKeeper.isOnMacOsOriPadOnMacOs() {
                self.launchVpnUrl(connection: connection)
            } else {
                self.stateKeeper.connectSaved(connection: connection)
            }
        }
    }
    
    func launchVpnUrl(connection: [String: String]) {
        let scheme = connection["vpnUriScheme"]!
        let host = connection["address"]!
        let port = connection["port"]!
        let externalId = connection["externalId"]!

        let tunneledProtocol = Utils.getTunneledProtocol()

        guard let url = URL(
            string: "\(scheme)://\(host):\(port)/tunnel?tunnelAction=start&remotePort=\(port)&tunneledProtocol=\(tunneledProtocol)&externalId=\(externalId)"
        ) else {
          return
        }

        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    func edit(index: Int) {
        let connection = self.elementAt(index: index)
        self.stateKeeper.editConnection(connection: connection)
    }
    
    func delete(index: Int) {
        let connection = self.elementAt(index: index)
        self.stateKeeper.connections.deleteConnectionById(id: connection["id"]!)
        self.stateKeeper.showConnections()
    }
    
    func elementAt(index: Int) -> [String: String] {
        return self.connections[index]
    }
    
    func getSavedImage(named: String) -> UIImage? {
        if let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            //log_callback_str(message: "\(#function) \(named)")
            return UIImage(contentsOfFile: URL(fileURLWithPath: dir.absoluteString).appendingPathComponent(named).path)
        }
        return nil
    }
    
    func search() {
        self.stateKeeper.connections.setSearchConnectionText(searchConnectionText: searchConnectionText)
        self.stateKeeper.showConnections()
    }
    
    fileprivate func getStaticText(text: String) -> some View {
        return Text(
            self.stateKeeper.localizedString(for: text)
        ).font(.title)
    }
    
    fileprivate func getHelpMessages() -> [LocalizedStringKey] {
        var messages: [LocalizedStringKey]
        if (Utils.isSpice()) {
            messages = [
                LocalizedStringKey(self.stateKeeper.localizedString(for: "ASPICE_HELP")),
                LocalizedStringKey(self.stateKeeper.localizedString(for: "MAIN_HELP_TEXT"))
            ]
        } else {
            messages = [
                LocalizedStringKey(self.stateKeeper.localizedString(for: "MAIN_HELP_TEXT"))
            ]
        }
        return messages
    }
    
    fileprivate func getThumbnailButtonForConnection(_ i: Int) -> some View {
        let screenshotFile = self.connections[i]["id"] ?? ""
        //log_callback_str(message: "\(#function) \(i) connection out of \(self.connections.count): screenshotFile: \(screenshotFile)")
        return Button(action: {
        }) {
            VStack {
                Image(uiImage: self.getSavedImage(named: screenshotFile) ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(5)
                    .frame(maxWidth: 600, maxHeight: 200)
                Text(self.stateKeeper.connections.buildTitle(connection: self.connections[i]))
                    .font(.headline)
                    .padding(5)
                    .background(Color.black)
                    .cornerRadius(5)
                    .foregroundColor(.white)
                    .padding(5)
                    .frame(height:100)
            }
            .padding()
            .foregroundColor(.white)
            .background(Color.black)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white, lineWidth: 2))
            .onTapGesture {
                self.connect(index: i)
            }.onLongPressGesture {
                self.edit(index: i)
            }
        }.buttonStyle(PlainButtonStyle()).contextMenu {
            Button("EDIT_LABEL", action: { edit(index: i) })
            Button("DELETE_LABEL", action: { delete(index: i) })
        }
    }
    
    var body: some View {
        ScrollView {
            VStack {
                HStack() {
                    Button(action: {
                        self.stateKeeper.addNewConnection(connectionName: "")
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                            Text("NEW_LABEL")
                        }.padding()
                    }
                    
                    Button(action: {
                        self.stateKeeper.showHelp(messages: getHelpMessages())
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "info")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                            Text("HELP_LABEL")
                        }.padding()
                    }
                    
                    Button(action: {
                        self.stateKeeper.showLog(title: "SESSION_LOG_LABEL",
                                                 text: self.stateKeeper.clientLog.joined())
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "text.alignleft")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                            Text("LOG_LABEL")
                        }.padding()
                    }
                    
                    Button(action: {
                        self.stateKeeper.editDefaultSetting()
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "gearshape")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                            Text("DEFAULT_SETTINGS_LABEL")
                        }.padding()
                    }
                }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, alignment: .topTrailing).padding()
                
                HStack() {
                    TextField(
                        self.stateKeeper.localizedString(for: "SEARCH_CONNECTION_TEXT"),
                        text: $searchConnectionText,
                        onCommit: {
                            self.search()
                        }
                    ).autocapitalization(.none).font(.title).padding(50).autocorrectionDisabled()
                    
                    Button(action: {
                        self.search()
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }.padding()
                    }
                }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, alignment: .topTrailing).padding()
                
                if (self.connections.count == 0 && Utils.isSpice()) {
                    self.getStaticText(text: "HELP_INSTRUCTIONS")
                } else {
                    ForEach(0 ..< self.connections.count) { i in
                        getThumbnailButtonForConnection(i)
                    }
                }
            }
        }
    }
}
