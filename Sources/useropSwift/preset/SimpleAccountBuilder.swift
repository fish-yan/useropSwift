//
//  SimpleAccountBuilder.swift
//  
//
//  Created by liugang zhang on 2023/8/22.
//

import BigInt
import Foundation
import Web3Core
import web3swift

public class SimpleAccountBuilder: UserOperationBuilder {
    struct ResolveAccountMiddleware: UserOperationMiddleware {
        private let entryPoint: IEntryPoint
        private let initCode: Data

        init(entryPoint: IEntryPoint, initCode: Data) {
            self.entryPoint = entryPoint
            self.initCode = initCode
        }

        func process(_ ctx: inout UserOperationMiddlewareContext) async throws {
            ctx.op.nonce = try await entryPoint.getNonce(sender: ctx.op.sender, key: 0)
            ctx.op.initCode = ctx.op.nonce == 0 ? initCode : Data()
        }
    }

    private let signer: Signer
    private let web3: Web3
    private let provider: JsonRpcProvider
    private let entryPoint: EntryPoint
    private let factory: SimpleAccountFactory
    private let proxy: SimpleAccount

    public init(signer: Signer,
                rpcUrl: URL,
                bundleRpcUrl: URL? = nil,
                entryPoint: EthereumAddress,
                factory: EthereumAddress,
                salt: BigInt? = nil,
                senderAddress: EthereumAddress? = nil,
                paymasterMiddleware: UserOperationMiddleware? = nil) async throws {
        self.signer = signer
        self.provider = try await BundlerJsonRpcProvider(url: rpcUrl, bundlerRpc: bundleRpcUrl)
        self.web3 = Web3(provider: self.provider)
        self.entryPoint = EntryPoint(web3: web3, address: entryPoint)
        self.factory = SimpleAccountFactory(web3: web3, address: entryPoint)
        self.proxy = SimpleAccount(web3: web3, address: EthereumAddress.zero)
        super.init()

        initCode = await factory.addressData +
         self.factory.contract.method("createAccount", parameters: [signer.getAddress(), salt ?? 0], extraData: nil)!

        if let senderAddress = senderAddress {
            self.proxy.address = senderAddress
            self.sender = senderAddress
        } else {
            let address = try await self.entryPoint.getSenderAddress(initCode: initCode)
            self.proxy.address = address
            self.sender = address
        }
        self.signature = try await signer.signMessage(Data(hex: "0xdead").sha3(.keccak256))

        useMiddleware(ResolveAccountMiddleware(entryPoint: self.entryPoint, initCode: initCode))
        useMiddleware(GasPriceMiddleware(provider: provider))
        useMiddleware(paymasterMiddleware != nil ? paymasterMiddleware! : GasEstimateMiddleware(rpcProvider: provider))
        useMiddleware(SignatureMiddleware(signer: signer))
    }

    public func execute(to: EthereumAddress, value: BigUInt, data: Data) async throws {
        callData = proxy.contract.method("execute", parameters: [to, value, data], extraData: nil)!
    }

    public func executeBatch(to: [EthereumAddress], data: [Data]) async throws {
        callData = proxy.contract.method("executeBatch", parameters: [to, data], extraData: nil)!
    }
}
