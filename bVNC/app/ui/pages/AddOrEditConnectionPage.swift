//
//  AddOrEditConnectionPage.swift
//  bVNC
//
//  Created by iordan iordanov on 2024-02-24.
//  Copyright © 2024 iordan iordanov. All rights reserved.
//

import Foundation
import SwiftUI

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
    @State var id: String
    @State var textHeight: CGFloat = 20
    @State var audioEnabled: Bool
    @State var allowZooming: Bool
    @State var allowPanning: Bool
    @State var touchInputMethod: TouchInputMethod
    @State var showSshTunnelSettings: Bool
    @State var externalId: String
    @State var requiresVpn: Bool
    @State var vpnUriScheme: String
    @State var rdpGatewayAddress: String
    @State var rdpGatewayPort: String
    @State var rdpGatewayDomain: String
    @State var rdpGatewayUser: String
    @State var rdpGatewayPass: String
    @State var rdpGatewayEnabled: Bool
    @State var consoleFile: String
    @State var desktopScaleFactor: Int
    @State var customResolution: Bool
    @State var customWidth: Int
    @State var customHeight: Int

    @State var generateSshKeyButtonClicked: Bool = false
    @State var instructions = "If you generate a key within the app, the private key will automatically be copied to your clipboard.\n\nPaste it into a file private.pem.\n\nRun the following commands to get a public key string for your authorized_keys file:\n\nchmod go-rwx private.pem\nssh-keygen -f private.pem -y\n"
    
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
            "id": self.id.trimmingCharacters(in: .whitespacesAndNewlines),
            "audioEnabled": String(self.audioEnabled),
            "allowZooming": String(self.allowZooming),
            "allowPanning": String(self.allowPanning),
            "touchInputMethod": self.touchInputMethod.rawValue.trimmingCharacters(in: .whitespacesAndNewlines),
            "showSshTunnelSettings": String(self.showSshTunnelSettings),
            "externalId": self.externalId.trimmingCharacters(in: .whitespacesAndNewlines),
            "requiresVpn": String(self.requiresVpn),
            "vpnUriScheme": self.vpnUriScheme.trimmingCharacters(in: .whitespacesAndNewlines),
            "consoleFile": self.consoleFile.trimmingCharacters(in: .whitespacesAndNewlines),
            "desktopScaleFactor": String(self.desktopScaleFactor),
            "customResolution": String(self.customResolution),
            "customWidth": String(self.customWidth),
            "customHeight": String(self.customHeight),
        ]
        if Utils.isSpice() {
            connection["tlsPort"] = self.tlsPortText.trimmingCharacters(in: .whitespacesAndNewlines)
            connection["certSubject"] = self.certSubjectText.trimmingCharacters(in: .whitespacesAndNewlines)
            connection["certAuthority"] = self.certAuthorityText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if Utils.isSpice() || Utils.isRdp() {
            connection["keyboardLayout"] = self.keyboardLayoutText.trimmingCharacters(in: .whitespacesAndNewlines)
            connection["rdpGatewayAddress"] = self.rdpGatewayAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            connection["rdpGatewayPort"] = self.rdpGatewayPort.trimmingCharacters(in: .whitespacesAndNewlines)
            connection["rdpGatewayDomain"] = self.rdpGatewayDomain.trimmingCharacters(in: .whitespacesAndNewlines)
            connection["rdpGatewayUser"] = self.rdpGatewayUser.trimmingCharacters(in: .whitespacesAndNewlines)
            connection["rdpGatewayPass"] = self.rdpGatewayPass.trimmingCharacters(in: .whitespacesAndNewlines)
            connection["rdpGatewayEnabled"] = String(self.rdpGatewayEnabled)
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
        var selectedConnection: [String : String] = self.retrieveConnectionDetails()
        selectedConnection["saveCredentials"] = String(selectedConnection["password"] != "")
        selectedConnection["saveSshCredentials"] = String(selectedConnection["sshPass"] != "")
        self.stateKeeper.connections.overwriteOneConnectionAndNavigate(connection: selectedConnection)
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
        if !self.stateKeeper.connectedWithConsoleFileOrUri {
            self.stateKeeper.connections.overwriteOneConnectionAndNavigate(connection: selectedConnection)
        }
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
    
    fileprivate func getGenerateSshKeyButton() -> Button<some View> {
        return Button(action: {
            let generator = SshKeyGenerator()
            let privateKey = generator.generatePrivateKey(type: kSecAttrKeyTypeEC, bits: 521)
            if (privateKey != nil) {
                sshPrivateKeyText = generator.privateKeytoBase64String(privateKey: privateKey!) ?? ""
                UIPasteboard.general.string = sshPrivateKeyText
            }
            generateSshKeyButtonClicked = true
        }) {
            getButton(imageName: "bubbles.and.sparkles", textLabel: "GENERATE_SSH_KEY_LABEL")
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
    
    fileprivate func getRdpGatewayCredentialsHeading() -> some View {
        return Text("ENTER_RDP_GATEWAY_CREDENTIALS_LABEL").font(.title)
    }
    
    fileprivate func getRdpGatewayCredentialsFields() -> some View {
        return VStack {
            getTextField(text: "RDP_GATEWAY_DOMAIN_LABEL", binding: $rdpGatewayDomain)
            getTextField(text: "RDP_GATEWAY_USER_LABEL", binding: $rdpGatewayUser)
            getSecureField(text: "RDP_GATEWAY_PASSWORD_LABEL", binding: $rdpGatewayPass)
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
                    getGenerateSshKeyButton()
                    if (generateSshKeyButtonClicked) {
                        MultilineTextView(placeholder: "", text: $instructions, minHeight: self.textHeight, calculatedHeight: $textHeight).frame(minHeight: self.textHeight, maxHeight: self.textHeight)
                    }
                    VStack {
                        Text("SSH_KEY_LABEL").font(.title)
                        Divider()
                        MultilineTextView(placeholder: "", text: $sshPrivateKeyText, minHeight: self.textHeight, calculatedHeight: $textHeight).frame(minHeight: self.textHeight, maxHeight: self.textHeight)
                        Divider()
                    }
                }
            }
        }.padding()
    }
    
    fileprivate func getRdpGatewayFields() -> some View {
        return VStack {
            Toggle(isOn: $rdpGatewayEnabled) {
                Text("RDP_GATEWAY_ENABLED_SETTINGS_LABEL")
            }.font(.title)
            
            if self.rdpGatewayEnabled {
                VStack {
                    Text("RDP_GATEWAY_LABEL").font(.title)
                    getTextField(text: "RDP_GATEWAY_ADDRESS_LABEL", binding: $rdpGatewayAddress)
                    getTextField(text: "RDP_GATEWAY_PORT_LABEL", binding: $rdpGatewayPort)
                    getRdpGatewayCredentialsFields()
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
        return VStack(alignment: .leading) {
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
            VStack(alignment: .leading) {
                Toggle(isOn: $allowZooming) {
                    Text("ALLOW_DESKTOP_ZOOMING_LABEL").font(.title)
                }
                Toggle(isOn: $allowPanning) {
                    Text("ALLOW_DESKTOP_PANNING_LABEL").font(.title)
                }
                if !self.stateKeeper.isOnMacOsOriPadOnMacOs() {
                    HStack {
                        Text("TOUCH_INPUT_METHOD_LABEL").font(.title)
                        Picker("", selection: $touchInputMethod) {
                            ForEach(TouchInputMethod.allCases, id: \.self) {
                                Text(self.stateKeeper.localizedString(for: $0.rawValue)).font(.title)
                            }
                        }.font(.title).padding()
                    }
                }
                if Utils.isRdp() {
                    HStack {
                        Text("DESKTOP_SCALE_LABEL").font(.title)
                        Picker("", selection: $desktopScaleFactor) {
                            ForEach(Constants.SCALE_FACTOR_ENTRIES, id: \.self) { scale in
                                Text("\(scale)").tag(scale)
                            }
                        }.pickerStyle(.wheel)
                    }
                }
                if !Utils.isVnc() {
                    VStack {
                        Toggle(isOn: $customResolution) {
                            Text("CUSTOM_RESOLUTION").font(.title)
                        }
                        HStack {
                            Text("CUSTOM_WIDTH").font(.title)
                            Picker("", selection: $customWidth) {
                                ForEach(Constants.CUSTOM_RESOLUTION_ENTRIES, id: \.self) { scale in
                                    Text("\(scale)").tag(scale)
                                }
                            }.pickerStyle(.wheel)
                        }
                        HStack {
                            Text("CUSTOM_HEIGHT").font(.title)
                            Picker("", selection: $customHeight) {
                                ForEach(Constants.CUSTOM_RESOLUTION_ENTRIES, id: \.self) { scale in
                                    Text("\(scale)").tag(scale)
                                }
                            }.pickerStyle(.wheel)
                        }
                    }
                }
            }
        }.padding()
    }
    
    fileprivate func getSoundOptionsFields() -> some View {
        return VStack {
            Text("SOUND_SETTINGS_LABEL").font(.title)
            Toggle(isOn: $audioEnabled) {
                Text("SOUND_ENABLED_LABEL").font(.title)
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
                if (Utils.isRdp()) {
                    getRdpGatewayFields()
                }
                getLayoutAndCertFields()
                getUiOptionsFields()
                if (Utils.isRdp() || Utils.isSpice()) {
                    getSoundOptionsFields()
                }
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
            if (Utils.isRdp() && rdpGatewayEnabled) {
                getRdpGatewayCredentialsHeading()
                getRdpGatewayCredentialsFields()
            }
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
