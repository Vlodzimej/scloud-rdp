//
//  HelpPage.swift
//  bVNC
//
//  Created by iordan iordanov on 2024-02-24.
//  Copyright © 2024 iordan iordanov. All rights reserved.
//

import Foundation
import SwiftUI

struct HelpPage : View {
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
