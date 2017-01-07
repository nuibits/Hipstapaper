//
//  URLListViewController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/16/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import RealmSwift
import SafariServices
import UIKit

class URLListViewController: UIViewController, RealmControllable {
    
    @IBOutlet fileprivate weak var tableView: UITableView? {
        didSet {
            let imageNib = UINib(nibName: URLTableViewCell.withImageNIBName, bundle: Bundle(for: URLTableViewCell.self))
            let noImageNib = UINib(nibName: URLTableViewCell.withOutImageNIBName, bundle: Bundle(for: URLTableViewCell.self))
            self.tableView?.register(imageNib, forCellReuseIdentifier: URLTableViewCell.withImageNIBName)
            self.tableView?.register(noImageNib, forCellReuseIdentifier: URLTableViewCell.withOutImageNIBName)
            self.tableView?.allowsMultipleSelectionDuringEditing = true
            self.tableView?.rowHeight = URLTableViewCell.cellHeight
            self.tableView?.estimatedRowHeight = URLTableViewCell.cellHeight
        }
    }
    
    fileprivate typealias UIBBI = UIBarButtonItem
    fileprivate lazy var editBBI: UIBBI = UIBBI(barButtonSystemItem: UIBarButtonSystemItem.edit, target: self, action: #selector(self.editBBITapped(_:)))
    fileprivate lazy var doneBBI: UIBBI = UIBBI(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(self.doneBBITapped(_:)))
    fileprivate lazy var archiveBBI: UIBBI = UIBBI(title: "📥Archive", style: .plain, target: self, action: #selector(self.archiveBBITapped(_:)))
    fileprivate lazy var unarchiveBBI: UIBBI = UIBBI(title: "📤Unarchive", style: .plain, target: self, action: #selector(self.unarchiveBBITapped(_:)))
    fileprivate lazy var tagBBI: UIBBI = UIBBI(title: "🏷Tag", style: .plain, target: self, action: #selector(self.tagBBITapped(_:)))
    fileprivate lazy var sortBBI: UIBBI = UIBBI(title: "Sort", style: .plain, target: self, action: #selector(self.sortBBITapped(_:)))
    fileprivate lazy var filterBBI: UIBBI = UIBBI(title: "Filter", style: .plain, target: self, action: #selector(self.filterBBITapped(_:)))
    fileprivate let flexibleSpaceBBI: UIBBI = UIBBI(barButtonSystemItem: .flexibleSpace, target: .none, action: .none)
    fileprivate let verticalBarSpaceBBI: UIBBI = {
        let bbi = UIBBI(title: "|", style: .plain, target: .none, action: .none)
        bbi.isEnabled = false
        return bbi
    }()
    
    
    // MARK: Selection
    
    var itemsToLoad = URLItem.ItemsToLoad.all
    var filter: URLItem.ArchiveFilter = .unarchived
    var sortOrder: URLItem.SortOrder = .recentlyAddedOnTop
    
    fileprivate weak var selectionDelegate: URLItemsToLoadChangeDelegate?
    
    // MARK: Data
    
    fileprivate var data: Results<URLItem>?
    
    weak var realmController: RealmController? {
        didSet {
            // forward the message to any presented view controllers
            let addRemoveTagPopoverVC = (self.presentedViewController as? UINavigationController)?.viewControllers.first as? RealmControllable
            addRemoveTagPopoverVC?.realmController = self.realmController
            
            // reload the data
            self.hardReloadData()
        }
    }
    
    fileprivate var selectedURLItems: [URLItem]? {
        guard
            let data = self.data,
            let indexPaths = self.tableView?.indexPathsForSelectedRows,
            indexPaths.isEmpty == false
        else { return .none}
        let items = indexPaths.map({ data[$0.row] })
        return items
    }
    
    convenience init(selectionDelegate: URLItemsToLoadChangeDelegate, controller: RealmController?) {
        self.init()
        self.selectionDelegate = selectionDelegate
        self.realmController = controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // register for 3d touch events
        if case .available = self.traitCollection.forceTouchCapability {
            self.registerForPreviewing(with: self, sourceView: view)
        }
        
        // because we are in a split view, we fully own our own Navigation Controller
        // therefore we don't need to micromanage this when switching views.
        // its always present
        self.navigationController?.setToolbarHidden(false, animated: false)
        
        // configure myself for splitview
        self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
        self.navigationItem.leftItemsSupplementBackButton = true
        
        // put us into non-edit mode
        self.doneBBITapped(.none)
        self.disableAllBBI()
        
        // load the data
        self.hardReloadData()
    }
    
    fileprivate func hardReloadData() {
        // get values in case things change
        let itemsToLoad = self.itemsToLoad
        let filter = self.filter
        let sortOrder = self.sortOrder
        
        // set title
        switch itemsToLoad {
        case .all:
            self.title = "Hipstapaper"
        case .tag(let tagID):
            self.title = "🏷 \(tagID.displayName)"
        }
        
        // clear things out
        self.notificationToken?.stop()
        self.notificationToken = .none
        self.data = .none
        self.tableView?.reloadData()
        self.doneBBITapped(.none)
        
        // configure data source
        self.data = self.realmController?.urlItems(for: itemsToLoad, sortedBy: sortOrder, filteredBy: filter)
        self.notificationToken = self.data?.addNotificationBlock(self.realmResultsChangeClosure)
    }
    
    private lazy var realmResultsChangeClosure: ((RealmCollectionChange<Results<URLItem>>) -> Void) = { [weak self] changes in
        switch changes {
        case .initial:
            self?.tableView?.reloadData()
        case .update(_, let deletions, let insertions, let modifications):
            self?.tableView?.beginUpdates()
            self?.tableView?.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }), with: .right)
            self?.tableView?.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}), with: .left)
            self?.tableView?.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }), with: .automatic)
            self?.tableView?.endUpdates()
            let itemsSelectedAfterUpdate = self?.selectedURLItems ?? []
            self?.updateBBI(with: itemsSelectedAfterUpdate)
        case .error(let error):
            let alert = UIAlertController(title: "Error Loading Reading List", message: error.localizedDescription, preferredStyle: .alert)
            let action = UIAlertAction(title: "Dismiss", style: .cancel, handler: .none)
            alert.addAction(action)
            self?.present(alert, animated: true, completion: .none)
            self?.data = .none
            self?.tableView?.reloadData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tableView?.flashScrollIndicators()
        self.tableView?.deselectAllRows(animated: true)
    }
    
    private var notificationToken: NotificationToken?
    
    deinit {
        self.notificationToken?.stop()
    }
}

