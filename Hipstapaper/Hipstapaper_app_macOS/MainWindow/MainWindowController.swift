//
//  HipstapaperWindowController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/18/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import Common
import AppKit

class MainWindowController: NSWindowController, RealmControllable {
    
    @IBOutlet private(set) weak var searchField: NSSearchField? {
        didSet {
            self.contentListViewController.searchField = self.searchField
        }
    }
    @IBOutlet private weak var shareToolbarButton: NSButton? {
        didSet {
            // configure the share button to send its action on mousedown
            self.shareToolbarButton?.sendAction(on: .leftMouseDown)
        }
    }
    
    // MARK: References to child view controllers
    
    let contentListViewController = ContentListViewController()
    fileprivate let sourceListViewController = SourceListViewController()
    
    private lazy var appearanceSwitcher = AppleInterfaceStyleWindowAppearanceSwitcher(window: self.window!)
    
    // MARK: Realm Controller Owner
    
    var realmController = RealmController() {
        didSet {
            self.sourceListViewController.realmController = self.realmController
            self.contentListViewController.realmController = self.realmController
        }
    }
    
    // MARK: KVO SourceList Collapsed
    
    private var sourceListCallapsedObserver: KeyValueObserver<Bool>?
    
    // MARK: Configure the window
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Get that OSX Yosemite 'look'
        self.window?.titleVisibility = .hidden
        _ = self.appearanceSwitcher
        
        // configure the splitview within the window
        let splitViewController = NSSplitViewController()
        splitViewController.view.wantsLayer = true
        self.window!.contentView = splitViewController.view
        self.window!.contentViewController = splitViewController
        
        // configure the splitview
        let sourceListItem = NSSplitViewItem(sidebarWithViewController: self.sourceListViewController)
        sourceListItem.isCollapsed = !UserDefaults.standard.wasSourceListOpen
        let contentListItem = NSSplitViewItem(contentListWithViewController: self.contentListViewController)
        splitViewController.addSplitViewItem(sourceListItem)
        splitViewController.addSplitViewItem(contentListItem)
        
        // Register to save SourceListView Width when the SplitView is Resized
        let token1 = NotificationCenter.default.addObserver(forName: NSSplitView.didResizeSubviewsNotification, object: splitViewController.splitView, queue: nil) { _ in
            UserDefaults.standard.sourceListWidth = self.sourceListViewController.view.frame.width
        }
        
        // KVO the sourceListItem Collapsed
        self.sourceListCallapsedObserver = KeyValueObserver(target: sourceListItem, keyPath: "collapsed") // #keyPath(NSSplitViewItem.isCollapsed)
        self.sourceListCallapsedObserver?.startObserving() { isCollapsed -> Bool? in
            UserDefaults.standard.wasSourceListOpen = !isCollapsed
            return nil
        }
        
        // Become the selection delegate for the sidebar
        // This lets us update the content view controller when the selection changes in the sidebar
        self.sourceListViewController.selectionDelegate = self
        
        // Become the selection delegate for the contentVC
        // This lets us update the sourceListVC when the user changes selection settings in the contentVC
        self.contentListViewController.selectionDelegate = self
        
        // check to see if the realm controller loaded
        // if it didn't load, then we're not logged in
        if let realmController = self.realmController {
            self.sourceListViewController.realmController = realmController
            self.contentListViewController.realmController = realmController
        }
        
