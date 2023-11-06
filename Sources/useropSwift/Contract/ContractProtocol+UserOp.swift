//
//  s.swift
//  
//
//  Created by yan on 2023/11/3.
//
import Foundation
import Web3Core
import BigInt

extension ContractProtocol {
    @discardableResult
    public func decodeUserOpReturnData(_ method: String, data: Data) throws -> [String: Any] {
        if method == "fallback" {
            return [:]
        }

        guard let function = methods[method]?.first else {
            throw Web3Error.inputError(desc: "Function method does not exist.")
        }

        switch data.count % 32 {
        case 0:
            let result = function.decodeReturnData(data)
            let success = result["_success"] as? Bool ?? false
            guard success else {
                let failure = result["_failureReason"] as? String ?? ""
                throw Web3Error.inputError(desc: failure)
            }
            return result
        case 4:
            let selector = data[0..<4]
            if selector.toHexString() == "08c379a0", let reason = ABI.Element.EthError.decodeStringError(data[4...]) {
                throw Web3Error.UserOpError.revert("revert(string)` or `require(expression, string)` was executed. reason: \(reason)", reason: reason)
            }
            else if selector.toHexString() == "4e487b71", let reason = ABI.Element.EthError.decodePanicError(data[4...]) {
                let panicCode = String(format: "%02X", Int(reason)).addHexPrefix()
                throw Web3Error.UserOpError.revert("Error: call revert exception; VM Exception while processing transaction: reverted with panic code \(panicCode)", reason: panicCode)
            }
            else if let customError = errors[selector.toHexString().addHexPrefix().lowercased()] {
                if let errorArgs = customError.decodeEthError(data[4...]) {
                    throw Web3Error.UserOpError.revertCustom(customError.signature, errorArgs)
                } else {
                    throw Web3Error.inputError(desc: "Signature matches \(customError.errorDeclaration) but failed to be decoded.")
                }
            } else {
                throw Web3Error.inputError(desc: "Found no matched error")
            }
        default:
            throw Web3Error.inputError(desc: "Invalid data count")
        }
    }
}


// MARK: - Decode custom error

extension ABI.Element.EthError {
    public func decodeEthError(_ data: Data) -> [String: Any]? {
        guard inputs.count * 32 <= data.count,
              let decoded = ABIDecoder.decode(types: inputs, data: data) else {
            return nil
        }

        var result = [String: Any]()
        for (index, out) in inputs.enumerated() {
            result["\(index)"] = decoded[index]
            if !out.name.isEmpty {
                result[out.name] = decoded[index]
            }
        }
        return result
    }

    /// Decodes `revert(string)` and `require(expression, string)` calls.
    /// These calls are decomposed as `Error(string` error.
    public static func decodeStringError(_ data: Data) -> String? {
        let decoded = ABIDecoder.decode(types: [.init(name: "", type: .string)], data: data)
        return decoded?.first as? String
    }

    /// Decodes `Panic(uint256)` errors.
    /// See more about panic code explain at:  https://docs.soliditylang.org/en/v0.8.21/control-structures.html#panic-via-assert-and-error-via-require
    public static func decodePanicError(_ data: Data) -> BigUInt? {
        let decoded = ABIDecoder.decode(types: [.init(name: "", type: .uint(bits: 256))], data: data)
        return decoded?.first as? BigUInt
    }
}

extension ABI.Element.EthError {
    public var signature: String {
        return "\(name)(\(inputs.map { $0.type.abiRepresentation }.joined(separator: ",")))"
    }

    public var methodString: String {
        return String(signature.sha3(.keccak256).prefix(8))
    }

    public var methodEncoding: Data {
        return signature.data(using: .ascii)!.sha3(.keccak256)[0...3]
    }
}

extension Web3Error {
    enum UserOpError: LocalizedError {
        case revert(String, reason: String?)
        case revertCustom(String, [String: Any])
        