extension URLListViewController: URLItemsToLoadChangeDelegate {
    func didChange(itemsToLoad: URLItem.ItemsToLoad?, sortOrder: URLItem.SortOrder?, filter: URLItem.ArchiveFilter?, sender: ViewControllerSender) {
        switch sender {
        case .contentVC:
            fatalError()
        case .tertiaryVC:
            // if the user changes the selection in the custom VC, we need to notify the source list
            self.selectionDelegate?.didChange(itemsToLoad: itemsToLoad ?? self.itemsToLoad,
                                              sortOrder: sortOrder ?? self.sortOrder,
                                              filter: filter ?? self.filter,
                                              sender: .contentVC)
            // then fall through to follow the logic of normal selection coming from the source list
            fallthrough
        case .sourceListVC:
            var changedSomething = false
            if let itemsToLoad = itemsToLoad {
                self.itemsToLoad = itemsToLoad
                changedSomething = true
            }
            if let sortOrder = sortOrder {
                self.sortOrder = sortOrder
                changedSomething = true
            }
            if let filter = filter {
                self.filter = filter
                changedSomething = true
            }
            if changedSomething {
                self.hardReloadData()
            }
        }
    }
}

extension URLListViewController /* Handle BarButtonItems */ {
    @objc fileprivate func editBBITapped(_ sender: NSObject?) {
        let enterEditMode = {
            // manage the table view
            // if a row is slidden over, we need to close it
            if self.tableView?.isEditing ?? false { self.tableView?.setEditing(false, animated: true) }
            // then switch the table view to editing mode
            self.tableView?.setEditing(true, animated: true)
            
            // manage the toolbar item
            let items = [
                self.flexibleSpaceBBI,
                self.tagBBI,
                self.flexibleSpaceBBI,
                self.unarchiveBBI,
                self.flexibleSpaceBBI,
                self.archiveBBI,
                self.flexibleSpaceBBI,
                self.doneBBI
            ]
            self.disableAllBBI()
            self.setToolbarItems(items, animated: true)
        }
        
        // HIG states that a popover should be dismissiable and a new one presentable in one tap
        self.emergencyDismiss(thenDo: enterEditMode)
    }
    
