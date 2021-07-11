
import UIKit
import SafariServices

public protocol iOSQuestAuthDelegate {
    func willPrepare(_ auth: iOSQuestAuth, for customization: inout iOSQuestAuth.VisualCustomization)
    func didDismiss(_ auth: iOSQuestAuth)
}

public class iOSQuestAuth: QuestAuth {
    
    private var presentedCtrl: UIViewController?
    
    public var authCtrlDelegate: iOSQuestAuthDelegate?
    
    override public init(tokenStore: Storable, clientID: String, redirectURL: String) {
        super.init(tokenStore: tokenStore, clientID: clientID, redirectURL: redirectURL)
        requestDelegate = self
    }
    
    public func authorize() {
        guard let url = URL(string: authURLString) else {
            delegate?.didFailToAuthorize(self, with: .urlParsingIssue)
            return
        }
        
        let safari = SFSafariViewController(url: url)
        var customization = VisualCustomization()
        authCtrlDelegate?.willPrepare(self, for: &customization)
        safari.preferredBarTintColor = customization.preferredBarTintColor
        safari.preferredControlTintColor = customization.preferredControlTintColor
        safari.modalPresentationStyle = customization.modalPresentationStyle ?? .formSheet
        safari.delegate = self
        
        DispatchQueue.main.async {
            if let ctrl = UIApplication.shared.keyWindow?.rootViewController {
                ctrl.present(safari, animated: true, completion: {
                    self.presentedCtrl = safari
                })
            }
        }
    }
    
    public override func authorize(from url: URL) {
        if let res = parseAuthResponse(from: url) {
            auth = res
            print("parse", res)
            delegate?.didAuthorize(self)
            DispatchQueue.main.async {
                self.presentedCtrl?.dismiss(animated: true)
            }
        } else {
            delegate?.didFailToAuthorize(self, with: .urlParsingIssue)
            presentedCtrl = nil
        }
    }
    
    public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) {
        //if token != nil { return }
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            if let url = userActivity.webpageURL {
                if let res = parseAuthResponse(from: url) {
                    auth = res
                    print("parse", res)
                    delegate?.didAuthorize(self)
                    DispatchQueue.main.async {
                        self.presentedCtrl?.dismiss(animated: true)
                    }
                } else {
                    delegate?.didFailToAuthorize(self, with: .urlParsingIssue)
                    presentedCtrl = nil
                }
            }
        }
    }
}

extension iOSQuestAuth: SFSafariViewControllerDelegate {
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        authCtrlDelegate?.didDismiss(self)
        presentedCtrl = nil
    }
}

extension iOSQuestAuth {
    public struct VisualCustomization {
        public var preferredControlTintColor: UIColor?
        public var preferredBarTintColor: UIColor?
        public var modalPresentationStyle: UIModalPresentationStyle?
    }
}

extension iOSQuestAuth: URLRequestCodableDelegate {
    public func willMake(request: URLRequest) {
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
    }
    
    public func didMake(request: URLRequest) {
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
}
