//
//  SortSelectingiOSViewController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 1/7/17.
//  Copyright © 2017 Jeffrey Bergier. All rights reserved.
//

import Common
import UIKit

class SortSelectingViewController: UIViewController {
    
    // MARK: Custom Types
    
    enum Kind {
        case sort(currentSort: URLItem.SortOrder), filter(currentFilter: URLItem.ArchiveFilter)
    }
    
    static func newPopover(kind: Kind, delegate: URLItemsToLoadChangeDelegate, from bbi: UIBarButtonItem) -> UIViewController {
        let vc = SortSelectingViewController(kind: kind, delegate: delegate)
        let navVC = UINavigationController(rootViewController: vc)
        vc.restorationIdentifier = StateRestorationIdentifier.tertiaryPopOverViewController.rawValue
        navVC.restorationIdentifier = StateRestorationIdentifier.tertiaryPopOverNavVC.rawValue
        navVC.modalPresentationStyle = .popover
        navVC.popoverPresentationController?.delegate = vc
        navVC.popoverPresentationController?.barButtonItem = bbi
        return navVC
    }
    
    // MARK: Handle Selection
    
    fileprivate var kind = Kind.filter(currentFilter: .unarchived)
    private weak var selectionDelegate: URLItemsToLoadChangeDelegate?
    
    // MARK: Outlets
    
    @IBOutlet private weak var pickerView: UIPickerView?
    
    // MARK: Loading
    
    convenience init(kind: Kind, delegate: URLItemsToLoadChangeDelegate) {
        self.init()
        self.selectionDelegate = delegate
        self.kind = kind
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.doneBBITapped(_:)))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelBBITapped(_:)))
        
        switch self.kind {
        case .sort(let current):
            self.title = "Sort"
            self.pickerView?.selectRow(current.rawValue, inComponent: 0, animated: false)
        case .filter(let current):
            self.title = "Filter"
            self.pickerView?.selectRow(current.rawValue, inComponent: 0, animated: false)
        }
    }
    
    @objc private func doneBBITapped(_ sender: NSObject?) {
        let selection = self.pickerView?.selectedRow(inComponent: 0) ?? 55
        switch self.kind {
        case .filter(let current):
            guard let new = URLItem.ArchiveFilter(rawValue: selection), new != current else { break }
            self.selectionDelegate?.didChange(itemsToLoad: nil, sortOrder: nil, filter: new, sender: .tertiaryVC)
        case .sort(let current):
            guard let new = URLItem.SortOrder(rawValue: selection), new != current else { break }
            self.selectionDelegate?.didChange(itemsToLoad: nil, sortOrder: new, filter: nil, sender: .tertiaryVC)
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func cancelBBITapped(_ sender: NSObject?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override var preferredContentSize: CGSize {
        get {
            let frameWorkSize = super.preferredContentSize
            switch self.kind {
            case .filter:
                return CGSize(width: frameWorkSize.width, height: 200)
            case .sort:
                return CGSize(width: frameWorkSize.width, height: 250)
            }
        }
        set {
            super.preferredContentSize = newValue
        }
    }
}

extension SortSelectingViewController: UIPickerViewDataSource {
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch self.kind {
        case .filter:
            return URLItem.ArchiveFilter.count
        case .sort:
            return URLItem.SortOrder.count
        }
    }
}

extension SortSelectingViewController: UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch self.kind {
        case .filter:
            let filter = URLItem.ArchiveFilter(rawValue: row)
            return filter?.displayName ?? "Error"
        case .sort:
            let sort = URLItem.SortOrder(rawValue: row)
            return sort?.displayName ?? "Error"
        }
    }
}

extension SortSelectingViewController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        return true
    }
}
extension SortSelectingViewController: UIAdaptivePresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        // returning .none tells the system DO NOT adapt, so it stays as a popover
        return .none
    }
}