        var token2: NSObjectProtocol!
        token2 = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeMainNotification, object: self.window!, queue: nil) { [unowned self] _ in
            // we only want it to do this once, so lets clear it out once we do it
            NotificationCenter.default.removeObserver(token2!)

            // check to see if the realm controller loaded
            // if it didn't load, then we're not logged in
            // if we're not logged in, show an alert
            guard self.realmController == nil else { return }
            let loginAlert = NSAlert()
            loginAlert.messageText = "Choose a sync option"
            loginAlert.informativeText = "Hipstapaper uses a Realm Mobile Platform server to synchronize your Reading list between all of your devices."
            loginAlert.addButton(withTitle: "Open Preferences")
            loginAlert.addButton(withTitle: "Dismiss")
            loginAlert.beginSheetModal(for: self.window!) { finished in
                guard finished == .alertFirstButtonReturn else { return }
                self.showPreferencesWindow(loginAlert)
            }
        }
        
        let invalidateBlock: (Notification) -> Void = { [weak self] _ in
            self?.invalidateRestorableState()
        }
        let token3 = NotificationCenter.default.addObserver(forName: NSTableView.selectionDidChangeNotification, object: self.contentListViewController.tableView!, queue: nil, using: invalidateBlock)
        let token4 = NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveScrollNotification, object: self.contentListViewController.scrollView, queue: nil, using: invalidateBlock)
        
        self.tokens += [token1, token2, token3, token4]
    }
    
    // MARK: Ownership of the preferences window
    
    private lazy var preferencesWindowController: PreferencesWindowController = {
        let wc = PreferencesWindowController()
        wc.delegate = self
        return wc
    }()
    
    @IBAction private func showPreferencesWindow(_ sender: NSObject?) {
        self.preferencesWindowController.showWindow(sender)
    }
    
    @objc private func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.tag == 333 {
            return true
        } else {
            return false
        }
    }
    
    // MARK: State Restoration
    
    enum StateRestoration {
        static let kSearchString = "kSearchStringKey"
        static let kSelectedItems = "kSelectedItemsKey"
        static let kVisibleItems = "kVisibleItemsKey"
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        // save all the state
        coder.encode(self.searchField?.searchString, forKey: StateRestoration.kSearchString)
        let selectedUUIDs = self.contentListViewController.selectedURLItems.map({ $0.uuid })
        coder.encode(selectedUUIDs, forKey: StateRestoration.kSelectedItems)
        if
            let rect = self.contentListViewController.scrollView?.documentVisibleRect,
            let range = self.contentListViewController.tableView?.rows(in: rect),
            rect.origin.y > 0 // don't save anything if we're scrolled at the top
        {
            let indexes = (0..<range.length).map({ range.location + $0 })
            let visibleUUIDs = self.contentListViewController.uuidStrings(for: indexes)
            coder.encode(visibleUUIDs, forKey: StateRestoration.kVisibleItems)
        }
        super.encodeRestorableState(with: coder)
    }
    
    override func restoreState(with coder: NSCoder) {
        // restore selection and visible rows
        self.contentListViewController.visibleUUIDsStateRestoration = coder.decodeObject(forKey: StateRestoration.kVisibleItems) as? [String]
        self.contentListViewController.selectedUUIDsStateRestoration = coder.decodeObject(forKey: StateRestoration.kSelectedItems) as? [String]
        
        // only restore the javascript state
        if let searchString = coder.decodeObject(forKey: StateRestoration.kSearchString) as? String {
            // only reload the data if we got a valid search back
            // this is needed because this method is called too late and the data has already loaded
            self.searchField?.searchString = searchString
            self.contentListViewController.hardReloadData()
            
            // invalidate the state again, otherwise if launched over and over the state is lost
            self.invalidateRestorableState()
        }
        
        super.restoreState(with: coder)
    }
    
    // MARK: Handle Going Away
    
    private var tokens = [NSObjectProtocol]()
    
    deinit {
        for token in self.tokens {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

extension MainWindowController: URLItemsToLoadChangeDelegate {
    var itemsToLoad: URLItem.ItemsToLoad {
        return self.contentListViewController.itemsToLoad
    }
    var filter: URLItem.ArchiveFilter {
        return self.contentListViewController.filter
    }
    var sortOrder: URLItem.SortOrder {
        return self.contentListViewController.sortOrder
    }
    
    func didChange(itemsToLoad: URLItem.ItemsToLoad?, sortOrder: URLItem.SortOrder?, filter: URLItem.ArchiveFilter?, sender: ViewControllerSender) {

        switch sender {
        case .tertiaryVC:
            fatalError()
        case .contentVC:
            self.sourceListViewController.didChange(itemsToLoad: itemsToLoad, sortOrder: sortOrder, filter: filter, sender: sender)
            // save the changes in NSUserDefaults
            UserDefaults.standard.userSelection = (itemsToLoad: itemsToLoad ?? self.itemsToLoad,
                                                   sortOrder: sortOrder ?? self.sortOrder,
                                                   filter: filter ?? self.filter)
        case .sourceListVC:
            // save the changes in NSUserDefaults
            UserDefaults.standard.userSelection = (itemsToLoad: itemsToLoad ?? self.itemsToLoad,
                                                   sortOrder: sortOrder ?? self.sortOrder,
                                                   filter: filter ?? self.filter)
            // if the new selection is different than the last one, forward it on
            // since the items can be nil, I only want to compare them if they are not nill
            // to accomplish that, if they're nil I set them to the same value that they're being compared with
            guard
                (itemsToLoad ?? self.itemsToLoad) != self.itemsToLoad ||
                (filter ?? self.filter) != self.filter ||
                (sortOrder ?? self.sortOrder) != self.sortOrder
            else { return }
            self.contentListViewController.didChange(itemsToLoad: itemsToLoad, sortOrder: sortOrder, filter: filter, sender: sender)
        }
    }
}
