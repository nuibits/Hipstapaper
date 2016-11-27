//
//  CloudKitURLItemSyncingController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 11/26/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import CloudKit

class CloudKitURLItemSyncingController: SyncingPersistenceType {
    
    private let privateDB = CKContainer.default().privateCloudDatabase
    private let recordType = "URLItem"
    
    private(set) var ids: Set<String> = []
    private var objectMap: [String : URLItem.CloudKitObject] = [:]
    
    private(set) var isSyncing: Bool = false
    private var networkOperationsInProgress = 0 {
        didSet {
            print("\(self.networkOperationsInProgress) ops in progress")
            if self.networkOperationsInProgress > 0 {
                self.isSyncing = true
            } else {
                self.isSyncing = false
            }
        }
    }
    
    private var syncOperation: (() -> Void)?
    private var networkQueue = [() -> Void]()
    
    init() {
        Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.checkSyncQueue(_:)), userInfo: .none, repeats: true)
    }
    
    func sync(completionHandler: SyncingPersistenceType.SuccessResult) {
        guard self.syncOperation == nil else { return }
        self.syncOperation = {
            self.networkOperationsInProgress += 1
            let predicate = NSPredicate(value: true)
            let initialQuery = CKQuery(recordType: self.recordType, predicate: predicate)
            self.privateDB.perform(initialQuery, inZoneWith: .none) { records, error in
                self.networkOperationsInProgress -= 1
                if let error = error {
                    self.ids = []
                    self.objectMap = [:]
                    completionHandler?(.error(error))
                } else {
                    let records = records ?? []
                    var ids = [String]()
                    var cloudObjects: [String : URLItem.CloudKitObject] = [:]
                    for record in records {
                        let object = URLItem.CloudKitObject(record: record)
                        let id = object.cloudKitID
                        ids.append(id)
                        cloudObjects[id] = object
                    }
                    self.objectMap = cloudObjects
                    self.ids = Set(ids)
                    completionHandler?(.success())
                }
            }
        }
        self.checkSyncQueue(.none)
    }
    
    func createItem() -> URLItemType {
        let newObject = URLItem.CloudKitObject()
        let id = newObject.cloudKitID
        self.objectMap[id] = newObject
        self.ids.insert(id)
        self.networkOperationsInProgress += 1
        self.networkQueue.append({
            self.privateDB.save(newObject.record, completionHandler: { _ in
                self.networkOperationsInProgress -= 1
            })
        })
        let newValue = URLItem.Value(cloudKitObject: newObject)
        return newValue
    }
    
    func read(itemWithID id: String) -> URLItemType {
        let existingObject = self.objectMap[id]!
        let value = URLItem.Value(cloudKitObject: existingObject)
        return value
    }
    
    func update(item: URLItemType) {
        let existingObject = self.objectMap[item.cloudKitID]!
        existingObject.urlString = item.urlString
        existingObject.archived = item.archived
        existingObject.tags = item.tags
        existingObject.modificationDate = item.modificationDate
        self.networkOperationsInProgress += 1
        self.networkQueue.append({
            self.privateDB.save(existingObject.record, completionHandler: { _ in
                self.networkOperationsInProgress -= 1
            })
        })
    }
    
    func delete(item: URLItemType) {
        let id = item.cloudKitID
        let existingObject = self.objectMap[id]!
        let recordID = existingObject.record.recordID
        self.ids.remove(id)
        self.objectMap[id] = .none
        self.networkOperationsInProgress += 1
        self.networkQueue.append({
            self.privateDB.delete(withRecordID: recordID, completionHandler: { _ in
                self.networkOperationsInProgress -= 1
            })
        })
    }
    
    @objc private func checkSyncQueue(_ timer: Timer?) {
        if self.networkQueue.isEmpty == false {
            let operation = self.networkQueue.removeFirst()
            operation()
            self.checkSyncQueue(timer)
        }
        if let syncOperation = self.syncOperation, self.networkQueue.isEmpty == true && self.isSyncing == false {
            syncOperation()
            self.syncOperation = .none
        }
    }
    
}