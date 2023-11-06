//
//  P256AccountTests.swift
//  
//
//  Created by liugang zhang on 2023/8/30.
//

import XCTest
import Web3Core
import web3swift
import BigInt

@testable import useropSwift

final class P256AccountTests: XCTestCase {
//    func testBindEmail() async throws {
//        let account =  try await P256AccountBuilder(signer: P256R1Signer(),
//                                                    rpcUrl: rpc,
//                                                    bundleRpcUrl: bundler,
//                                                    entryPoint: entryPointAddress,
//                                                    factory: factoryAddress,
//                                                    salt: 1)
//        let data = account.proxy.contract.method("addEmailGuardian", parameters: [
//            "0x36387ffce3ddd8c35b790148d6e6134689f74fe32471a27e8a243634ce213098",
//            "0x416bf2958e0965619fe574411312d6963673c87443f2ca65b34cc4415badc96749b5509d0ef2c43000e34fdd9ef5503bf2a12963c0190c25c1f56889d2efb9031b"
//        ], extraData: nil)!
//        account.execute(to: account.sender, value: 0, data: data)
//
//        let client = try await Client(rpcUrl: rpc, overrideBundlerRpc: bundler, entryPoint: entryPointAddress)
//        let response = try await client.sendUserOperation(builder: account)
//    }
//
//    func testRemoveEmail() async throws {
//        let account =  try await P256AccountBuilder(signer: P256R1Signer(),
//                                                    rpcUrl: rpc,
//                                                    bundleRpcUrl: bundler,
//                                                    entryPoint: entryPointAddress,
//                                                    factory: factoryAddress,
//                                                    salt: 1)
//        let data = account.proxy.contract.method("removeEmailGuardian", parameters: [], extraData: nil)!
//        account.execute(to: account.sender, value: 0, data: data)
//
//        let client = try await Client(rpcUrl: rpc, overrideBundlerRpc: bundler, entryPoint: entryPointAddress)
//        let response = try await client.sendUserOperation(builder: account)
//    }
    
    func testGetAddress() async throws {
        let privateKey = Data(hex: "36514c262240227300f9dbdbbb6511017a0b3df8e8b6795ec39b0136b83e9ad0")
        let rpcUrl = URL(string: "https://goerli.infura.io/v3/5ea2f3cac61a4890afca79e3c39b8b47")!
        let bundleRpcUrl = URL(string: "http://20.205.162.210:3000")!
        let entryPoint = EthereumAddress("0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789")!
        let owner = EthereumAddress("0x3DDa64705BE3b4D9c512B707Ef480795f45070CC")!
        let salt = BigUInt(1)
        
        let provider = try await BundlerJsonRpcProvider(url: rpcUrl, bundlerRpc: bundleRpcUrl)
        let web3 = Web3(provider: provider)
        let factory = SimpleAccountFactory(web3: web3, address: entryPoint)
        let initCode = entryPoint.addressData +
        factory.contract.method("createAccount", parameters: [owner, salt], extraData: nil)!
//        let address = try await factory.getAddress(owner: owner, salt: 1)
        
        let initCodeHash = initCode.sha3(.keccak256)
        var data = Data()
        data.append(Data([0xff]))
        data.append(owner.addressData)
        data.append(Data(repeating: 0x0, count: 31))
        data.append(salt.serialize())
        data += initCodeHash
        let hash = data.sha3(.keccak256)
        let addressData = Data(hash[12...])
        let address = addressData.toHexString()
        XCTAssertEqual(address, "15efc2d3360fb7f1a1f497beb985d35ce2dda3b1")
    }

}
