//
//  EOSManager+Rx.swift
//  CyberSwift
//
//  Created by Chung Tran on 22/05/2019.
//  Copyright © 2019 golos.io. All rights reserved.
//

import Foundation
import RxSwift
import eosswift

extension EOSManager: ReactiveCompatible {}

extension Reactive where Base: EOSManager {
    // Get chain info
    static var chainInfo: Single<Info> {
        return EOSManager.chainApi.getInfo()
            .flatMap({ (response) -> Single<Info> in
                guard let body = response.body else {throw ErrorAPI.blockchain(message: "Can not retrieve chain info")}
                return .just(body)
            })
    }
    
    //  MARK: - Contract `gls.publish`
    private static func glsPublishPushTransaction(actionName: String, data: DataWriterValue, expiration: Date = Date.defaultTransactionExpiry(expireSeconds: Config.expireSeconds)) -> Single<ChainResponse<TransactionCommitted>> {
        guard let userNickName = Config.currentUser.nickName, let userActiveKey = Config.currentUser.activeKey else {
            return .error(ErrorAPI.blockchain(message: "Unauthorized"))
        }
        
        // Prepare action
        let transactionAuthorizationAbi = TransactionAuthorizationAbi(
                actor:        AccountNameWriterValue(name:    userNickName),
                permission:   AccountNameWriterValue(name:    "active"))
        
        let action = ActionAbi(
                account: AccountNameWriterValue(name: "gls.publish"),
                name: AccountNameWriterValue(name: actionName),
                authorization: [transactionAuthorizationAbi],
                data: data)
        
        let transaction = EOSTransaction(chainApi: EOSManager.chainApi)
        
        do {
            let privateKey = try EOSPrivateKey.init(base58: userActiveKey)
            return transaction.push(expirationDate: expiration, actions: [action], authorizingPrivateKey: privateKey)
        } catch {
            return .error(error)
        }
    }
    
    static func vote(voteType: VoteType, author: String, permlink: String, weight: Int16, refBlockNum: UInt64) -> Completable {
        guard let userNickName = Config.currentUser.nickName, let _ = Config.currentUser.activeKey else {
            return .error(ErrorAPI.blockchain(message: "Unauthorized"))
        }
        
        // Prepare data
        let voteArgs: Encodable = (voteType == .unvote) ?
            EOSTransaction.UnvoteArgs.init(voterValue: userNickName,
                                           authorValue:         author,
                                           permlinkValue:       permlink,
                                           refBlockNumValue:    refBlockNum)
            :
            EOSTransaction.UpvoteArgs.init(voterValue:          userNickName,
                                           authorValue:         author,
                                           permlinkValue:       permlink,
                                           refBlockNumValue:    refBlockNum,
                                           weightValue:         weight)
        
        let voteArgsData = DataWriterValue(hex: voteArgs.toHex())

        
        return Completable.create {completable in
            return glsPublishPushTransaction(actionName: voteType.rawValue, data: voteArgsData)
                .subscribe(onSuccess: { (response) in
                    if response.success {
                        // Update user profile reputation
                        if voteType == .unvote {
                            completable(.completed)
                            return
                        }
                        
                        let changereputArgs = EOSTransaction.UserProfileChangereputArgs(voterValue: userNickName, authorValue: author, rsharesValue: voteType == .upvote ? 1 : -1)
                        
                        #warning("change to rx later")
                        EOSManager.updateUserProfile(changereputArgs: changereputArgs) { (response, error) in
                            guard error == nil else {
                                completable(.error(error!))
                                return
                            }
                            completable(.completed)
                        }
                    }
                    completable(.error(ErrorAPI.requestFailed(message: response.errorBody!)))
                }, onError: { (error) in
                    completable(.error(error))
                })
        }
    }
    
    static func create(message:         String,
                       headline:        String = "",
                       parentData:      ParentData? = nil,
                       tags:            [EOSTransaction.Tags],
                       jsonMetaData:    String?) -> Single<ChainResponse<TransactionCommitted>> {
        // Check user authorize
        guard let userNickName = Config.currentUser.nickName, let _ = Config.currentUser.activeKey else {
            return .error(ErrorAPI.invalidData(message: "Unauthorized"))
        }
        
        return chainInfo
            .flatMap({ (info) -> Single<ChainResponse<TransactionCommitted>> in
                let refBlockNum: UInt64 = UInt64(info.head_block_num)
                
                // Prepare arguments
                let messageCreateArgs = EOSTransaction.MessageCreateArgs(
                    authorValue:        userNickName,
                    parentDataValue:    parentData,
                    refBlockNumValue:   refBlockNum,
                    headermssgValue:    headline,
                    bodymssgValue:      message,
                    tagsValues:         tags,
                    jsonmetadataValue:  jsonMetaData)
                
                // JSON
                Logger.log(message: messageCreateArgs.convertToJSON(), event: .debug)
                let messageCreateArgsData = DataWriterValue(hex: messageCreateArgs.toHex())
                
                // send transaction
                return glsPublishPushTransaction(actionName: "createmssg", data: messageCreateArgsData)
                    .map {response -> ChainResponse<TransactionCommitted> in
                        if !response.success {throw ErrorAPI.blockchain(message: response.errorBody!)}
                        return response
                    }
            })
    }
    
    
    static func delete(messageArgs: EOSTransaction.MessageDeleteArgs) -> Completable {
        // Check user authorize
        guard let userNickName = Config.currentUser.nickName, let userActiveKey = Config.currentUser.activeKey else {
            return .error(ErrorAPI.invalidData(message: "Unauthorized"))
        }
        
        // Prepare arguments
        let messageDeleteArgsData = DataWriterValue(hex: messageArgs.toHex())
        
        
        // Send transaction
        return Completable.create {completable in
            return glsPublishPushTransaction(actionName: "deletemssg", data: messageDeleteArgsData)
                .subscribe(onSuccess: { (response) in
                    if response.success {
                        completable(.completed)
                        return
                    }
                    completable(.error(ErrorAPI.requestFailed(message: response.errorBody!)))
                }, onError: { (error) in
                    completable(.error(error))
                })
        }
        
    }
}