    @objc fileprivate func doneBBITapped(_ sender: NSObject?) {
        self.tableView?.setEditing(false, animated: true)
        let items = [
            self.sortBBI,
            self.verticalBarSpaceBBI,
            self.filterBBI,
            self.flexibleSpaceBBI,
            self.editBBI
        ]
        self.disableAllBBI()
        self.setToolbarItems(items, animated: true)
    }
    
    @objc fileprivate func archiveBBITapped(_ sender: NSObject?) {
        guard let items = self.selectedURLItems else { return }
        self.realmController?.updateArchived(to: true, on: items)
        self.disableAllBBI()
    }
    
    @objc fileprivate func unarchiveBBITapped(_ sender: NSObject?) {
        guard let items = self.selectedURLItems else { return }
        self.realmController?.updateArchived(to: false, on: items)
        self.disableAllBBI()
    }
    
    @objc fileprivate func tagBBITapped(_ sender: NSObject?) {
        guard
            let bbi = sender as? UIBBI,
            let items = self.selectedURLItems,
            let realmController = self.realmController
        else { return }
        let tagVC = TagAddRemoveViewController.viewController(style: .popBBI(bbi), selectedItems: items, controller: realmController)
        self.present(tagVC, animated: true, completion: .none)
    }
    
    @objc fileprivate func sortBBITapped(_ sender: NSObject?) {
        guard let bbi = sender as? UIBBI else { return }
        let vc = SortSelectingiOSViewController.newPopover(kind: .sort(currentSort: self.sortOrder), delegate: self, from: bbi)
        // HIG states that a popover should be dismissiable and a new one presentable in one tap
        self.emergencyDismiss(thenPresentViewController: vc)
    }
    
    @objc fileprivate func filterBBITapped(_ sender: NSObject?) {
        guard let bbi = sender as? UIBBI else { return }
        let vc = SortSelectingiOSViewController.newPopover(kind: .filter(currentFilter: self.filter), delegate: self, from: bbi)
        // HIG states that a popover should be dismissiable and a new one presentable in one tap
        self.emergencyDismiss(thenPresentViewController: vc)
    }
    
    fileprivate func disableAllBBI() {
        self.archiveBBI.isEnabled = false
        self.unarchiveBBI.isEnabled = false
        self.tagBBI.isEnabled = false
    }
    
    fileprivate func updateBBI(with items: [URLItem]) {
        if items.isEmpty {
            self.disableAllBBI()
        } else {
            self.tagBBI.isEnabled = true
            self.archiveBBI.isEnabled = self.realmController?.atLeastOneItem(in: items, canBeArchived: true) ?? false
            self.unarchiveBBI.isEnabled = self.realmController?.atLeastOneItem(in: items, canBeArchived: false) ?? false
        }
    }
}

