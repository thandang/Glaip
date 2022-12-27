//
//  WalletConnect.swift
//  
//
//  Created by Mauricio Vazquez on 15/8/22.
//

import Foundation
import WalletConnectSwift

protocol WalletConnectDelegate: AnyObject {
    func failedToConnect()
    func didConnect()
    func didDisconnect(type: WalletType)
    func didUpdate()
}

final class WalletConnect {
    var session: Session!
    var client: Client!
    var wurl: WCURL!
    
    private let sessionKey = "sessionKey"
    private var delegate: WalletConnectDelegate
    private var config: AppConfig
    
    init(delegate: WalletConnectDelegate, config: AppConfig) {
        self.delegate = delegate
        self.config = config
    }
    
    func connect(title: String, description: String, icons: [URL] = []) -> String {
        // gnosis wc bridge: https://safe-walletconnect.gnosis.io/
        // test bridge with latest protocol version: https://bridge.walletconnect.org
//        let bridgeURL = URL(string: "https://safe-walletconnect.safe.global/")!
//        let clientURL = URL(string: "https://safe.gnosis.io")!
        
        let wcUrl =  WCURL(topic: UUID().uuidString,
                           bridgeURL: config.bridgeURL,
                           key: try! randomKey())
        let clientMeta = Session.ClientMeta(name: title,
                                            description: description,
                                            icons: icons,
                                            url: config.clientURL)
        let dAppInfo = Session.DAppInfo(peerId: UUID().uuidString, peerMeta: clientMeta)
        client = Client(delegate: self, dAppInfo: dAppInfo)
        
        try! client.connect(to: wcUrl)
        return wcUrl.absoluteString
    }
    
    func openWallet() -> String {
        // gnosis wc bridge: https://safe-walletconnect.gnosis.io/
        // test bridge with latest protocol version: https://bridge.walletconnect.org
//        let bridgeURL = URL(string: "https://safe-walletconnect.safe.global/")!
//        let clientURL = URL(string: "https://safe.gnosis.io")!
        
        let wcUrl =  WCURL(topic: UUID().uuidString,
                           bridgeURL: config.bridgeURL,
                           key: try! randomKey())
        return wcUrl.absoluteString
    }
    
    //Current open session
    func openSessions() -> [Session] {
        let sessions = client.openSessions()
        #if DEBUG
            print("open sessions: ", sessions)
        #endif
        return sessions
    }
    
    func reconnectIfNeeded() {
        self.reconnectMetamask()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.reconnectTrust()
        }
    }
    
    private func reconnectMetamask() {
        let metamaskKey = sessionKey + "metamask"
        if let oldSessionObject = UserDefaults.standard.object(forKey: metamaskKey) as? Data,
           let session = try? JSONDecoder().decode(Session.self, from: oldSessionObject) {
            if client == nil {
                client = Client(delegate: self, dAppInfo: session.dAppInfo)
            }
            try? client.reconnect(to: session)
        }
    }
    
    private func reconnectTrust() {
        let trustWalletKey = sessionKey + "trustwallet"
        if let oldSessionObject = UserDefaults.standard.object(forKey: trustWalletKey) as? Data,
           let session = try? JSONDecoder().decode(Session.self, from: oldSessionObject) {
            if client == nil {
                client = Client(delegate: self, dAppInfo: session.dAppInfo)
            }
            try? client.reconnect(to: session)
        }
    }
    
    func personalSign(message: String, wallet: WalletType, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let sessions = self.openSessions()
            if sessions.count > 0 {
                for ss  in sessions {
                    if let info = ss.walletInfo, wallet.rawValue.contains(info.peerMeta.name.replacingOccurrences(of: " ", with: "").lowercased()), let account = info.accounts.first {
                        print("session url: ", ss.url)
                        do {
                            try self.client.personal_sign(
                                url: ss.url,
                                message: message,
                                account: account
                            ) { response in
                                guard let responseHash = try? response.result(as: String.self) else { return }
                                completion(.success(responseHash))
                            }
                        } catch {
                            completion(.failure(error))
                        }
                        break
                    }
                }
            }
        }
    }
    
    // https://developer.apple.com/documentation/security/1399291-secrandomcopybytes
    private func randomKey() throws -> String {
        var bytes = [Int8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes: bytes, count: 32).toHexString()
        } else {
            enum TestError: Error {
                case unknown
            }
            throw TestError.unknown
        }
    }
    
    private func store(_ session: Session) {
        let key = sessionKey + (session.walletInfo != nil ? session.walletInfo!.peerMeta.name.replacingOccurrences(of: " ", with: "").lowercased() : "")
        do {
            let sesionData = try JSONEncoder().encode(session)
            let userDefault = UserDefaults.standard
            userDefault.set(sesionData, forKey: key)
            userDefault.synchronize()
        } catch {
            print("Could not store session")
        }
    }
}

extension WalletConnect: ClientDelegate {
    func client(_ client: Client, didFailToConnect url: WCURL) {
        delegate.failedToConnect()
    }
    
    func client(_ client: Client, didConnect url: WCURL) {
        self.wurl = url
        delegate.didConnect()
    }
    
    func client(_ client: Client, didConnect session: Session) {
        self.session = session
        store(session)
        delegate.didConnect()
    }
    
    func client(_ client: Client, didDisconnect session: Session) {
        let key = sessionKey + (session.walletInfo != nil ? session.walletInfo!.peerMeta.name.replacingOccurrences(of: " ", with: "").lowercased() : "")
        print("key: ", key)
        UserDefaults.standard.removeObject(forKey: key)
        var type: WalletType = .MetaMask
        if key.contains("metamask") {
            type = .MetaMask
        } else if key.contains("trust") {
            type = .TrustWallet
        }
        delegate.didDisconnect(type: type)
    }
    
    func client(_ client: Client, didUpdate session: Session) {
        store(session)
        delegate.didUpdate()
    }
}
