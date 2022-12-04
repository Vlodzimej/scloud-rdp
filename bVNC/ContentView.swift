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

    var body: some View {
        let selectedConnection = stateKeeper.connections.selectedConnection
        VStack {
            if stateKeeper.currentPage == "connectionsList" {
                ConnectionsList(stateKeeper: stateKeeper, searchConnectionText: searchConnectionText, connections: filteredConnections)
            } else if stateKeeper.currentPage == "addOrEditConnection" {
                AddOrEditConnectionPage(
                     stateKeeper: stateKeeper,
                     sshAddressText: selectedConnection["sshAddress"] ?? "",
                     sshPortText: selectedConnection["sshPort"] ?? "22",
                     sshUserText: selectedConnection["sshUser"] ?? "",
                     sshPassText: selectedConnection["sshPass"] ?? "",
                     sshPassphraseText: selectedConnection["sshPassphrase"] ?? "",
                     sshPrivateKeyText: selectedConnection["sshPrivateKey"] ?? "",
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
                     screenShotFile: selectedConnection["screenShotFile"] ?? UUID().uuidString,
                     allowZooming: Bool(selectedConnection["allowZooming"] ?? "true") ?? true,
                     allowPanning: Bool(selectedConnection["allowPanning"] ?? "true") ?? true,
                     showSshTunnelSettings: Bool(selectedConnection["showSshTunnelSettings"] ?? "false")! || (selectedConnection["sshAddress"] ?? "") != "")
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
            } else if stateKeeper.currentPage == "blankPage" {
                BlankPage()
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
            self.stateKeeper.connectSaved(connection: connection)
        }
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
            return UIImage(contentsOfFile: URL(fileURLWithPath: dir.absoluteString).appendingPathComponent(named).path)
        }
        return nil
    }
    
    var body: some View {
        let binding = Binding<String>(get: {
            self.searchConnectionText
        }, set: {
            self.searchConnectionText = $0
            self.stateKeeper.connections.setSearchConnectionText(searchConnectionText: searchConnectionText)
        })
        
        ScrollView {
            VStack {
                HStack() {
                    TextField(self.stateKeeper.localizedString(for: "SEARCH_CONNECTION_TEXT"), text: binding).autocapitalization(.none).font(.title).padding(50)

                    Button(action: {
                        self.stateKeeper.showConnections()
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }.padding()
                    }
                    
                    Button(action: {
                        self.stateKeeper.addNewConnection()
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
                        self.stateKeeper.showHelp(messages: [ LocalizedStringKey(self.stateKeeper.localizedString(for: "MAIN_HELP_TEXT")) ])
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
                }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, alignment: .topTrailing).padding()
                
                ForEach(0 ..< self.connections.count) { i in
                    Button(action: {
                    }) {
                        VStack {
                            Image(uiImage: self.getSavedImage(named: self.connections[i]["screenShotFile"] ?? "") ?? UIImage())
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
            }
        }
    }
}

struct AddOrEditConnectionPage : View {
    var settings: UserDefaults = UserDefaults.standard
    @ObservedObject var stateKeeper: StateKeeper
    @State var sshAddressText: String
    @State var sshPortText: String
    @State var sshUserText: String
    @State var sshPassText: String
    @State var sshPassphraseText: String
    @State var sshPrivateKeyText: String
    @State var addressText: String
    @State var portText: String
    @State var tlsPortText: String
    @State var certSubjectText: String
    @State var certAuthorityText: String
    @State var keyboardLayoutText: String
    @State var domainText: String
    @State var usernameText: String
    @State var passwordText: String
    @State var screenShotFile: String
    @State var textHeight: CGFloat = 20
    @State var allowZooming: Bool
    @State var allowPanning: Bool
    @State var showSshTunnelSettings: Bool
    
    func retrieveConnectionDetails() -> [String : String] {
        var connection = [
            "sshAddress": self.sshAddressText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshPort": self.sshPortText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshUser": self.sshUserText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshPass": self.sshPassText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshPassphrase": self.sshPassphraseText.trimmingCharacters(in: .whitespacesAndNewlines),
            "sshPrivateKey": self.sshPrivateKeyText.trimmingCharacters(in: .whitespacesAndNewlines),
            "address": self.addressText.trimmingCharacters(in: .whitespacesAndNewlines),
            "port": self.portText.trimmingCharacters(in: .whitespacesAndNewlines),
            "domain": self.domainText.trimmingCharacters(in: .whitespacesAndNewlines),
            "username": self.usernameText.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": self.passwordText.trimmingCharacters(in: .whitespacesAndNewlines),
            "screenShotFile": self.screenShotFile.trimmingCharacters(in: .whitespacesAndNewlines),
            "allowZooming": String(self.allowZooming),
            "allowPanning": String(self.allowPanning),
            "showSshTunnelSettings": String(self.showSshTunnelSettings)
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
    
    var body: some View {
        ScrollView {
            VStack {
                HStack(spacing: 5) {
                    Button(action: {
                        let selectedConnection: [String : String] = self.retrieveConnectionDetails()
                        self.stateKeeper.connections.saveConnection(connection: selectedConnection)
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                            Text("SAVE_LABEL")
                                .lineLimit(1)
                                .allowsTightening(true)
                                .scaledToFit()
                                .minimumScaleFactor(0.70)
                        }.padding()
                    }
                    
                    Button(action: {
                        self.stateKeeper.connections.deleteCurrentConnection()
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                            Text("DELETE_LABEL")
                                .lineLimit(1)
                                .allowsTightening(true)
                                .scaledToFit()
                                .minimumScaleFactor(0.70)
                        }.padding()
                    }
                    
                    Button(action: {
                        self.stateKeeper.showConnections()
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                            Text("CANCEL_LABEL")
                                .lineLimit(1)
                                .allowsTightening(true)
                                .scaledToFit()
                                .minimumScaleFactor(0.70)
                        }.padding()
                    }

                    Button(action: {
                        var help_messages_list: [LocalizedStringKey] = ["VNC_CONNECTION_SETUP_HELP_TEXT", "UI_SETUP_HELP_TEXT"]
                        if self.stateKeeper.sshAppIds.contains(UIApplication.appId ?? "") {
                            help_messages_list.insert("SSH_CONNECTION_SETUP_HELP_TEXT", at: 0)
                        }
                        self.stateKeeper.connections.edit(connection: self.retrieveConnectionDetails())
                        self.stateKeeper.showHelp(messages: help_messages_list)
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "info")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                            Text("HELP_LABEL")
                                .lineLimit(1)
                                .allowsTightening(true)
                                .scaledToFit()
                                .minimumScaleFactor(0.70)
                        }.padding()
                    }
                }
                
                if self.stateKeeper.sshAppIds.contains(UIApplication.appId ?? "") {
                    VStack {
                        Toggle(isOn: $showSshTunnelSettings) {
                            Text("SHOW_SSH_TUNNEL_SETTINGS_LABEL")
                        }
                    }.padding()
                }

                if self.showSshTunnelSettings {
                VStack {
                    Text("SSH_TUNNEL_LABEL").font(.headline)
                    TextField(self.stateKeeper.localizedString(for: "SSH_SERVER_LABEL"), text: $sshAddressText).autocapitalization(.none).font(.title)
                    TextField(self.stateKeeper.localizedString(for: "SSH_PORT_LABEL"), text: $sshPortText).autocapitalization(.none).font(.title)
                    TextField(self.stateKeeper.localizedString(for: "SSH_USER_LABEL"), text: $sshUserText).autocapitalization(.none).font(.title)
                    SecureField(self.stateKeeper.localizedString(for: "SSH_PASSWORD_LABEL"), text: $sshPassText).autocapitalization(.none).font(.title)
                    SecureField(self.stateKeeper.localizedString(for: "SSH_PASSPHRASE_LABEL"), text: $sshPassphraseText).autocapitalization(.none).font(.title)
                    VStack {
                        Divider()
                        HStack {
                            Text("SSH_KEY_LABEL").font(.headline)
                            Divider()
                            MultilineTextView(placeholder: "", text: $sshPrivateKeyText, minHeight: self.textHeight, calculatedHeight: $textHeight).frame(minHeight: self.textHeight, maxHeight: self.textHeight)
                            Divider()
                        }
                        Divider()
                    }
                }.padding()
                }
                
                VStack {
                    Text("MAIN_CONNECTION_SETTINGS_LABEL").font(.headline)
                    TextField(self.stateKeeper.localizedString(for: "ADDRESS_LABEL"), text: $addressText).autocapitalization(.none).font(.title)
                    TextField(self.stateKeeper.localizedString(for: "PORT_LABEL"), text: $portText).font(.title)
                    if Utils.isSpice() {
                        TextField(self.stateKeeper.localizedString(for: "TLS_PORT_LABEL"), text: $tlsPortText).font(.title)
                    }
                }.padding()

                VStack {
                    if Utils.isRdp() {
                        TextField(self.stateKeeper.localizedString(for: "DOMAIN_LABEL"), text: $domainText).font(.title)
                    }
                    if Utils.isVnc() {
                        TextField(self.stateKeeper.localizedString(for: "USER_LABEL"), text: $usernameText).autocapitalization(.none).font(.title)
                    } else if Utils.isRdp() {
                        TextField(self.stateKeeper.localizedString(for: "MANDATORY_USER_LABEL"), text: $usernameText).autocapitalization(.none).font(.title)
                    }
                    SecureField(self.stateKeeper.localizedString(for: "PASSWORD_LABEL"), text: $passwordText).font(.title)
                    
                    if Utils.isSpice() {
                        TextField(self.stateKeeper.localizedString(for: "CERT_SUBJECT_LABEL"), text: $certSubjectText).autocapitalization(.none).font(.title)
                        VStack {
                            Divider()
                            HStack {
                                Text("CERT_AUTHORITY_LABEL").font(.headline)
                                Divider()
                                MultilineTextView(placeholder: "", text: $certAuthorityText, minHeight: self.textHeight, calculatedHeight: $textHeight).frame(minHeight: self.textHeight, maxHeight: self.textHeight)
                                Divider()
                            }
                            Divider()
                        }
                    }
                    
                    if Utils.isSpice() || Utils.isRdp() {
                        Picker("Keyboard Layout", selection: $keyboardLayoutText) {
                            ForEach(self.getKeyboardLayouts(), id: \.self) {
                                Text($0)
                            }
                        }
                    }
                }.padding()
                
                VStack {
                    Text("USER_INTERFACE_SETTINGS_LABEL").font(.headline)
                    Toggle(isOn: $allowZooming) {
                        Text("ALLOW_DESKTOP_ZOOMING_LABEL")
                    }
                    Toggle(isOn: $allowPanning) {
                        Text("ALLOW_DESKTOP_PANNING_LABEL")
                    }
                    Text("").padding(.bottom, 1000)
                }.padding()
            }
        }
    }
}

struct ConnectionInProgressPage : View {
    
    @ObservedObject var stateKeeper: StateKeeper
    
    var body: some View {
        VStack {
            Text("CONNECTING_TO_SERVER_LABEL")
            Button(action: {
                self.stateKeeper.lazyDisconnect()
                self.stateKeeper.showConnections()
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


struct BlankPage : View {
    var body: some View {
        Text("")
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
        AddOrEditConnectionPage(stateKeeper: StateKeeper(), sshAddressText: "", sshPortText: "", sshUserText: "", sshPassText: "", sshPassphraseText: "", sshPrivateKeyText: "", addressText: "", portText: "", tlsPortText: "", certSubjectText: "", certAuthorityText: "", keyboardLayoutText: "", domainText: "", usernameText: "", passwordText: "", screenShotFile: "", allowZooming: true, allowPanning: true, showSshTunnelSettings: false)
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
