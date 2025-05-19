//
//  MiscellaneousPages.swift
//  sCloudRDP
//
//  Created by iordan iordanov on 2024-02-24.
//  Copyright © 2024 iordan iordanov. All rights reserved.
//

import Foundation
import SwiftUI

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
    
    fileprivate func handleDismissClick() {
        self.stateKeeper.showConnections()
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
                    handleDismissClick()
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
