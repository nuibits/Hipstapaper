//
//  URLItemSavingShareViewController.swift
//  Hipstapaper
//
//  Created by Jeffrey Bergier on 12/7/16.
//  Copyright © 2016 Jeffrey Bergier. All rights reserved.
//

import HipstapaperPersistence
import UIKit

@objc(URLItemSavingShareViewController)
class URLItemSavingShareViewController: UIViewController {
    
    private enum UIState {
        case saving, saved, saveError, noItemsError
    }
    
    @IBOutlet private weak var containerViewVerticalSpaceConstraint: NSLayoutConstraint?
    @IBOutlet private weak var containerView: UIView?
    @IBOutlet private weak var messageLabel: UILabel?
    @IBOutlet private weak var dismissButton: UIButton?
    @IBOutlet private weak var stackView: UIStackView?
    
    private var uiState = UIState.saving {
        didSet {
            DispatchQueue.main.async {
                switch self.uiState {
                case .saving:
                    self.containerViewVerticalSpaceConstraint?.constant = 312
                    self.dismissButton?.isHidden = true
                    self.messageLabel?.text = "Saving..."
                case .saved:
                    self.containerViewVerticalSpaceConstraint?.constant = 0
                    self.dismissButton?.isHidden = true
                    self.messageLabel?.text = "Saved!"
                case .saveError:
                    self.containerViewVerticalSpaceConstraint?.constant = 312
                    self.dismissButton?.isHidden = false
                    self.messageLabel?.text = "An error ocurred"
                case .noItemsError:
                    self.containerViewVerticalSpaceConstraint?.constant = 312
                    self.dismissButton?.isHidden = false
                    self.messageLabel?.text = "No Web Site Found to Save"
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.containerView?.layer.cornerRadius = 5
        self.containerView?.layer.borderColor = UIColor.lightGray.cgColor
        self.containerView?.layer.borderWidth = 1
        
        self.containerViewVerticalSpaceConstraint?.constant = self.view.frame.height
        self.uiState = .saved
        self.go()
    }
    
    private func go() {
        // make sure the UI is in saving... mode
        self.uiState = .saving
        // detect any URLs
        self.extensionContext?.jsb_inputItems.mapURLs() { urlMapResult in
            switch urlMapResult {
            case .error(let errors):
                // if no URL's change to no items error state
                // the user has to manually dismiss the sheet now
                NSLog("Error Getting URLs: \(errors)")
                self.uiState = .noItemsError
            case .success(let urls):
                // if there are URLs, we need to just grab the first one
                guard let url = urls.first else { self.uiState = .noItemsError; return; }
                // create the item in the realm
                self.createItem(with: url, in: RealmURLItemSyncingController()) { realmResult in
                    switch realmResult {
                    case .error:
                        // if there is an error change error state
                        // the user has to manually dismiss the sheet now
                        self.uiState = .saveError
                    case .success(let realmItem):
                        DispatchQueue.main.async {
                            // if successful change to saved UI state and tell the system we have completed the request
                            self.uiState = .saved
                            self.extensionContext!.completeRequest(returningItems: []) { _ in
                                // in the completion handler, we can perform background work
                                // so now its time to save it to the cloud
                                self.createAnotherItem(withRealmItem: realmItem, in: CloudKitURLItemSyncingController(), completionHandler: .none)
                            }
                        }
                    }
                }
            }
        }
    }

    private func createItem(with url: URL, in realm: SingleSourcePersistenceType, completionHandler: URLItemResult?) {
        let realm: SingleSourcePersistenceType = RealmURLItemSyncingController()
        realm.createItem(withID: .none) { realmCreateResult in
            switch realmCreateResult {
            case .error(let errors):
                NSLog("Error Creating in Realm: \(errors)")
                completionHandler?(realmCreateResult)
            case .success(var newItem):
                newItem.urlString = url.absoluteString
                realm.update(item: newItem) { realmUpdateResult in
                    switch realmUpdateResult {
                    case .error(let errors):
                        NSLog("Error Updating in Realm: \(errors)")
                    case .success:
                        NSLog("Successfully Saved Item in Realm")
                    }
                    completionHandler?(realmUpdateResult)
                }
            }
        }
    }
    
    private func createAnotherItem(withRealmItem realmItem: URLItemType, in cloud: SingleSourcePersistenceType, completionHandler: URLItemResult?) {
        cloud.createItem(withID: realmItem.cloudKitID) { cloudCreateResult in
            switch cloudCreateResult {
            case .error(let errors):
                NSLog("Error Creating in Cloud: \(errors)")
            case .success(var cloudItem):
                cloudItem.cloudKitID = realmItem.cloudKitID
                cloudItem.realmID = realmItem.realmID
                cloudItem.urlString = realmItem.urlString
                cloudItem.archived = realmItem.archived
                cloudItem.tags = realmItem.tags
                cloudItem.modificationDate = realmItem.modificationDate
                cloud.update(item: cloudItem) { cloudUpdateResult in
                    switch cloudUpdateResult {
                    case .error(let errors):
                        NSLog("Error Updating in Cloud: \(errors)")
                    case .success:
                        NSLog("Successfully Saved Item in Cloud")
                    }
                    completionHandler?(cloudUpdateResult)
                }
            }
        }
    }
    
    @IBAction private func cancel(_ sender: AnyObject?) {
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        self.extensionContext!.cancelRequest(withError: cancelError)
    }
    
}