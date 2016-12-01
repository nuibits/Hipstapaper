//
//  SyncingPersistenceProtocol.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 11/25/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

typealias URLItemResult = ((Result<URLItemType>) -> Void)
typealias SuccessResult = ((Result<Void>) -> Void)

// This protocol is intended for use systems that use a local database (quick)
// and a cloud based persistence layer (full)
// It allows me to return the available results quickly
// But also keep the UI showing that network activity is happening

protocol DoubleSourcePersistenceType: class {
    var ids: Set<String> { get }    
    func sync(quickResult: SuccessResult?, fullResult: SuccessResult?)
    func createItem(withID id: String?, quickResult: URLItemResult?, fullResult: URLItemResult?)
    func readItem(withID id: String, quickResult: URLItemResult?, fullResult: URLItemResult?)
    func update(item: URLItemType, quickResult: URLItemResult?, fullResult: URLItemResult?)
    func delete(item: URLItemType, quickResult: SuccessResult?, fullResult: SuccessResult?)
}

// This protocol is intended for systems that use either a local database or a cloud storage system
protocol SingleSourcePersistenceType {
    var ids: Set<String> { get }
    func reloadData(result: SuccessResult?)
    func createItem(withID: String?, result: URLItemResult?)
    func readItem(withID id: String, result: URLItemResult?)
    func update(item: URLItemType, result: URLItemResult?)
    func delete(item: URLItemType, result: SuccessResult?)
}

