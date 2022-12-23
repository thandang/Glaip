//
//  WalletLinkService.swift
//  
//
//  Created by Mauricio Vazquez on 15/8/22.
//

import Foundation

import WalletConnectSwift
import SwiftUI

public protocol WalletService {
    func connect(wallet: WalletType, completion: @escaping (Result<User, Error>) -> Void)
    func sign(wallet: WalletType, message: String, completion: @escaping (Result<String, Error>) -> Void)
}

public struct WalletDetails {
    public let address: String
    public let chainId: Int
    
    public init(address: String, chainId: Int) {
        self.address = address
        self.chainId = chainId
    }
}

public final class WalletLinkService: WalletService {
    
    private let title: String
    private let description: String
    
    private var walletConnect: WalletConnect!
    var onDidConnect: ((User) -> Void)?
    var onDidDisconnect: ((WalletType) -> Void)?
    
    public init(title: String, description: String) {
        self.title = title
        self.description = description
        
        setWalletConnect()
    }
    
    public func connect(wallet: WalletType, completion: @escaping (Result<User, Error>) -> Void) {
        openAppToConnect(wallet: wallet, getDeepLink(wallet: wallet), delay: 1)
        
        // Temp fix to avoid threading issue with async await
        let lock = NSLock()
        
        onDidConnect = { walletInfo in
            lock.lock()
            defer { lock.unlock() }
            
            completion(.success(walletInfo))
        }
    }
    
    public func disconnect(type: WalletType) {
        let sessions = walletConnect.openSessions()
        if sessions.count > 0 {
            for session  in sessions {
                if let info = session.walletInfo, type.rawValue.contains(info.peerMeta.name.lowercased()) {
                    do {
            //            guard let session = walletConnect.session else { return }
                        try walletConnect.client.disconnect(from: session)
                    } catch {
                        print("error disconnecting")
                    }

                    break
                }
            }
        }
    }
    
    public func sign(wallet: WalletType, message: String, completion: @escaping (Result<String, Error>) -> Void) {
        openAppToConnect(wallet: wallet, getDeepLink(wallet: .MetaMask), delay: 3)
        
        walletConnect.sign(message: message, completion: completion)
    }
    
    private func setWalletConnect() {
        walletConnect = WalletConnect(delegate: self)
        walletConnect.reconnectIfNeeded()
    }
    
    private func openAppToConnect(wallet: WalletType, _ url: String, delay: CGFloat = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if let url = URL(string: self.getDeepLink(wallet: wallet)), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    private func getDeepLink(wallet: WalletType) -> String {
        let connectionUrl = walletConnect.connect(title: title, description: description)
        let encodeURL = connectionUrl.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        let end = encodeURL.replacingOccurrences(of: "=", with: "%3D").replacingOccurrences(of: "&", with: "%26")
        
        return "\(wallet.rawValue)\(end)"
    }
}

// MARK: - WalletConnectDelegate
extension WalletLinkService: WalletConnectDelegate {
    func didUpdate() {
        print("did update")
    }
    
    func failedToConnect() {
        print("did failed to connect")
    }
    
    func didConnect() {
        guard
            let session = walletConnect.session,
            let walletInfo = session.walletInfo,
            let walletAddress = walletInfo.accounts.first
        else { return }
        
        var type: WalletType = .MetaMask
        if let wallet = session.walletInfo, wallet.peerMeta.name.lowercased().contains("metamask") {
            type = .MetaMask
        } else if let wallet = session.walletInfo, wallet.peerMeta.name.lowercased().contains("trust") {
            type = .TrustWallet
        }
        let user = User(
            wallet: Wallet(
                type: type,
                address: walletAddress,
                chainId: String(walletInfo.chainId))
        )
        onDidConnect?(user)
    }
    
    func didDisconnect(type: WalletType) {
        onDidDisconnect?(type)
    }
}

