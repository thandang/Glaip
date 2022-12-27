//
//  WristBandAPI.swift
//  
//
//  Created by Mauricio Vazquez on 15/8/22.
//

import SwiftUI
import WalletConnectSwift

public final class Glaip: ObservableObject {
    
    private let walletConnectLink: WalletLinkService
     
    public let title: String
    public let description: String
    public let supportedWallets: [WalletType]
    
    public var currentWallet: WalletType?
    
    @Published public var userState: UserState = .unregistered
    
    public init(title: String, description: String, supportedWallets: [WalletType], configJson: [String: Any], onConnect: (([User]) -> Void)?, onDidDisconnect: ((WalletType) -> Void)?) {
        self.title = title
        self.description = description
        self.supportedWallets = supportedWallets
        
        let config = AppConfig(config: configJson)
        self.walletConnectLink = WalletLinkService(title: title, description: description, config: config)
        self.walletConnectLink.onDidConnect = onConnect
        self.walletConnectLink.onDidDisconnect = onDidDisconnect
    }
    
    public func validateOpenSessions() {
//        let openSessions = walletConnectLink.walletConnect.openSessions()
        walletConnectLink.setWalletConnect()
    }
    
    public func loginUser(type: WalletType, completion: @escaping (Result<[User], Error>) -> Void) {
        walletLogin(wallet: type, completion: { [weak self] result in
            switch result {
            case let .success(users):
                DispatchQueue.main.async {
//                    self?.userState = .loggedIn(user)
                }
                self?.currentWallet = type
                completion(.success(users))
            case let .failure(error):
                completion(.failure(error))
            }
        })
    }
    
    public func sign(message: String, type: WalletType, completion: @escaping (Result<String, Error>) -> Void) {
        walletConnectLink.sign(wallet: type, message: message, completion: completion)
    }
    
    public func logout(type: WalletType) {
        walletConnectLink.disconnect(type: type)
    }
    
    private func walletLogin(wallet: WalletType, completion: @escaping (Result<[User], Error>) -> Void) {
        walletConnectLink.connect(wallet: wallet, completion: { result in
            switch result {
            case let .success(users):
                completion(.success(users))
            case let .failure(error):
                completion(.failure(error))
            }
        })
    }
}



