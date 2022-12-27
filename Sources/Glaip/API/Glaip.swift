//
//  WristBandAPI.swift
//  
//
//  Created by Mauricio Vazquez on 15/8/22.
//

import SwiftUI
import WalletConnectSwift

public final class Glaip: ObservableObject {
    
    private let walletConnect: WalletLinkService
     
    public let title: String
    public let description: String
    public let supportedWallets: [WalletType]
    
    public var currentWallet: WalletType?
    
    @Published public var userState: UserState = .unregistered
    
    public init(title: String, description: String, supportedWallets: [WalletType], configJson: [String: Any], onConnect: ((User) -> Void)?, onDidDisconnect: ((WalletType) -> Void)?) {
        self.title = title
        self.description = description
        self.supportedWallets = supportedWallets
        
        let config = AppConfig(config: configJson)
        self.walletConnect = WalletLinkService(title: title, description: description, config: config)
        self.walletConnect.onDidConnect = onConnect
        self.walletConnect.onDidDisconnect = onDidDisconnect
    }
    
    public func loginUser(type: WalletType, completion: @escaping (Result<User, Error>) -> Void) {
        walletLogin(wallet: type, completion: { [weak self] result in
            switch result {
            case let .success(user):
                DispatchQueue.main.async {
                    self?.userState = .loggedIn(user)
                }
                self?.currentWallet = type
                completion(.success(user))
            case let .failure(error):
                completion(.failure(error))
            }
        })
    }
    
    public func sign(message: String, type: WalletType, completion: @escaping (Result<String, Error>) -> Void) {
        walletConnect.sign(wallet: type, message: message, completion: completion)
    }
    
    public func logout(type: WalletType) {
        walletConnect.disconnect(type: type)
    }
    
    private func walletLogin(wallet: WalletType, completion: @escaping (Result<User, Error>) -> Void) {
//        let service = WalletLinkService(title: title, description: description, config: conf)
        walletConnect.connect(wallet: wallet, completion: { result in
            switch result {
            case let .success(user):
                completion(.success(user))
            case let .failure(error):
                completion(.failure(error))
            }
        })
    }
}



