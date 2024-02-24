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


struct MainPage : View {
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
                ConnectionsListPage(
                    stateKeeper: stateKeeper, searchConnectionText: searchConnectionText, connections: filteredConnections
                )
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
                HelpPage(stateKeeper: stateKeeper)
            } else if stateKeeper.currentPage == "yesNoMessage" {
                YesNoDialog(stateKeeper: stateKeeper)
            } else if stateKeeper.currentPage == "disconnectionInProgress" {
                DismissableBlankPage(stateKeeper: stateKeeper)
            }
        }
    }
}

struct MainPageA_Previews : PreviewProvider {
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

struct MainPage_Previews: PreviewProvider {
    static var previews: some View {
        MainPage(stateKeeper: StateKeeper(), searchConnectionText: "", filteredConnections: [])
    }
}
