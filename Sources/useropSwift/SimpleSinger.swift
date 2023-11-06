//
//  SimpleSinger.swift
//  
//
//  Created by yan on 2023/11/3.
//

import Foundation
import Web3Core

class SimpleSinger: NSObject, Signer {
    private let privateKey: Data
    
    init(privateKey: Data) {
        self.privateKey = privateKey
    }
    
    func getAddress() async -> EthereumAddress {
        try! await Utilities.publicToAddress(getPublicKey())!
    }
    
    func getPublicKey() async throws -> Data {
        Utilities.privateToPublic(privateKey)!
    }
    
    func signMessage(_ data: Data) async throws -> Data {
        let (compressedSignature, _) = SECP256K1.signForRecovery(hash: data,
                                                                 privateKey: privateKey,
                                                                 useExtraEntropy: false)
        return compressedSignature!
    }
    
}
