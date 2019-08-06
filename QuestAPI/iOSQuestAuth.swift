
import UIKit
import SafariServices

public struct APIDelegate: URLRequestCodableDelegate {
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

public protocol QuestAuthCtrlCostomizable {
    func willPrepareAuthCtrl(for customization: inout AuthViewControllerCustomization)
}

public struct AuthViewControllerCustomization {
    public var preferredControlTintColor:UIColor?
    public var preferredBarTintColor:UIColor?
}

public enum iOSQuestAuthError: Error {
    case authControllerWasDismissed
}

public class iOSQuestAuth: QuestAuth {
    
    private var authCompletion: Completion<Error?>?
    private var presentedAuthCtrl: UIViewController?
    
    public var authCtrlDelegate:QuestAuthCtrlCostomizable?
    
    override public init(keychainStore: AuthKeychainStore) throws {
        try super.init(keychainStore: keychainStore)
        apiDelegate = APIDelegate()
    }
    
    public func authorize(completion:Completion<Error?>? = nil) {
        guard let url = URL(string: authURLString) else {
            completion?(QuestAuthError.urlParsingIssue)
            return
        }
        
        authCompletion = completion
        
        let safari = SFSafariViewController(url: url)
        var customization = AuthViewControllerCustomization()
        authCtrlDelegate?.willPrepareAuthCtrl(for: &customization)
        safari.preferredBarTintColor = customization.preferredBarTintColor
        safari.preferredControlTintColor = customization.preferredControlTintColor
        safari.modalPresentationStyle = .formSheet
        safari.delegate = self
        
        DispatchQueue.main.async {
            if let ctrl = UIApplication.shared.keyWindow?.rootViewController {
                ctrl.present(safari, animated: true, completion: {
                    self.presentedAuthCtrl = safari
                })
            }
        }
    }
    
    public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) {
        if token != nil { return }
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            if let url = userActivity.webpageURL {
                if let auth = parseAuthResponse(from: url) {
                    token = auth
                    DispatchQueue.main.async {
                        self.presentedAuthCtrl?.dismiss(animated: true) {
                            self.authCompletion?(nil)
                            self.authCompletion = nil
                        }
                    }
                } else {
                    authCompletion?(QuestAuthError.urlParsingIssue)
                    authCompletion = nil
                    presentedAuthCtrl = nil
                }
            }
        }
    }
}

extension iOSQuestAuth: SFSafariViewControllerDelegate {
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        authCompletion?(iOSQuestAuthError.authControllerWasDismissed)
        authCompletion = nil
        presentedAuthCtrl = nil
    }
}
