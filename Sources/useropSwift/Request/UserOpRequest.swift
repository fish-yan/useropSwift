//
//  UserOpRequest.swift
//  
//
//  Created by yan on 2023/11/3.
//

import Foundation
import web3swift
import Web3Core

public enum UserOpAPIRequest {
    case sendUserOperation(UserOperation, EthereumAddress)
}
