//
//  URLTaggingViewController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/23/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import Common
import RealmSwift
import AppKit

class TagAddRemoveViewController: NSViewController {
    
    fileprivate weak var realmController: RealmController? {
        didSet {
            self.hardReloadData()
        }
    }
    
    // MARK: Data
    
    fileprivate var data: AnyRealmCollection<TagItem>?
    fileprivate var itemsToTag: [URLItem.UIIdentifier] = []
    
    // MARK: Outlets
    
    @IBOutlet private weak var tableView: NSTableView?
    
    // MARK: Appearance
    
    private lazy var appearanceSwitcher = AppleInterfaceStyleWindowAppearanceSwitcher(window: self.view.window!)
    
    // MARK: Loading
    
    convenience init(itemsToTag items: [URLItem.UIIdentifier], controller: RealmController) {
        self.init()
        self.realmController = controller
        self.itemsToTag = items
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.hardReloadData()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        _ = self.appearanceSwitcher
    }
    
    // MARK: Reload Data
    
    private func hardReloadData() {
        self.notificationToken?.stop()
        self.notificationToken = nil
        self.data = nil
        
        let data = self.realmController?.tag_loadAll()
        self.notificationToken = data?.addNotificationBlock({ [weak self] in self?.realmResultsChanged($0) })
    }
    
    private func realmResultsChanged(_ changes: RealmCollectionChange<AnyRealmCollection<TagItem>>) {
        switch changes {
        case .initial(let data):
            self.data = data
            self.tableView?.reloadData()
        case .update(_, let deletions, let insertions, let modifications):
            self.tableView?.beginUpdates()
            self.tableView?.insertRows(at: IndexSet(insertions), withAnimation: .slideRight)
            self.tableView?.removeRows(at: IndexSet(deletions), withAnimation: .slideLeft)
            self.tableView?.reloadData(forRowIndexes: IndexSet(modifications), columnIndexes: IndexSet([0]))
            self.tableView?.endUpdates()
        case .error(let error):
            guard let window = self.view.window else { break }
            let alert = NSAlert(error: error)
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }
    
    // MARK: Handle Creating New Tag
    
    @objc private func createNewTag(_ sender: NSObject?) {
        guard let button = sender as? NSButton, let realmController = self.realmController else {
            // if we can't respond, just pass it on
            self.nextResponder?.tryToPerform(#selector(self.createNewTag(_:)), with: sender)
            return
        }
        // create the tag naming VC
        let newVC = TagCreateViewController()
        newVC.confirmTagActionHandler = { [weak self] tuple in
            let newName = tuple.newName
            let sender = tuple.sender
            let presentedVC = tuple.presentedVC

            // create the tag
            let tag = realmController.tag_uniqueTag(named: newName)
            // add it to the selected items
            realmController.tag_apply(tag: tag, to: self?.itemsToTag ?? [])
            // hack because the tableview shows the new tag, but doesn't have the appropriate selection
            // maybe this is a bug in realm notifications?
            Thread.sleep(forTimeInterval: 0.3)
            self?.hardReloadData()
            // dismiss the naming view controller
            presentedVC.dismiss(sender)
        }
        // present the vc
        self.present(newVC, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }
    
    // MARK: Handle Going Away
    
    private var notificationToken: NotificationToken?
    
    deinit {
        self.notificationToken?.stop()
    }
}

// MARK: NSTableViewDataSource

extension TagAddRemoveViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.data?.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let tagItem = self.data?[row], let realmController = self.realmController else { return nil }
        let state = realmController.tag_applicationState(of: tagItem, on: self.itemsToTag)
        let object = CheckboxStateTableCellBindingObject(displayName: tagItem.name, state: state.cellStateValue, index: row)
        object.delegate = self
        return object
    }
    
}

// MARK: Handle Input from TableViewCells

extension TagAddRemoveViewController: TagAssignmentChangeDelegate {
    func didChangeAssignment(to newValue: Bool, forTagItemAtIndex index: Int) {
        guard let tagItem = self.data?[index] else { return }
        switch newValue {
        case true:
            self.realmController?.tag_apply(tag: tagItem, to: self.itemsToTag)
        case false:
            self.realmController?.tag_remove(tag: tagItem, from: self.itemsToTag)
        }
    }
}

// MARK: Bindings Class for TableViewCells Display/Input

private class CheckboxStateTableCellBindingObject: NSObject {
    weak var delegate: TagAssignmentChangeDelegate?
    let index: Int
    @objc let displayName: String
    @objc var state: NSCell.StateValue {
        didSet {
            // slow this down a little bit so the checkbox animation is not disrupted
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard let newState = CheckboxState(rawValue: self.state.rawValue) else { return }
                self.delegate?.didChangeAssignment(to: newState.boolValue, forTagItemAtIndex: self.index)
            }
        }
    }
    init(displayName: String, state: NSCell.StateValue, index: Int) {
        self.state = state
        self.displayName = displayName
        self.index = index
        super.init()
    }
}

extension CheckboxState {
    fileprivate var cellStateValue: NSCell.StateValue {
        return NSCell.StateValue(rawValue: self.rawValue)
    }
}
