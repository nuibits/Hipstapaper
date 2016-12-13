//
//  CloudKitURLItemSyncingController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 11/26/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import CloudKit

open class URLItemCloudKitController: URLItemSinglePersistanceType {
    
    fileprivate let recordType = "URLItem"
    fileprivate let privateDB = CKContainer(identifier: "iCloud.com.saturdayapps.Hipstapaper").privateCloudDatabase
    fileprivate let serialQueue = DispatchQueue(label: "CloudKitURLItemSyncingController", qos: .userInitiated)
    
    fileprivate var objectMap: [String : URLItem.CloudKitObject] = [:]
    
    public init() {}
    
}

extension URLItemCloudKitController: URLItemQueryPersistanceType {
    
    public func tagItems(result: TagListResult?) {
        var tags = Set<String>()
        for (_, value) in self.objectMap {
            let newTags = value.tags
            newTags.forEach({ tags.insert($0 as! String) })
        }
        let sortedTags = Array(tags).sorted(by: { $0.0.name <= $0.1.name })
        result?(.success(sortedTags))
    }
    public func unarchivedItems(sortedBy: URLItem.Sort, ascending: Bool, result: URLItemIDsResult?) {
        let predicate = NSPredicate(format: "archived = NO")
        self.allItems(matchingPredicate: predicate, sortedBy: sortedBy, ascending: ascending, result: result)
    }
    public func allItems(for tag: TagItemType, sortedBy: URLItem.Sort, ascending: Bool, result: URLItemIDsResult?) {
        let matchingItemIDs = self.objectMap.filter({ $0.value.tags.filter({ $0.name == tag.name }).first != nil }).map({ $0.value.cloudKitID })
        result?(.success(matchingItemIDs))
    }
    
}

extension URLItemCloudKitController {
    fileprivate func allItems(matchingPredicate predicate: NSPredicate, sortedBy: URLItem.Sort, ascending: Bool, result: URLItemIDsResult?) {
        self.serialQueue.async {
            let sortDescriptor = NSSortDescriptor(key: sortedBy.cloudPropertyName, ascending: ascending)
            let query = CKQuery(recordType: self.recordType, predicate: predicate)
            query.sortDescriptors = [sortDescriptor]
            self.privateDB.perform(query, inZoneWith: .none) { records, error in
                self.serialQueue.async {
                    if let records = records {
                        var ids = [String]()
                        var cloudObjects: [String : URLItem.CloudKitObject] = [:]
                        for record in records {
                            let object = URLItem.CloudKitObject(record: record)
                            let id = object.cloudKitID
                            ids.append(id)
                            cloudObjects[id] = object
                        }
                        self.objectMap = cloudObjects
                        result?(.success(ids))
                    } else {
                        self.objectMap = [:]
                        result?(.error([error!]))
                    }
                }
            }
        }
    }
}

extension URLItemCloudKitController: URLItemCRUDSinglePersistanceType {

    public func allItems(sortedBy: URLItem.Sort, ascending: Bool, result: URLItemIDsResult?) {
        let predicate = NSPredicate(value: true)
        self.allItems(matchingPredicate: predicate, sortedBy: sortedBy, ascending: ascending, result: result)
    }
    
    public func create(item: URLItemType?, result: URLItemResult?) {
        self.serialQueue.async {
            let newObject: URLItem.CloudKitObject
            if let item = item {
                newObject = URLItem.CloudKitObject(urlItem: item)
            } else {
                newObject = URLItem.CloudKitObject()
            }
            self.privateDB.save(newObject.record) { (record, error) in
                self.serialQueue.async {
                    if let record = record {
                        let returnObject = URLItem.CloudKitObject(record: record)
                        let id = newObject.cloudKitID
                        self.objectMap[id] = returnObject
                        let returnValue = URLItem.Value(cloudKitObject: newObject)
                        result?(.success(returnValue))
                    } else {
                        result?(.error([error!]))
                    }
                }
            }
        }    }
    
    public func readItem(withID id: String, result: URLItemResult?) {
        self.serialQueue.async {
            if let existingObject = self.objectMap[id] {
                let value = URLItem.Value(cloudKitObject: existingObject)
                result?(.success(value))
            } else {
                result?(.error([NSError()]))
            }
        }
    }
    
    public func update(item: URLItemType, result: URLItemResult?) {
        self.serialQueue.async {
            guard let existingObject = self.objectMap[item.cloudKitID]
                else { result?(.error([NSError()])); return; }
            existingObject.urlString = item.urlString
            existingObject.archived = item.archived
            existingObject.tags = item.tags
            existingObject.modificationDate = item.modificationDate
            self.privateDB.save(existingObject.record) { (record, error) in
                self.serialQueue.async {
                    if let record = record {
                        let updatedObject = URLItem.CloudKitObject(record: record)
                        let id = updatedObject.cloudKitID
                        self.objectMap[id] = updatedObject
                        let updatedValue = URLItem.Value(cloudKitObject: updatedObject)
                        result?(.success(updatedValue))
                    } else {
                        result?(.error([error!]))
                    }
                }
            }
        }
    }
    
    public func delete(item: URLItemType, result: SuccessResult?) {
        self.serialQueue.async {
            let id = item.cloudKitID
            guard let existingObject = self.objectMap[id]
                else { result?(.error([NSError()])); return; }
            let recordID = existingObject.record.recordID
            self.objectMap[id] = .none
            self.privateDB.delete(withRecordID: recordID) { (recordID, error) in
                self.serialQueue.async {
                    if let _ = recordID {
                        result?(.success())
                    } else {
                        result?(.error([error!]))
                    }
                }
            }
        }
    }
}

extension URLItemCloudKitController: URLItemDoublePersistanceType {
    
    public var isSyncing: Bool { return false }
    
    public func sync(result: SuccessResult?) {
        self.allItems(sortedBy: .modificationDate, ascending: false) { innerResult in
            switch innerResult {
            case .success:
                result?(.success())
            case .error(let errors):
                result?(.error(errors))
            }
        }
    }
    public func create(item: URLItemType?, quickResult: URLItemResult?, fullResult: URLItemResult?) {
        self.create(item: item) { result in
            quickResult?(result)
            fullResult?(result)
        }
    }
    public func update(item: URLItemType, quickResult: URLItemResult?, fullResult: URLItemResult?) {
        self.update(item: item) { result in
            quickResult?(result)
            fullResult?(result)
        }
    }
    public func delete(item: URLItemType, quickResult: SuccessResult?, fullResult: SuccessResult?) {
        self.delete(item: item) { result in
            quickResult?(result)
            fullResult?(result)
        }
    }
}