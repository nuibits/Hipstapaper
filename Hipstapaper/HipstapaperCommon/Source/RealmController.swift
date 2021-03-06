//
//  RealmController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/25/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import RealmSwift

// MARK: Initialization

public class RealmController {
    
    public enum Kind {
        case sync(SyncUser), local
    }
    
    private let kind: Kind
    private let configuration: Realm.Configuration
    
    public var realm: Realm {
        let realm = try! Realm(configuration: self.configuration)
        return realm
    }
    
    public var session: SyncSession? {
        switch self.kind {
        case .sync(let user):
            return user.session(for: self.configuration.syncConfiguration!.realmURL)!
        case .local:
            return nil
        }
    }
    
    private static func realmURL(for user: SyncUser) -> URL {
        var components = URLComponents(url: user.authenticationServer!, resolvingAgainstBaseURL: false)!
        if components.scheme == "https" {
            components.scheme = "realms"
        } else {
            components.scheme = "realm"
        }
        if components.path.last == "/" {
            components.path += "~/Hipstapaper"
        } else {
            components.path += "/~/Hipstapaper"
        }
        let url = components.url!
        return url
    }
    
    public init(kind: Kind) {
        SyncManager.shared.logLevel = .warn
        self.kind = kind
        let config: Realm.Configuration
        switch kind {
        case .local:
            try? RealmController.createRealmDir()
            let fileURL = RealmController.realmDir.appendingPathComponent("Realm.realm")
            config = Realm.Configuration(fileURL: fileURL)
        case .sync(let user):
            config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: user, realmURL: RealmController.realmURL(for: user)))
        }
        self.configuration = config
    }
    
    public convenience init?() {
        if let user = SyncUser.current {
            self.init(kind: .sync(user))
        } else if RealmController.realmDirExists {
            self.init(kind: .local)
        } else {
            return nil
        }
    }
    
    public func logOut() {
        switch self.kind {
        case .local:
            try? type(of: self).deleteRealmDir()
        case .sync(let user):
            user.logOut()
        }
    }
    
}

// MARK: Object Agnostic Helper Methods

extension RealmController {

    public func add(_ item: Object) {
        let realm = self.realm
        realm.beginWrite()
        realm.add(item)
        try! realm.commitWrite()
    }
    
    public func delete(_ item: Object) {
        let realm = self.realm
        realm.beginWrite()
        if let urlItem = item as? URLItem, let extras = urlItem.extras {
            realm.delete(extras) // add check to perform cascade delete
        }
        realm.delete(item)
        try! realm.commitWrite()
    }
    
    public func delete(_ items: [Object]) {
        let realm = self.realm
        realm.beginWrite()
        for item in items {
            if let urlItem = item as? URLItem, let extras = urlItem.extras {
                realm.delete(extras) // add check to perform cascade delete
            }
            realm.delete(item)
        }
        try! realm.commitWrite()
    }
    
    public func duplicate(_ oldURLItem: URLItem, in rc: RealmController? = nil) {
        let rc = rc ?? self
        let newURLItem = URLItem()
        newURLItem.archived = oldURLItem.archived
        newURLItem.urlString = oldURLItem.urlString
        newURLItem.creationDate = oldURLItem.creationDate
        newURLItem.modificationDate = oldURLItem.modificationDate
        for oldTag in oldURLItem.tags {
            let newTag = rc.tag_uniqueTag(named: oldTag.name)
            newURLItem.tags.append(newTag)
        }
        if let oldExtras = oldURLItem.extras {
            let newExtras = URLItemExtras()
            newExtras.pageTitle = oldExtras.pageTitle
            if let oldData = oldExtras.imageData, oldData.count > XPImageProcessor.maxFileSize {
                let compressedData = XPImageProcessor.compressedJPEGImageData(fromAnyImageData: oldData)
                newExtras.imageData = compressedData
            } else {
                newExtras.imageData = oldExtras.imageData
            }
            newURLItem.extras = newExtras
        }
        let realm = rc.realm
        realm.beginWrite()
        realm.add(newURLItem)
        try! realm.commitWrite()
    }
    
}

// MARK: Tag Helper Methods

extension RealmController {
    
    // MARK: Class Funcs for Common Operations
    
    public class func indexes(ofItemUUIDs uuids: [String], within collection: AnyRealmCollection<URLItem>) -> [Int] {
        guard uuids.isEmpty == false else { return [] }
        let predicates = uuids.map({ "\(#keyPath(URLItem.uuid)) = '\($0)'" })
        let indexes = collection.indexes(matchingPredicates: predicates)
        return indexes
    }
    
    // MARK: Create / Load / Delete Tags
    
