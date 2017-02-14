//
//  FrameworkExtensions.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 1/15/17.
//  Copyright © 2017 Jeffrey Bergier. All rights reserved.
//

import Foundation

public extension UserDefaults {
    
    private enum Keys {
        fileprivate static let sortOrder = "kSortOrderKey"
        fileprivate static let filter = "kFilterKey"
        fileprivate static let tagDisplayName = "kTagDisplayNameKey"
        fileprivate static let tagUniqueName = "kTagUniqueNameKey"
        fileprivate static let selectedItems = "kSelectedItemsKey"
        fileprivate static let sourceListShown = "kSourceListShownKey"
    }
    
    public var selectedURLItemUUIDStrings: [String]? {
        get {
            let untyped = self.object(forKey: Keys.selectedItems) as? NSArray
            let typed = untyped?.flatMap({ $0 as? String })
            if typed?.isEmpty == true { return .none } else { return typed }
        }
        set {
            self.set(newValue, forKey: Keys.selectedItems)
        }
    }
    
    public var userSelection: (itemsToLoad: URLItem.ItemsToLoad, sortOrder: URLItem.SortOrder, filter: URLItem.ArchiveFilter) {
        get {
            let sortValue = (self.value(forKey: Keys.sortOrder) as? NSNumber)?.intValue ?? -1
            let filterValue = (self.value(forKey: Keys.filter) as? NSNumber)?.intValue ?? -1
            let tagDisplayName = self.value(forKey: Keys.tagDisplayName) as? String
            let tagUniqueName = self.value(forKey: Keys.tagUniqueName) as? String
            let sort = URLItem.SortOrder(rawValue: sortValue)
            let filter = URLItem.ArchiveFilter(rawValue: filterValue)
            let itemsToLoad: URLItem.ItemsToLoad
            if let tagDisplayName = tagDisplayName, let tagUniqueName = tagUniqueName {
                itemsToLoad = .tag(TagItem.UIIdentifier(idName: tagUniqueName, displayName: tagDisplayName))
            } else {
                itemsToLoad = .all
            }
            return (itemsToLoad: itemsToLoad, sortOrder: sort ?? .recentlyAddedOnTop, filter: filter ?? .unarchived)
        }
        set {
            let sortNumber = NSNumber(integerLiteral: newValue.sortOrder.rawValue)
            let filterNumber = NSNumber(integerLiteral: newValue.filter.rawValue)
            self.set(sortNumber, forKey: Keys.sortOrder)
            self.set(filterNumber, forKey: Keys.filter)
            if case .tag(let tagID) = newValue.itemsToLoad {
                self.set(tagID.displayName, forKey: Keys.tagDisplayName)
                self.set(tagID.idName, forKey: Keys.tagUniqueName)
            } else {
                self.set(nil, forKey: Keys.tagDisplayName)
                self.set(nil, forKey: Keys.tagUniqueName)
            }
        }
    }
    
    public var wasSourceListOpen: Bool {
        get {
            let number = self.object(forKey: Keys.sourceListShown) as? NSNumber
            let previousValue = number?.boolValue
            let defaultValue = true
            return previousValue ?? defaultValue
        }
        set {
            let number = NSNumber(value: newValue)
            self.set(number, forKey: Keys.sourceListShown)
        }
    }
}
