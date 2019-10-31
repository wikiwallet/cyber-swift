//
//  Broadcast.swift
//  CyberSwift
//
//  Created by msm72 on 15.05.2018.
//  Copyright © 2018 Golos.io. All rights reserved.
//

import Foundation
import RxSwift

/// Type of request API
public typealias RequestMethodAPIType   =   (id: Int, requestMessage: String?, methodAPIType: MethodAPIType, errorAPI: ErrorAPI?)


public class Broadcast {
    // MARK: - Properties
    public static let instance = Broadcast()
    
    #warning("Remove later")
    let bag = DisposeBag()
    
    // MARK: - Class Initialization
    private init() {}
    
    deinit {
        Logger.log(message: "Success", event: .severe)
    }
    
    
    // MARK: - Class Functions

    /// Completion handler
    func completion<Result>(onResult: @escaping (Result) -> Void, onError: @escaping (ErrorAPI) -> Void) -> ((Result?, ErrorAPI?) -> Void) {
        return { (maybeResult, maybeError) in
            if let result = maybeResult {
                onResult(result)
            }
                
            else if let error = maybeError {
                onError(error)
            }
                
            else {
                onError(ErrorAPI.requestFailed(message: "Result not found"))
            }
        }
    }
    

    /// Generate array of new accounts
    public func generateNewTestUser(success: @escaping (ResponseAPICreateNewAccount?) -> Void) {
        //  1. Set up the HTTP request with URLSession
        let session = URLSession.shared
        
        if let url = URL(string: "http://116.203.39.126:7777/get_users") {
            let task = session.dataTask(with: url, completionHandler: { data, response, error in
                guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                    Logger.log(message: "Error create new acounts: \(error!.localizedDescription)", event: .error)
                    return success(nil)
                }
                
                do {
                    let jsonArray = try JSONDecoder().decode([ResponseAPICreateNewAccount].self, from: data!)
                    
                    if let newAccount = jsonArray.first {
                        Logger.log(message: "newAccount: \(String(describing: newAccount))", event: .debug)                        
                        return success(newAccount)
                    }
                } catch {
                    Logger.log(message: error.localizedDescription, event: .error)
                    return success(nil)
                }
            })
            
            task.resume()
        }
    }
    
    
    var currentId = 0
    /// Generating a unique ID
    //  for content:                < 100
    private func generateUniqueId() -> Int {
        currentId += 1
        if currentId == 100 {
            currentId = 0
        }
        return currentId
    }
}


// MARK: - Microservices
extension Broadcast {
    /// Prepare method request
    func prepareGETRequest(requestParamsType: RequestMethodParameters) -> RequestMethodAPIType {
        
        let codeID              =   generateUniqueId()
        
        let requestAPI          =   RequestAPI(id:          codeID,
                                               method:      String(format: "%@.%@", requestParamsType.methodGroup, requestParamsType.methodName),
                                               jsonrpc:     "2.0",
                                               params:      requestParamsType.parameters)
        
        do {
            // Encode data
            let jsonEncoder = JSONEncoder()
            var jsonData = Data()
            var jsonString: String
            
            jsonData    =   try jsonEncoder.encode(requestAPI)
            jsonString  =   String(data: jsonData, encoding: .utf8)!
            
            // Template: { "id": 2, "jsonrpc": "2.0", "method": "content.getProfile", "params": { "userId": "tst3uuqzetwf" }}
            return (id: codeID, requestMessage: jsonString, methodAPIType: requestParamsType.methodAPIType, errorAPI: nil)
        } catch {
            Logger.log(message: "Error: \(error.localizedDescription)", event: .error)
            
            return (id: codeID, requestMessage: nil, methodAPIType: requestParamsType.methodAPIType, errorAPI: ErrorAPI.requestFailed(message: "Broadcast, line 406: \(error.localizedDescription)"))
        }
    }
    
    /// Rx method to deal with executeGetRequest
    public func executeGetRequest<T: Decodable>(methodAPIType: MethodAPIType) -> Single<T> {
        // Offline mode
        if (!Config.isNetworkAvailable) {
            return .error(ErrorAPI.disableInternetConnection(message: nil)) }
        
        // Prepare content request
        let requestParamsType   =   methodAPIType.introduced()
        let requestMethodAPIType = prepareGETRequest(requestParamsType: requestParamsType)
        
        guard requestMethodAPIType.errorAPI == nil else {
            return .error(ErrorAPI.requestFailed(message: "Broadcast, line \(#line): \(requestMethodAPIType.errorAPI!)"))
        }
        
        Logger.log(message: "\nrequestMethodAPIType:\n\t\(requestMethodAPIType.requestMessage!)\n", event: .debug)
        
        return SocketManager.shared.sendRequest(methodAPIType: requestMethodAPIType)
            .catchError({ (error) -> Single<T> in
                if let errorAPI = error as? ErrorAPI {
                    let message = errorAPI.caseInfo.message
                    
                    if message == "Unauthorized request: access denied" {
                        return RestAPIManager.instance.rx.authorize()
                            .flatMap {_ in self.executeGetRequest(methodAPIType: methodAPIType)}
                    }
                    
                    if message == "There is no secret stored for this channelId. Probably, client's already authorized" ||
                        message == "Secret verification failed - access denied"{
                        // retrieve secret
                        return RestAPIManager.instance.rx.generateSecret()
                            .andThen(self.executeGetRequest(methodAPIType: methodAPIType))
                    }
                    
                    if message == "Invalid step taken" {
                        throw ErrorAPI.registrationRequestFailed(message: message, currentStep: "currentState")
                    }
                }
                                
                if let errorRx = error as? RxError {
                    switch errorRx {
                    case .timeout:
                        throw ErrorAPI.requestFailed(message: "Request has timed out")
                    default:
                        break
                    }
                }
                
                throw error
            })
            .log(method: "\(requestParamsType.methodGroup).\(requestParamsType.methodName)")
    }
}