        public var errorDescription: String? {
            switch self {
            case .revert(let message, let reason):
                return "\(message); reverted with reason string: \(reason ?? "")"
            case .revertCustom(let error, _):
                return "reverted with custom error: \(error)"
            }
        }
    }
}

extension DefaultContractProtocol {
    @discardableResult
    public func callStatic(_ method: String, parameters: [Any], provider: Web3Provider) async throws -> [String: Any] {
        guard let address = address else {
            throw Web3Error.inputError(desc: "address field is missing")
        }
        guard let data = self.method(method, parameters: parameters, extraData: nil) else {
            throw Web3Error.dataError
        }
        let transaction = CodableTransaction(to: address, data: data)

        let result: Data = try await APIRequest.sendRequest(with: provider, for: .call(transaction, .latest)).result
        return try decodeUserOpReturnData(method, data: result)
    }
}

extension ABI.Element.Event {
    public static func encodeTopic(input: ABI.Element.Event.Input, value: Any) -> EventFilterParameters.Topic? {
        switch input.type {
        case .string:
            guard let string = value as? String else {
                return nil
            }
            return .string(string.sha3(.keccak256).addHexPrefix())
        case .dynamicBytes:
            guard let data = ABIEncoder.convertToData(value) else {
                return nil
            }
            return .string(data.sha3(.keccak256).toHexString().addHexPrefix())
        case .bytes(length: _):
            guard let data = value as? Data, let data = data.setLengthLeft(32) else {
                return nil
            }
            return .string(data.toHexString().addHexPrefix())
        case .address, .uint(bits: _), .int(bits: _), .bool:
            guard let encoded = ABIEncoder.encodeSingleType(type: input.type, value: value) else {
                return nil
            }
            return .string(encoded.toHexString().addHexPrefix())
        default:
            guard let data = try? ABIEncoder.abiEncode(value).setLengthLeft(32) else {
                return nil
            }
            return .string(data.toHexString().addHexPrefix())
        }
    }

    public func encodeParameters(_ parameters: [Any?]) -> [EventFilterParameters.Topic?] {
        guard parameters.count <= inputs.count else {
            // too many arguments for fragment
            return []
        }
        var topics: [EventFilterParameters.Topic?] = []

        if !anonymous {
            topics.append(.string(topic.toHexString().addHexPrefix()))
        }

        for (i, p) in parameters.enumerated() {
            let input = inputs[i]
            if !input.indexed {
                // cannot filter non-indexed parameters; must be null
                return []
            }
            if p == nil {
                topics.append(nil)
            } else if input.type.isArray || input.type.isTuple {
                // filtering with tuples or arrays not supported
                return []
            } else if let p = p as? Array<Any> {
                topics.append(.strings(p.map { Self.encodeTopic(input: input, value: $0) }))
            } else {
                topics.append(Self.encodeTopic(input: input, value: p!))
            }
        }

        // Trim off trailing nulls
        while let last = topics.last {
            if last == nil {
                topics.removeLast()
            } else if case .string(let string) = last, string == nil {
                topics.removeLast()
            } else {
                break
            }
        }
        return topics
    }
}

extension ABI.Element.ParameterType {
    var isArray: Bool {
        switch self {
        case .array(type: _, length: _):
            return true
        default:
            return false
        }
    }
    
    var isTuple: Bool {
        switch self {
        case .tuple:
            return true
        default:
            return false
        }
    }
}

extension Data {
    func setLengthLeft(_ toBytes: UInt64, isNegative: Bool = false) -> Data? {
        let existingLength = UInt64(self.count)
        if existingLength == toBytes {
            return Data(self)
        } else if existingLength > toBytes {
            return nil
        }
        var data: Data
        if isNegative {
            data = Data(repeating: UInt8(255), count: Int(toBytes - existingLength))
        } else {
            data = Data(repeating: UInt8(0), count: Int(toBytes - existingLength))
        }
        data.append(self)
        return data
    }
    
}