    public func tag_loadAll() -> AnyRealmCollection<TagItem> {
        let realm = self.realm
        let tags = AnyRealmCollection(realm.objects(TagItem.self).sorted(byKeyPath: #keyPath(TagItem.name)))
        return tags
    }
    
    public func tag_deleteTag(with tagID: TagItem.UIIdentifier) {
        let realm = self.realm
        guard let tag = realm.object(ofType: TagItem.self, forPrimaryKey: tagID.idName) else { return }
        realm.beginWrite()
        realm.delete(tag)
        try! realm.commitWrite()
    }
    
    public func tag_uniqueTag(named proposedName: String) -> TagItem {
        let normalizedName = TagItem.normalize(proposedName)
        let realm = self.realm
        let existingItem = realm.object(ofType: TagItem.self, forPrimaryKey: normalizedName)
        if let existingItem = existingItem {
            return existingItem
        } else {
            realm.beginWrite()
            let newItem = TagItem()
            newItem.normalizedNameHash = normalizedName
            newItem.name = normalizedName == "untitledtag" ? "Untitled Tag" : proposedName
            realm.add(newItem)
            try! realm.commitWrite()
            return newItem
        }
    }
    
    // MARK: Query / Apply / Remove Tags from URLItems
    
    public func tag_applicationState(of tagItem: TagItem, on itemIDs: [URLItem.UIIdentifier]) -> CheckboxState {
        let items = self.url_existingItems(itemIDs: itemIDs)
        guard items.isEmpty == false else { return .off }
        let matches = items.compactMap({ $0.tags.index(of: tagItem) })
        if matches.count == items.count {
            // this means all items have this tag
            return .on
        } else {
            if matches.isEmpty {
                // this means that none of the items have this tag
                return .off
            } else {
                // this means we're mixed. Some items have the tag and some don't
                return .mixed
            }
        }
    }
    
    public func tag_apply(tag tagItem: TagItem, to itemIDs: [URLItem.UIIdentifier]) {
        let items = self.url_existingItems(itemIDs: itemIDs)
        guard items.isEmpty == false else { return }
        let realm = self.realm
        realm.beginWrite()
        let newDate = Date()
        for urlItem in items {
            guard urlItem.tags.index(of: tagItem) == nil else { continue }
            urlItem.tags.append(tagItem)
            urlItem.modificationDate = newDate
            let tagItemName = tagItem.name
            tagItem.name = tagItemName // hack to trigger change notification on the TagItem so tables reload in the UI
        }
        try! realm.commitWrite()
    }
    
    public func tag_remove(tag tagItem: TagItem, from itemIDs: [URLItem.UIIdentifier]) {
        let items = self.url_existingItems(itemIDs: itemIDs)
        guard items.isEmpty == false else { return }
        let realm = self.realm
        realm.beginWrite()
        let newDate = Date()
        for urlItem in items {
            guard let index = urlItem.tags.index(of: tagItem) else { continue }
            urlItem.tags.remove(objectAtIndex: index)
            urlItem.modificationDate = newDate
            let tagItemName = tagItem.name
            tagItem.name = tagItemName // hack to trigger change notification on the TagItem so tables reload in the UI
        }
        try! realm.commitWrite()
    }
}

// MARK: URLItem Helper Methods

extension RealmController {

    public func url_existingItem(itemID: URLItem.UIIdentifier) -> URLItem? {
        let realm = self.realm
        let item = realm.object(ofType: URLItem.self, forPrimaryKey: itemID.uuid)
        return item
    }
    
    public func url_existingItems(itemIDs: [URLItem.UIIdentifier]) -> [URLItem] {
        let realm = self.realm
        let items = itemIDs.compactMap({ realm.object(ofType: URLItem.self, forPrimaryKey: $0.uuid) })
        return items
    }
    
    public func url_loadAll(for itemsToLoad: URLItem.ItemsToLoad, sortedBy sortOrder: URLItem.SortOrder, filteredBy filter: URLItem.ArchiveFilter, searchFilter: String? = nil) -> AnyRealmCollection<URLItem>? {
        
        // configure my filters
        var filters = [String]()
        
        // filter for archived or not all
        switch filter {
        case .unarchived:
            filters.append("\(filter.keyPath) = NO")
        case .all:
            break // don't add anything to the filter array
        }

        // filter for the users search
        if let searchFilter = searchFilter {
            let predicate = "\(#keyPath(URLItem.urlString)) CONTAINS[c] '\(searchFilter)' OR \(#keyPath(URLItem.extras.pageTitle)) CONTAINS[c] '\(searchFilter)'"
            filters.append(predicate)
        }
        
        // query for the correct object
        let unsortedUnfiltered: AnyRealmCollection<URLItem>
        switch itemsToLoad {
        case .all:
            unsortedUnfiltered = AnyRealmCollection(realm.objects(URLItem.self))
        case .tag(let tagID):
            guard let tag = realm.object(ofType: TagItem.self, forPrimaryKey: tagID.idName) else { return nil }
            unsortedUnfiltered = AnyRealmCollection(tag.items)
        }
        
        // perform filters on the query
        let unsortedFiltered = filters.reduce(unsortedUnfiltered) { collectionSoFar, nextFilterString in
            return AnyRealmCollection(collectionSoFar.filter(nextFilterString))
        }
        
        // sort the filtered items
        let sortedFiltered = AnyRealmCollection(unsortedFiltered.sorted(byKeyPath: sortOrder.keyPath, ascending: sortOrder.ascending))
        
        // return the result
        return sortedFiltered
    }
    
    public func url_setArchived(to archived: Bool, on items: [URLItem]) {
        let realm = self.realm
        realm.beginWrite()
        let newDate = Date()
        for item in items {
            item.archived = archived
            item.modificationDate = newDate
        }
        try! realm.commitWrite()
    }
}

extension RealmController {
    private static let realmDir: URL = {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).last!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.unknown.app"
        let realmDir = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        return realmDir
    }()
    
    private static func createRealmDir() throws {
        let realmDir = self.realmDir
        let fm = FileManager.default
        try fm.createDirectory(at: realmDir, withIntermediateDirectories: true)
    }
    
    private static func deleteRealmDir() throws {
        let realmDir = self.realmDir
        let fm = FileManager.default
        try fm.removeItem(at: realmDir)
    }
    
    private static var realmDirExists: Bool {
        let realmDir = self.realmDir
        let fm = FileManager.default
        return fm.fileExists(atPath: realmDir.path, isDirectory: nil)
    }
}
