//
//  TagListViewController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/16/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import RealmSwift
import UIKit

extension UITableView {
    func deselectAllRows(animated: Bool) {
        for indexPath in self.indexPathsForSelectedRows ?? [] {
            self.deselectRow(at: indexPath, animated: animated)
        }
    }
}

class TagListViewController: UIViewController, RealmControllable {
    
    fileprivate enum Section: Int {
        case readingList = 0, tags
    }
    
    @IBOutlet private weak var tableView: UITableView?
    fileprivate var tags: Results<TagItem>?
    
    fileprivate weak var selectionDelegate: URLItemSelectionDelegate?
    
    weak var realmController: RealmController? {
        didSet {
            self.hardReloadData()
        }
    }
    
    convenience init(selectionDelegate: URLItemSelectionDelegate, controller: RealmController?) {
        self.init()
        self.selectionDelegate = selectionDelegate
        self.realmController = controller
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // title
        self.title = "Tags"
        
        // accounts button
        // set target to nil so it goes down the responder chain to the parent splitview controller
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Account", style: .plain, target: nil, action: #selector(HipstapaperSplitViewController.accountsBBITapped(_:)))
        
        // load tag data
        self.hardReloadData()
    }

    private func hardReloadData() {
        // reset everything
        self.notificationToken?.stop()
        self.notificationToken = .none
        self.tags = .none
        self.tableView?.reloadData()
        
        // reload everything
        self.tags = self.realmController?.tags
        self.notificationToken = self.tags?.addNotificationBlock(self.tableUpdateClosure)
    }
    
    private lazy var tableUpdateClosure: ((RealmCollectionChange<Results<TagItem>>) -> Void) = { [weak self] changes in
        switch changes {
        case .initial:
            // when the data is ready, relad the tableview
            self?.tableView?.reloadData()
            
            // after that, select the currently selected row
            // here we should always select the row because we want the row to be able to deselect itself when the view appears later
            guard let currentSelection = self?.selectionDelegate?.currentSelection else { return }
            self?.selectTableViewRows(for: currentSelection, animated: true)
        case .update(_, let deletions, let insertions, let modifications):
            // when there are changes from realm, update the table view with sweet animations
            self?.tableView?.beginUpdates()
            self?.tableView?.insertRows(at: insertions.map({ IndexPath(row: $0, section: 1) }), with: .automatic)
            self?.tableView?.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 1)}), with: .automatic)
            self?.tableView?.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 1) }), with: .automatic)
            self?.tableView?.endUpdates()
            
            // if a tag is the current selection, things may have changed out from underneath us, so we should update the current selections
            // we should also only do this if we're in collapsed mode. Otherwise the user could just be sitting on the Tag page on their iphone and something becomes selected
            guard let currentSelection = self?.selectionDelegate?.currentSelection, self?.splitViewController?.isCollapsed == false, case .tag = currentSelection else { return }
            self?.selectTableViewRows(for: currentSelection, animated: true)
        case .error(let error):
            let alert = UIAlertController(title: "Error Loading Tags", message: error.localizedDescription, preferredStyle: .alert)
            let action = UIAlertAction(title: "Dismiss", style: .cancel, handler: .none)
            alert.addAction(action)
            self?.present(alert, animated: true, completion: .none)
            self?.tags = .none
            self?.tableView?.reloadData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tableView?.flashScrollIndicators()
        if let currentSelection = self.selectionDelegate?.currentSelection, (self.splitViewController?.isCollapsed ?? true) == false {
            // because of the complexities of split view, we need to do some logic to figure out if we should deselect our row or select it
            // When the view appears and there is a selection and the splitview is not collapsed, that means the user can see the Tag List and URL List
            // at the same time. This means we need to select the row so the user can see what data is shown in the URL List
            self.selectTableViewRows(for: currentSelection, animated: true)
        } else {
            // otherwise, we need to deselect all rows. Because in this other case, we're in a normal iPhone layout
            // That means that the user clicked the back button from the URL list and arrived here and now the expect to see their previous selection
            // fade out in the traditional iphone way
            self.tableView?.deselectAllRows(animated: true)
        }
    }
    
    private func selectTableViewRows(for selection: URLItem.Selection, animated: Bool) {
        switch selection {
        case .unarchived:
            self.tableView?.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
        case .all:
            self.tableView?.selectRow(at: IndexPath(row: 1, section: 0), animated: false, scrollPosition: .none)
        case .tag(let tagID):
            guard let index = self.tags?.enumerated().filter({ $0.element.normalizedNameHash == tagID.idName }).map({ $0.offset }).first else { return }
            self.tableView?.selectRow(at: IndexPath(row: index, section: 1), animated: false, scrollPosition: .none)
        }
    }
    
    private var notificationToken: NotificationToken?
    
    deinit {
        self.notificationToken?.stop()
    }

}

extension TagListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return .none }
        switch section {
        case .readingList:
            return "Reading List  🎁"
        case .tags:
            return "Tags  🏷"
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let section = Section(rawValue: indexPath.section) else { return false }
        switch section {
        case .readingList:
            return false
        case .tags:
            return true
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section), section == .tags, editingStyle == .delete, let tagItem = self.tags?[indexPath.row] else { return }
        self.realmController?.delete(item: tagItem)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        let selection: URLItem.Selection
        switch section {
        case .readingList:
            selection = indexPath.row == 0 ? .unarchived : .all
        case .tags:
            guard let tagItem = self.tags?[indexPath.row] else { fatalError() }
            selection = .tag(TagItem.UIIdentifier(idName: tagItem.normalizedNameHash, displayName: tagItem.name))
        }
        self.selectionDelegate?.didSelect(selection, from: tableView)
    }
}

extension TagListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .readingList:
            return 2
        case .tags:
            return self.tags?.count ?? 0
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "BasicCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ?? UITableViewCell(style: .value1, reuseIdentifier: identifier)
        
        guard let section = Section(rawValue: indexPath.section) else { return cell }
        switch section {
        case .readingList:
            cell.textLabel?.text = indexPath.row == 0 ? "Unread Items" : "All Items"
        case .tags:
            guard let tagItem = self.tags?[indexPath.row] else { return cell }
            cell.textLabel?.text = tagItem.name
            cell.detailTextLabel?.text = "\(tagItem.items.count)"
        }
        
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}



