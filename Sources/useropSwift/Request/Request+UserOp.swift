//
// Request+UserOp.swift
//
//
//  Created by yan on 2023/11/3.
//
import Foundation
import Web3Core

//extension APIRequest {
//    public static func sendRequest<Result>(with provider: Web3Provider, for call: UserOpAPIRequest) async throws -> APIResponse<Result> {
//        let request = setupRequest(for: call, with: provider)
//        return try await APIRequest.send(uRLRequest: request, with: provider.session)
//    }
//    
//    static func setupRequest(for call: UserOpAPIRequest, with provider: Web3Provider) -> URLRequest {
//        var urlRequest = URLRequest(url: provider.url, cachePolicy: .reloadIgnoringCacheData)
//        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
//        urlRequest.httpMethod = "POST"
//        urlRequest.httpBody = call.encodedBody
//        return urlRequest
//    }
//}
//
extension APIRequest {
    public static func send<Result>(_ method: String, parameter: [Encodable], with provider: Web3Provider) async throws -> APIResponse<Result> {
        let body = RequestBody(method: method, params: parameter)
        let uRLRequest = setupRequest(for: body, with: provider)
        return try await send(uRLRequest: uRLRequest, with: provider.session)
    }
    
    static func setupRequest(for body: RequestBody, with provider: Web3Provider) -> URLRequest {
        var urlRequest = URLRequest(url: provider.url, cachePolicy: .reloadIgnoringCacheData)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = body.encodedBody
        return urlRequest
    }
}

struct RequestBody: Encodable {
    var jsonrpc = "2.0"
    var id = Counter.increment()

    var method: String
    var params: [Encodable]

    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case method
        case params
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)

        var paramsContainer = container.superEncoder(forKey: .params).unkeyedContainer()
        try params.forEach { a in
            try paramsContainer.encode(a)
        }
    }
    
    public var encodedBody: Data {
         return try! JSONEncoder().encode(self)
     }
}
