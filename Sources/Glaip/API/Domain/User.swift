//
//  User.swift
//  
//
//  Created by Mauricio Vazquez on 15/8/22.
//

import Foundation

public struct User: Equatable {
  public init(wallet: Wallet) {
    self.wallet = wallet
  }

  public let wallet: Wallet
}


/**
 {
   "clientURL": <String>,
   "bridgeURL": <String>,
   "iconURLs": Array<String>
 }
 */
public struct AppConfig {
    let clientURL: URL
    let bridgeURL: URL
    let iconURLs: [URL]
    
    init(clientURL: URL, bridgeURL: URL, iconURLs: [URL]) {
        self.clientURL = clientURL
        self.bridgeURL = bridgeURL
        self.iconURLs = iconURLs
    }
    
    init(config json: [String: Any]) {
        if let cl = json["clientURL"] as? String {
            self.clientURL = URL(string: cl)!
        } else {
            self.clientURL = URL(string: "https://safe.gnosis.io")!
        }
        
        if let br = json["bridgeURL"] as? String {
            self.bridgeURL = URL(string: br)!
        } else {
            self.bridgeURL = URL(string: "https://safe-walletconnect.safe.global/")!
        }
        var icons = [URL]()
        if let iconsArr = json["iconURLs"] as? Array<String>, icons.count > 0 {
            for item in iconsArr {
                if let url = URL(string: item) {
                    icons.append(url)
                }
            }
        }
        self.iconURLs = icons
    }
}