extension URLListViewController: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard
            let realmController = self.realmController,
            let tableView = self.tableView,
            let indexPath = tableView.indexPathForRow(at: self.view.convert(location, to: tableView)),
            let cellView = tableView.cellForRow(at: indexPath),
            let item = self.data?[indexPath.row],
            let url = URL(string: item.urlString)
        else { return .none }
        
        // Lets create some cool 3d actions
        // this code is almost a duplicate of the row actions
        // but ever so slightly different
        // might be able to abstract later, but for now, it works
        let archiveActionTitle = item.archived ? "📤 Unarchive" : "📥 Archive"
        let archiveAction = UIPreviewAction(title: archiveActionTitle, style: .default) { _ in
            let newArchiveValue = !item.archived
            realmController.updateArchived(to: newArchiveValue, on: [item])
        }
        let tagAction = UIPreviewAction(title: "🏷 Tag", style: .default) { [weak self] _ in
            let presentation = TagAddRemoveViewController.PresentationStyle.popCustom(rect: cellView.bounds, view: cellView)
            let tagVC = TagAddRemoveViewController.viewController(style: presentation, selectedItems: [item], controller: realmController)
            self?.present(tagVC, animated: true, completion: nil)
        }
        // use my special preview action injection SafariViewController
        // the actions are queried for on the presented view controller
        // but SFSafariViewController knows nothing about realm controller, no do I want it to
        let sfVC = PreviewActionInjectionSafariViewController(url: url, previewActions: [tagAction, archiveAction])
        
        // give the previewing context the Rect that the CellView is in so it knows where this 3d touch came from
        previewingContext.sourceRect = tableView.convert(cellView.frame, to: self.view)
        
        // return the configured view controller
        return sfVC
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        // i'm not sure why apple makes you do this
        // but they make you confirm that you actually want to present this new view controller
        // so I just check to make sure its a safari view controller of some kind
        // then present
        guard viewControllerToCommit is SFSafariViewController else { return }
        self.present(viewControllerToCommit, animated: true, completion: .none)
    }
}

extension URLListViewController: UITableViewDelegate {
 
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedItems = self.selectedURLItems ?? []
        if tableView.isEditing {
            self.updateBBI(with: selectedItems)
        } else {
            guard let selectedItem = selectedItems.first, let url = URL(string: selectedItem.urlString) else { return }
            let sfVC = SFSafariViewController(url: url, entersReaderIfAvailable: false)
            self.present(sfVC, animated: true, completion: .none)
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let selectedItems = self.selectedURLItems ?? []
        self.updateBBI(with: selectedItems)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return URLTableViewCell.cellHeight
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard
            let item = self.data?[indexPath.row],
            let cellView = tableView.cellForRow(at: indexPath),
            let realmController = self.realmController
        else { return .none }
        
        let archiveActionTitle = item.archived ? "📤Unarchive" : "📥Archive"
        let archiveToggleAction = UITableViewRowAction(style: .normal, title: archiveActionTitle) { action, indexPath in
            let newArchiveValue = !item.archived
            self.realmController?.updateArchived(to: newArchiveValue, on: [item])
        }
        archiveToggleAction.backgroundColor = tableView.tintColor
        
        let tagAction = UITableViewRowAction(style: .normal, title: "🏷Tag") { [weak self] action, indexPath in
            let selector: Selector = "_button"
            let popoverView: UIView
            if action.responds(to: selector), let actionButton = action.perform(selector)?.takeUnretainedValue() as? UIView {
                // use 'private' api to get the actual rect and view of the button the user clicked on
                // then present the popover from that view
                popoverView = actionButton
            } else {
                // if we can't get that button, then just popover on the cell view
                popoverView = cellView
            }
            let presentation = TagAddRemoveViewController.PresentationStyle.popCustom(rect: popoverView.bounds, view: popoverView)
            let tagVC = TagAddRemoveViewController.viewController(style: presentation, selectedItems: [item], controller: realmController)
            self?.present(tagVC, animated: true, completion: nil)
        }
        return [archiveToggleAction, tagAction]
    }
}

extension URLListViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.data?.count ?? 0
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = self.data?[indexPath.row]
        let identifier = item?.extras?.image == .none ? URLTableViewCell.withOutImageNIBName : URLTableViewCell.withImageNIBName
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        if let cell = cell as? URLTableViewCell, let item = item {
            cell.configure(with: item)
        }
        return cell
    }
}
