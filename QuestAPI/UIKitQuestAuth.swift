
import UIKit
import SafariServices

public protocol UIKitQuestAuthDelegate: QuestAuthDelegate {
    func willPrepare(_ auth: UIKitQuestAuth, for customization: inout UIKitQuestAuth.VisualCustomization)
    func didDismiss(_ auth: UIKitQuestAuth)
}

public class UIKitQuestAuth: QuestAuth {
    
    private var presentedCtrl: UIViewController?
    private var uiKitDelegate: UIKitQuestAuthDelegate? { delegate as? UIKitQuestAuthDelegate }
    
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
        uiKitDelegate?.willPrepare(self, for: &customization)
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
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return }
        guard let url = userActivity.webpageURL else { return }
 
        authorize(from: url)
    }
}

extension UIKitQuestAuth: SFSafariViewControllerDelegate {
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        uiKitDelegate?.didDismiss(self)
        presentedCtrl = nil
    }
}

extension UIKitQuestAuth {
    public struct VisualCustomization {
        public var preferredControlTintColor: UIColor?
        public var preferredBarTintColor: UIColor?
        public var modalPresentationStyle: UIModalPresentationStyle?
    }
}

extension UIKitQuestAuth: URLRequestCodableDelegate {
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
