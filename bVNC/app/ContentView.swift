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
import Combine
import SwiftUI

struct MultilineTextView: UIViewRepresentable {
    var placeholder: String
    @Binding var text: String
    
    var minHeight: CGFloat
    @Binding var calculatedHeight: CGFloat
    
    init(placeholder: String, text: Binding<String>, minHeight: CGFloat, calculatedHeight: Binding<CGFloat>) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
        self._calculatedHeight = calculatedHeight
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        
        // Decrease priority of content resistance, so content would not push external layout set in SwiftUI
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        textView.isScrollEnabled = false
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        // Set the placeholder
        textView.text = placeholder
        textView.textColor = UIColor.lightGray
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != self.text {
            textView.text = self.text
        }
        
        recalculateHeight(view: textView)
    }
    
    func recalculateHeight(view: UIView) {
        let newSize = view.sizeThatFits(CGSize(width: view.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
        if minHeight < newSize.height && $calculatedHeight.wrappedValue != newSize.height {
            DispatchQueue.main.async {
                self.$calculatedHeight.wrappedValue = newSize.height // !! must be called asynchronously
            }
        } else if minHeight >= newSize.height && $calculatedHeight.wrappedValue != minHeight {
            DispatchQueue.main.async {
                self.$calculatedHeight.wrappedValue = self.minHeight // !! must be called asynchronously
            }
        }
    }
    
    class Coordinator : NSObject, UITextViewDelegate {
        
        var parent: MultilineTextView
        
        init(_ uiTextView: MultilineTextView) {
            self.parent = uiTextView
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // This is needed for multistage text input (eg. Chinese, Japanese)
            if textView.markedTextRange == nil {
                parent.text = textView.text ?? String()
                parent.recalculateHeight(view: textView)
            }
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == UIColor.lightGray {
                textView.text = nil
                textView.textColor = UIColor.lightGray
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.lightGray
            }
        }
    }
}

struct ContentView : View {
    @ObservedObject var stateKeeper: StateKeeper
    @State var searchConnectionText: String
    @State var filteredConnections: [Dictionary<String, String>]
    
    func updateConnections(filteredConnections: [Dictionary<String, String>]) {
        self.filteredConnections = filteredConnections
    }
    
    fileprivate func getScreenShotFile(connection: [String : String]) -> String {
        var screenShotFile: String? = connection["screenShotFile"]
        if screenShotFile == stateKeeper.connections.defaultSettings["screenShotFile"] {
            screenShotFile = nil
        }
        return screenShotFile ?? UUID().uuidString
    }
    
    var body: some View {
        let selectedConnection = stateKeeper.connections.selectedConnection
        VStack {
            if stateKeeper.currentPage == "connectionsList" {
                ConnectionsList(stateKeeper: stateKeeper, searchConnectionText: searchConnectionText, connections: filteredConnections)
            } else if stateKeeper.currentPage == "addOrEditConnection" {
                let screenshotFile = getScreenShotFile(connection: selectedConnection)
                AddOrEditConnectionPage(
                    stateKeeper: stateKeeper,
                    connectionNameText: selectedConnection["connectionName"] ?? "",
                    sshAddressText: selectedConnection["sshAddress"] ?? "",
                    sshPortText: selectedConnection["sshPort"] ?? "22",
                    sshUserText: selectedConnection["sshUser"] ?? "",
                    sshPassText: selectedConnection["sshPass"] ?? "",
                    saveSshCredentials: Bool(selectedConnection["saveSshCredentials"] ?? "true") ?? true,
                    sshPassphraseText: selectedConnection["sshPassphrase"] ?? "",
                    sshPrivateKeyText: selectedConnection["sshPrivateKey"] ?? "",
                    sshFingerprintSha256: selectedConnection["sshFingerprintSha256"] ?? "",
                    x509FingerprintSha256: selectedConnection["x509FingerprintSha256"] ?? "",
                    x509FingerprintSha512: selectedConnection["x509FingerprintSha512"] ?? "",
                    addressText: selectedConnection["address"] ?? "",
                    portText: selectedConnection["port"] ?? Utils.getDefaultPort(),
                    tlsPortText: selectedConnection["tlsPort"] ?? "-1",
                    certSubjectText: selectedConnection["certSubject"] ?? "",
                    certAuthorityText: selectedConnection["certAuthority"] ?? "",
                    keyboardLayoutText: selectedConnection["keyboardLayout"] ??
                    Constants.DEFAULT_LAYOUT,
                    domainText: selectedConnection["domain"] ?? "",
                    usernameText: selectedConnection["username"] ?? "",
                    passwordText: selectedConnection["password"] ?? "",
                    saveCredentials: Bool(selectedConnection["saveCredentials"] ?? "true") ?? true,
                    screenShotFile: screenshotFile,
                    allowZooming: Bool(selectedConnection["allowZooming"] ?? "true") ?? true,
                    allowPanning: Bool(selectedConnection["allowPanning"] ?? "true") ?? true,
                    showSshTunnelSettings: Bool(selectedConnection["showSshTunnelSettings"] ?? "false")! || (selectedConnection["sshAddress"] ?? "") != "",
                    externalId: selectedConnection["externalId"] ?? "",
                    requiresVpn: Bool(selectedConnection["requiresVpn"] ?? "true") ?? false,
                    vpnUriScheme: selectedConnection["vpnUriScheme"] ?? ""
                )

            } else if stateKeeper.currentPage == "genericProgressPage" {
                ProgressPage(stateKeeper: stateKeeper)
            } else if stateKeeper.currentPage == "connectionInProgress" {
                ConnectionInProgressPage(stateKeeper: stateKeeper)
            } else if stateKeeper.currentPage == "connectedSession" {
                ConnectedSessionPage()
            } else if stateKeeper.currentPage == "dismissableErrorMessage" {
                DismissableLogDialog(stateKeeper: stateKeeper)
            } else if stateKeeper.currentPage == "mustExitErrorMessage" {
                DismissableLogDialog(stateKeeper: stateKeeper, dismissAction: "exit")
            } else if stateKeeper.currentPage == "dismissableMessage" {
                DismissableMessageDialog(stateKeeper: stateKeeper)
            } else if stateKeeper.currentPage == "helpDialog" {
                HelpDialog(stateKeeper: stateKeeper)
            } else if stateKeeper.currentPage == "yesNoMessage" {
                YesNoDialog(stateKeeper: stateKeeper)
            } else if stateKeeper.currentPage == "disconnectionInProgress" {
                DismissableBlankPage(stateKeeper: stateKeeper)
            }
        }
    }
}

struct ConnectionsList : View {
    @ObservedObject var stateKeeper: StateKeeper
    @State var searchConnectionText: String
    @State var connections: [Dictionary<String, String>]
    
    func connect(index: Int) {
        if self.stateKeeper.currentPage != "connectionInProgress" {
            self.stateKeeper.currentPage = "connectionInProgress"
            let connection = self.elementAt(index: index)
            if (connection["requiresVpn"] == "true") {
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

        var tunneledProtocol = "VNC"
        if Utils.isRdp() {
            tunneledProtocol = "VNC"
        } else if Utils.isSpice() {
            tunneledProtocol = "SPICE"
        }

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
    
    func elementAt(index: Int) -> [String: String] {
        return self.connections[index]
    }
    
    func getSavedImage(named: String) -> UIImage? {
        if let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            log_callback_str(message: "\(#function) \(named)")
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
        let screenshotFile = self.connections[i]["screenShotFile"] ?? ""
        log_callback_str(message: "\(#function) \(i) connection out of \(self.connections.count): screenshotFile: \(screenshotFile)")
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
        }.buttonStyle(PlainButtonStyle())
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

struct AddOrEditConnectionPage : View {
    var settings: UserDefaults = UserDefaults.standard
    @ObservedObject var stateKeeper: StateKeeper
    @State var connectionNameText: String
    @State var sshAddressText: String
    @State var sshPortText: String
    @State var sshUserText: String
    @State var sshPassText: String
    @State var saveSshCredentials: Bool
    @State var sshPassphraseText: String
    @State var sshPrivateKeyText: String
    @State var sshFingerprintSha256: String
    @State var x509FingerprintSha256: String
    @State var x509FingerprintSha512: String
    @State var addressText: String
    @State var portText: String
    @State var tlsPortText: String
    @State var certSubjectText: String
    @State var certAuthorityText: String
    @State var keyboardLayoutText: String
    @State var domainText: String
    @State var usernameText: String
    @State var passwordText: String
    @State var saveCredentials: Bool
    @State var screenShotFile: String
    @State var textHeight: CGFloat = 20
    @State var allowZooming: Bool
    @State var allowPanning: Bool
    @State var showSshTunnelSettings: Bool

    @State var externalId: String
    @State var requiresVpn: Bool
    @State var vpnUriScheme: String

    func retrieveConnectionDetails() -> [String : String] {
        var connection = [
            "connectionName": self.connectionNameText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshAddress": self.sshAddressText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshPort": self.sshPortText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshUser": self.sshUserText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshPass": self.sshPassText.trimmingCharacters(in: .whitespacesAndNewlines),
            "saveSshCredentials": String(self.saveSshCredentials),
            "sshPassphrase": self.sshPassphraseText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshPrivateKey": self.sshPrivateKeyText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshFingerprintSha256": self.sshFingerprintSha256.trimmingCharacters(in: .whitespacesAndNewlines),
            "x509FingerprintSha256": self.x509FingerprintSha256.trimmingCharacters(in: .whitespacesAndNewlines),
            "x509FingerprintSha512": self.x509FingerprintSha512.trimmingCharacters(in: .whitespacesAndNewlines),
            "address": self.addressText.trimmingCharacters(in: .whitespacesAndNewlines),
            "port": self.portText.trimmingCharacters(in: .whitespacesAndNewlines),
            "domain": self.domainText.trimmingCharacters(in: .whitespacesAndNewlines),
            "username": self.usernameText.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": self.passwordText.trimmingCharacters(in: .whitespacesAndNewlines),
            "saveCredentials": String(self.saveCredentials),
            "screenShotFile": self.screenShotFile.trimmingCharacters(in: .whitespacesAndNewlines),
            "allowZooming": String(self.allowZooming),
            "allowPanning": String(self.allowPanning),
            "showSshTunnelSettings": String(self.showSshTunnelSettings),
            "externalId": self.externalId.trimmingCharacters(in: .whitespacesAndNewlines),
            "requiresVpn": String(self.requiresVpn),
            "vpnUriScheme": self.vpnUriScheme.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        if Utils.isSpice() {
            connection["tlsPort"] = self.tlsPortText.trimmingCharacters(in: .whitespacesAndNewlines)
            connection["certSubject"] = self.certSubjectText.trimmingCharacters(in: .whitespacesAndNewlines)
            connection["certAuthority"] = self.certAuthorityText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if Utils.isSpice() || Utils.isRdp() {
            connection["keyboardLayout"] = self.keyboardLayoutText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return connection
    }
    
    func getKeyboardLayouts() -> [String] {
        
        return stateKeeper.keyboardLayouts.sorted()
    }
    
    fileprivate func getCredentialsHeading() -> some View {
        var credentialsHeading = Text("ENTER_VNC_CREDENTIALS_LABEL").font(.title)
        if Utils.isRdp() {
            credentialsHeading = Text("ENTER_RDP_CREDENTIALS_LABEL").font(.title)
        }
        if Utils.isSpice() {
            credentialsHeading = Text("ENTER_SPICE_CREDENTIALS_LABEL").font(.title)
        }
        return credentialsHeading
    }
    
    fileprivate func getCredentialsFields() -> some View {
        return VStack {
            if Utils.isRdp() {
                getTextField(text: "DOMAIN_LABEL", binding: $domainText)
            }
            if Utils.isVnc() {
                getTextField(text: "USER_LABEL", binding: $usernameText)
            } else if Utils.isRdp() {
                getTextField(text: "MANDATORY_USER_LABEL", binding: $usernameText)
            }
            getSecureField(text: "PASSWORD_LABEL", binding: $passwordText)
        }.padding()
    }
    
    fileprivate func saveButtonActions() {
        let selectedConnection: [String : String] = self.retrieveConnectionDetails()
        self.stateKeeper.connections.saveConnection(connection: selectedConnection)
    }
    
    fileprivate func getSaveButton() -> Button<some View> {
        return Button(action: {
            saveButtonActions()
        }) {
            getButton(imageName: "folder.badge.plus", textLabel: "SAVE_LABEL")
        }
    }
    
    fileprivate func saveAndConnectButtonActions(saveCredentials: Bool) {
        var selectedConnection: [String : String] = self.retrieveConnectionDetails()
        if self.stateKeeper.requestingCredentials {
            self.stateKeeper.requestingCredentials = false
            selectedConnection["saveCredentials"] = String(saveCredentials)
        }
        if self.stateKeeper.requestingSshCredentials {
            self.stateKeeper.requestingSshCredentials = false
            selectedConnection["saveSshCredentials"] = String(saveCredentials)
        }
        self.stateKeeper.connections.saveConnection(connection: selectedConnection)
        self.stateKeeper.connect(connection: selectedConnection)
    }
    
    fileprivate func getSaveAndConnectButton() -> Button<some View> {
        return Button(action: {
            saveAndConnectButtonActions(saveCredentials: true)
        }) {
            getButton(imageName: "rectangle.center.inset.filled.badge.plus", textLabel: "SAVE_AND_CONNECT_LABEL")
        }
    }
    
    fileprivate func getDoNotSaveAndConnectButton() -> Button<some View> {
        return Button(action: {
            saveAndConnectButtonActions(saveCredentials: false)
        }) {
            getButton(imageName: "rectangle.center.inset.filled", textLabel: "DO_NOT_SAVE_AND_CONNECT_LABEL")
        }
    }
    
    fileprivate func deleteButtonActions() {
        self.stateKeeper.connections.deleteCurrentConnection()
        self.stateKeeper.connections.deselectConnection()
    }
    
    fileprivate func getDeleteButton() -> Button<some View> {
        return Button(action: {
            deleteButtonActions()
        }) {
            getButton(imageName: "trash", textLabel: "DELETE_LABEL")
        }
    }
    
    fileprivate func cancelButtonActions() {
        self.stateKeeper.requestingCredentials = false
        self.stateKeeper.requestingSshCredentials = false
        self.stateKeeper.connections.deselectConnection()
        self.stateKeeper.showConnections()
    }
    
    fileprivate func getCancelButton() -> Button<some View> {
        return Button(action: {
            cancelButtonActions()
        }) {
            getButton(imageName: "arrowshape.turn.up.left", textLabel: "CANCEL_LABEL")
        }
    }
    
    fileprivate func getHelpButtonActions() {
        var help_messages_list: [LocalizedStringKey] = ["VNC_CONNECTION_SETUP_HELP_TEXT", "UI_SETUP_HELP_TEXT"]
        if self.stateKeeper.sshAppIds.contains(UIApplication.appId ?? "") {
            help_messages_list.insert("SSH_CONNECTION_SETUP_HELP_TEXT", at: 0)
        }
        self.stateKeeper.connections.edit(connection: self.retrieveConnectionDetails())
        self.stateKeeper.showHelp(messages: help_messages_list)
    }
    
    fileprivate func getButton(imageName: String, textLabel: String) -> some View {
        return VStack(spacing: 10) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            Text(self.stateKeeper.localizedString(for: textLabel))
                .lineLimit(1)
                .allowsTightening(true)
                .scaledToFit()
                .minimumScaleFactor(0.70)
        }.padding()
    }
    
    fileprivate func getHelpButton() -> Button<some View> {
        return Button(action: {
            getHelpButtonActions()
        }) {
            getButton(imageName: "info", textLabel: "HELP_LABEL")
        }
    }
    
    fileprivate func getTopButtons() -> some View {
        return HStack(spacing: 5) {
            getSaveButton()
            getDeleteButton()
            getCancelButton()
            getHelpButton()
        }
    }
    
    fileprivate func getCredentialsButtons() -> some View {
        return HStack(spacing: 5) {
            getCancelButton()
            getDoNotSaveAndConnectButton()
            getSaveAndConnectButton()
        }
    }
    
    fileprivate func getConnectionNameField() -> some View {
        return VStack {
            getTextField(text: "CONNECTION_NAME_LABEL", binding: $connectionNameText)
        }.padding()
    }
    
    fileprivate func getSshCredentialsHeading() -> some View {
        return Text("ENTER_SSH_CREDENTIALS_LABEL").font(.title)
    }
    
    fileprivate func getSshCredentialsFields() -> some View {
        return VStack {
            getTextField(text: "SSH_USER_LABEL", binding: $sshUserText)
            getSecureField(text: "SSH_PASSWORD_LABEL", binding: $sshPassText)
        }
    }
    
    fileprivate func getSshSettingsFields() -> some View {
        return VStack {
            Toggle(isOn: $showSshTunnelSettings) {
                Text("SHOW_SSH_TUNNEL_SETTINGS_LABEL")
            }.font(.title)
            
            if self.showSshTunnelSettings {
                VStack {
                    Text("SSH_TUNNEL_LABEL").font(.title)
                    getTextField(text: "SSH_SERVER_LABEL", binding: $sshAddressText)
                    getTextField(text: "SSH_PORT_LABEL", binding: $sshPortText)
                    getSshCredentialsFields()
                    getSecureField(text: "SSH_PASSPHRASE_LABEL", binding: $sshPassphraseText)
                    VStack {
                        Divider()
                        HStack {
                            Text("SSH_KEY_LABEL").font(.title)
                            Divider()
                            MultilineTextView(placeholder: "", text: $sshPrivateKeyText, minHeight: self.textHeight, calculatedHeight: $textHeight).frame(minHeight: self.textHeight, maxHeight: self.textHeight)
                            Divider()
                        }
                        Divider()
                    }
                }
            }
        }.padding()
    }
    
    fileprivate func shouldShowSshSettingsFields() -> Bool {
        return self.stateKeeper.sshAppIds.contains(UIApplication.appId ?? "")
    }
    
    fileprivate func getTextField(text: String, binding: Binding<String>) -> some View {
        return TextField(
            self.stateKeeper.localizedString(for: text),
            text: binding
        ).autocapitalization(.none).font(.title).autocorrectionDisabled()
    }
    
    fileprivate func getSecureField(text: String, binding: Binding<String>) -> some View {
        return SecureField(
            self.stateKeeper.localizedString(for: text),
            text: binding
        ).autocapitalization(.none).font(.title).autocorrectionDisabled()
    }
    
    fileprivate func getAddressAndPortFields() -> some View {
        return VStack {
            Text("MAIN_CONNECTION_SETTINGS_LABEL").font(.title)
            getTextField(text: "ADDRESS_LABEL", binding: $addressText)
            getTextField(text: "PORT_LABEL", binding: $portText)
            if Utils.isSpice() {
                getTextField(text: "TLS_PORT_LABEL", binding: $tlsPortText)
            }
        }.padding()
    }
    
    fileprivate func getLayoutAndCertFields() -> some View {
        return VStack {
            if Utils.isSpice() || Utils.isRdp() {
                HStack {
                    Text("KEYBOARD_LAYOUT_LABEL").font(.title)
                    Picker("", selection: $keyboardLayoutText) {
                        ForEach(self.getKeyboardLayouts(), id: \.self) {
                            Text($0).font(.title)
                        }
                    }.font(.title).padding()
                }
            }
            
            if Utils.isSpice() {
                getTextField(text: "CERT_SUBJECT_LABEL", binding: $certSubjectText)
                VStack {
                    Divider()
                    HStack {
                        Text("CERT_AUTHORITY_LABEL").font(.title)
                        Divider()
                        MultilineTextView(placeholder: "", text: $certAuthorityText, minHeight: self.textHeight, calculatedHeight: $textHeight).frame(minHeight: self.textHeight, maxHeight: self.textHeight)
                        Divider()
                    }
                    Divider()
                }
            }
        }.padding()
    }
    
    fileprivate func getUiOptionsFields() -> some View {
        return VStack {
            Text("USER_INTERFACE_SETTINGS_LABEL").font(.title)
            Toggle(isOn: $allowZooming) {
                Text("ALLOW_DESKTOP_ZOOMING_LABEL").font(.title)
            }
            Toggle(isOn: $allowPanning) {
                Text("ALLOW_DESKTOP_PANNING_LABEL").font(.title)
            }
        }.padding()
    }
    
    fileprivate func getConnectionEditBody() -> some View {
        return ScrollView {
            VStack {
                getTopButtons()
                getConnectionNameField()
                if shouldShowSshSettingsFields() {
                    getSshSettingsFields()
                }
                getAddressAndPortFields()
                getCredentialsFields()
                getLayoutAndCertFields()
                getUiOptionsFields()
            }
        }
    }
    
    fileprivate func getSshCredentialsRequestBody() -> some View {
        return VStack(alignment: .leading) {
            getSshCredentialsHeading()
            getSshCredentialsFields()
            getCredentialsButtons()
        }.padding()
    }
    
    fileprivate func getCredentialsRequestBody() -> some View {
        return VStack(alignment: .leading) {
            getCredentialsHeading()
            getCredentialsFields()
            getCredentialsButtons()
        }.padding()
    }
    
    var body: some View {
        if self.stateKeeper.requestingSshCredentials {
            getSshCredentialsRequestBody()
        } else if self.stateKeeper.requestingCredentials {
            getCredentialsRequestBody()
        } else {
            getConnectionEditBody()
        }
    }
}

struct ConnectionInProgressPage : View {
    
    @ObservedObject var stateKeeper: StateKeeper
    
    var body: some View {
        VStack {
            Text("CONNECTING_TO_SERVER_LABEL")
            Button(action: {
                self.stateKeeper.disconnectFromCancelButton()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                    Text("CANCEL_LABEL")
                }.padding()
            }
        }
    }
}

struct ProgressPage : View {
    @ObservedObject var stateKeeper: StateKeeper
    
    func getCurrentTransition() -> String {
        return stateKeeper.currentTransition
    }
    
    var body: some View {
        VStack {
            Text(getCurrentTransition())
        }
    }
}

struct ConnectedSessionPage : View {
    var body: some View {
        Text("")
    }
}

struct HelpDialog : View {
    @ObservedObject var stateKeeper: StateKeeper
    
    var body: some View {
        VStack {
            ScrollView {
                Text("HELP_LABEL").font(.title).padding()
                ForEach(self.stateKeeper.localizedMessages, id: \.self) { message in
                    Text(message).font(.body).padding()
                }
                if self.stateKeeper.helpDialogAppIds.contains(UIApplication.appId ?? "") {
                    VStack {
                        Button(action: {
                            UIApplication.shared.open(URL(string: "https://groups.google.com/forum/#!forum/bvnc-ardp-aspice-opaque-remote-desktop-clients")!, options: [:], completionHandler: nil)
                            
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                Text("SUPPORT_FORUM_LABEL")
                            }.padding()
                        }
                        
                        Button(action: {
                            UIApplication.shared.open(URL(string: "https://github.com/iiordanov/remote-desktop-clients/issues")!, options: [:], completionHandler: nil)
                            
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "ant.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                Text("REPORT_BUG_LABEL")
                            }.padding()
                        }
                        
                        Button(action: {
                            UIApplication.shared.open(URL(string: "https://www.youtube.com/watch?v=16pwo3wwv9w")!, options: [:], completionHandler: nil)
                            
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "video.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                Text("HELP_VIDEOS_LABEL")
                            }.padding()
                        }
                        
                    }
                }
            }
            Button(action: {
                self.stateKeeper.dismissHelp()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                    Text("DISMISS_LABEL")
                }.padding()
            }
        }
    }
}


struct DismissableBlankPage : View {
    @ObservedObject var stateKeeper: StateKeeper
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    self.stateKeeper.showConnections()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                        Text("DISMISS_LABEL")
                    }.padding()
                }
            }
        }
    }
}

struct DismissableLogDialog : View {
    @ObservedObject var stateKeeper: StateKeeper
    var dismissAction: String = "default"
    
    func getTitle() -> LocalizedStringKey {
        return stateKeeper.localizedTitle ?? ""
    }
    
    var body: some View {
        VStack {
            ScrollView {
                Text(self.getTitle()).font(.title)
                Button(action: {
                    self.stateKeeper.showLog(title: "SESSION_LOG_LABEL",
                                             text: self.stateKeeper.clientLog.joined())
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "text.alignleft")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                        Text("LOG_LABEL")
                    }.padding()
                }
            }
            Button(action: {
                if self.dismissAction == "exit" {
                    self.stateKeeper.exitNow()
                } else {
                    self.stateKeeper.showConnections()
                    
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                    Text("DISMISS_LABEL")
                }.padding()
            }
        }
    }
}

struct DismissableMessageDialog : View {
    @ObservedObject var stateKeeper: StateKeeper
    
    func getTitle() -> LocalizedStringKey {
        return stateKeeper.localizedTitle ?? ""
    }
    
    func getMessage() -> String {
        return stateKeeper.message
    }
    
    var body: some View {
        VStack {
            ScrollView {
                Text(self.getTitle()).font(.title).padding()
                Text(self.getMessage()).font(.body).padding()
            }
            HStack {
                Button(action: {
                    let pasteboard = UIPasteboard.general
                    pasteboard.string = self.getMessage()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.on.clipboard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                        Text("COPY_TO_CLIPBOARD_LABEL")
                    }.padding()
                }
                Button(action: {
                    self.stateKeeper.showConnections()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                        Text("DISMISS_LABEL")
                    }.padding()
                }
            }
        }
    }
}

struct YesNoDialog : View {
    @ObservedObject var stateKeeper: StateKeeper
    
    func getLocalizedTitle() -> LocalizedStringKey {
        return stateKeeper.localizedTitle ?? ""
    }
    
    func setResponse(response: Bool) -> Void {
        stateKeeper.setYesNoReponse(response: response,
                                    pageYes: "connectedSession",
                                    pageNo: "connectionsList")
    }
    
    var body: some View {
        VStack {
            Text(self.getLocalizedTitle()).font(.title).padding()
            Divider()
            ScrollView {
                ForEach(self.stateKeeper.localizedMessages, id: \.self) { message in
                    Text(message).font(.body).padding()
                }
                Text(self.stateKeeper.message).font(.body).padding()
            }
            HStack {
                Button(action: {
                    self.setResponse(response: false)
                }) {
                    Text("NO_LABEL")
                        .fontWeight(.bold)
                        .font(.title)
                        .padding(5)
                        .background(Color.gray)
                        .cornerRadius(5)
                        .foregroundColor(.white)
                        .padding(10)
                }
                Button(action: {
                    self.setResponse(response: true)
                }) {
                    Text("YES_LABEL")
                        .fontWeight(.bold)
                        .font(.title)
                        .padding(5)
                        .background(Color.gray)
                        .cornerRadius(5)
                        .foregroundColor(.white)
                        .padding(10)
                }
                
            }
        }
    }
}


struct ContentViewA_Previews : PreviewProvider {
    static var previews: some View {
        AddOrEditConnectionPage(
            stateKeeper: StateKeeper(),
            connectionNameText: "",
            sshAddressText: "",
            sshPortText: "",
            sshUserText: "",
            sshPassText: "",
            saveSshCredentials: true,
            sshPassphraseText: "",
            sshPrivateKeyText: "",
            sshFingerprintSha256: "",
            x509FingerprintSha256: "",
            x509FingerprintSha512: "",
            addressText: "",
            portText: "",
            tlsPortText: "",
            certSubjectText: "",
            certAuthorityText: "",
            keyboardLayoutText: "",
            domainText: "",
            usernameText: "",
            passwordText: "",
            saveCredentials: true,
            screenShotFile: "",
            allowZooming: true,
            allowPanning: true,
            showSshTunnelSettings: false,
            externalId: "",
            requiresVpn: false,
            vpnUriScheme: ""
        )
    }
}

struct ConnectionInProgressPage_Previews : PreviewProvider {
    static var previews: some View {
        ConnectionInProgressPage(stateKeeper: StateKeeper())
    }
}

struct ProgressPage_Previews : PreviewProvider {
    static var previews: some View {
        ProgressPage(stateKeeper: StateKeeper())
    }
}

struct ConnectedSessionPage_Previews : PreviewProvider {
    static var previews: some View {
        ConnectedSessionPage()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(stateKeeper: StateKeeper(), searchConnectionText: "", filteredConnections: [])
    }
}
