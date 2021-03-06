//
//  TabAddRemoveViewController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/17/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import Common
import RealmSwift
import UIKit

class TagAddRemoveViewController: UIViewController, RealmControllable {
    
    enum PresentationStyle {
        case popBBI(UIBarButtonItem)
        case popCustom(rect: CGRect, view: UIView)
        case formSheet
    }
    
    class func viewController(style: PresentationStyle,
                              selectedItems: [URLItem.UIIdentifier],
                              controller: RealmController,
                              completionHandler:  @escaping (UIViewController) -> Void) -> UIViewController
    {
        let tagVC = TagAddRemoveViewController(selectedItems: selectedItems, controller: controller)
        let navVC = UINavigationController(rootViewController: tagVC)
        tagVC.restorationIdentifier = StateRestorationIdentifier.tertiaryPopOverViewController.rawValue
        navVC.restorationIdentifier = StateRestorationIdentifier.tertiaryPopOverNavVC.rawValue
        tagVC.presentationStyle = style
        tagVC.completionHandler = completionHandler
        switch style {
        case .popBBI(let bbi):
            navVC.modalPresentationStyle = .popover
            navVC.popoverPresentationController?.barButtonItem = bbi
        case .popCustom(let rect, let view):
            navVC.modalPresentationStyle = .popover
            navVC.popoverPresentationController?.sourceRect = rect
            navVC.popoverPresentationController?.sourceView = view
        case .formSheet:
            navVC.modalPresentationStyle = .formSheet
        }
        navVC.popoverPresentationController?.permittedArrowDirections = [.up, .down]
        navVC.presentationController?.delegate = tagVC
        return navVC
    }
    
    @IBOutlet fileprivate weak var tableView: UITableView? {
        didSet {
            let nib = UINib(nibName: TagAddRemoveTableViewCell.nibName, bundle: Bundle(for: TagAddRemoveTableViewCell.self))
            self.tableView?.register(nib, forCellReuseIdentifier: TagAddRemoveTableViewCell.nibName)
        }
    }
    
    fileprivate var data: AnyRealmCollection<TagItem>?
    fileprivate var itemsToTag: [URLItem.UIIdentifier] = []
    fileprivate private(set) var presentationStyle = PresentationStyle.formSheet
    fileprivate var completionHandler: ((UIViewController) -> Void)!
    weak var realmController: RealmController? {
        didSet {
            self.hardReloadData()
        }
    }
    
    private convenience init(selectedItems: [URLItem.UIIdentifier], controller: RealmController) {
        self.init()
        self.itemsToTag = selectedItems
        self.realmController = controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // title
        self.title = "Apply Tags"
        
        // configure dismiss buttons
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBBITapped(_:)))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.doneBBITapped(_:)))
        
        // load the data
        self.hardReloadData()
    }
    
    private func hardReloadData() {
        // reset everything
        self.notificationToken?.stop()
        self.notificationToken = nil
        self.data = nil
        self.tableView?.reloadData()
        
        // reload everything
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
            self.tableView?.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }), with: .right)
            self.tableView?.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}), with: .left)
            self.tableView?.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }), with: .automatic)
            self.tableView?.endUpdates()
        case .error(let error):
            assert(true != true, "\(error)")
        }
    }
    
    @objc private func doneBBITapped(_ sender: NSObject?) {
        self.completionHandler(self)
    }
    
    @objc private func addBBITapped(_ sender: NSObject?) {
        let alertVC = UIAlertController(title: "New Tag", message: nil, preferredStyle: .alert)
        alertVC.addTextField(configurationHandler: { $0.placeholder = "tag name" })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let addAction = UIAlertAction(title: "Add", style: .default) { _ in
            guard let realmController = self.realmController else { return }
            let newName = alertVC.textFields?.compactMap({ $0.text }).first ?? ""
            let tag = realmController.tag_uniqueTag(named: newName)
            realmController.tag_apply(tag: tag, to: self.itemsToTag)
        }
        alertVC.addAction(cancelAction)
        alertVC.addAction(addAction)
        self.present(alertVC, animated: true, completion: nil)
    }
    
    private var notificationToken: NotificationToken?
    
    deinit {
        self.notificationToken?.stop()
    }
}

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

extension TagAddRemoveViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return "No Tags Available"
        } else {
            return "\(self.itemsToTag.count) Item(s) Selected"
        }
    }
}

extension TagAddRemoveViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.data?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TagAddRemoveTableViewCell.nibName, for: indexPath)
        if let cell = cell as? TagAddRemoveTableViewCell, let tagItem = self.data?[indexPath.row] {
            cell.tagNameLabel?.text = tagItem.name
            cell.index = indexPath.row
            let state = self.realmController?.tag_applicationState(of: tagItem, on: self.itemsToTag) ?? .mixed
            cell.tagSwitch?.isOn = state.boolValue
            cell.delegate = self
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            guard let tagItem = self.data?[indexPath.row] else { return }
            self.realmController?.delete([tagItem])
        case .insert, .none:
            break
        @unknown default:
            break
        }
    }
}

extension TagAddRemoveViewController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        self.completionHandler(self)
        return false
    }
}
extension TagAddRemoveViewController: UIAdaptivePresentationControllerDelegate {

    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        
        switch self.presentationStyle {
        case .popBBI, .popCustom:
            // if we were able to present as popover
            // always present as popover, on any device
            // returning .none tells the system DO NOT adapt, so it stays as a popover
            return .none
        case .formSheet:
            return .formSheet
        }
    }

}
