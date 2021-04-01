# QuestAPI

## Getting Started

Add to your podfile to install from repo

```
pod 'QuestAPI', :git => 'https://github.com/elislade/QuestAPI.git'
```

Before using `QuestAPI` you need to setup both the QuestAuthRedirect and QuestAuthClientId in your Info.plist from the values that Questrade provides in it's developer portal.


The QuestAPI is made up of three main pieces:
1. TokenStore
2. QuestAuth
3. QuestAPI


## TokenStore
The TokenStorable protocol is for you to conform to so that you can choose how to securly store the api token.
```
public protocol TokenStorable {
    func getToken() -> Data
    func setToken(_ token: Data)
}

class TokenStore: TokenStorable {
    // get/set
}
```

## QuestAuth
The `QuestAuth` class requires a class or struct that conforms to  `TokenStorable` .  `QuestAuth` is responsible for authorizing and deauthorizing requests.
```
let auth = iOSQuestAuth(tokenStore: TokenStore(), redirectURL: "https://myserver.com/authorize")
```
### QuestAuthDelegate

#### DidSignOut
`didSignOut` will be called whenever the authorizer can't auto reauthorize a request.
Here is some example code of how you might handle it:

```
extension LoginViewController: QuestAuthDelegate {
    func didSignOut(_ questAuth: QuestAuth) {
        let alertTitle = NSLocalizedString("Questrade Did Revoke Access", comment: "")
        let alertMsg = NSLocalizedString("Please sign-in again!", comment: "")
        let alertAction = NSLocalizedString("Okay", comment: "")

        let alertCtrl = UIAlertController(title: alertTitle, message: alertMsg, preferredStyle: .alert)
        alertCtrl.addAction(UIAlertAction(title: alertAction, style: .cancel, handler: { act in
            self.view.tintAdjustmentMode = .normal
        }))

        DispatchQueue.main.async {
            self.view.tintAdjustmentMode = .dimmed
            self.present(alertCtrl, animated: true, completion: nil)
        }
    }
}
```

### Initial Authorization

#### 1. Requesting Authorization

```
func setupAPIAuthorization() {
    if !auth.isAuthorized {
        auth.authorize { error in
            if let e = error {
                // Handle errors with authorization
            } else {
                // API was successfully authorized you can now interact with the API.
            }
        }
    }
}
```

#### 2. AppDelegate Complete Requesting Authorization

Pass the AppDelegate userActivity method onto the mirrored iOS authorization userActivity handler. This closes the loop when requesting authorization.

```
let auth = iOSAuthorizer()

func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    auth.application(application, continue: userActivity, restorationHandler: restorationHandler)
    return true
}
```

## QuestAPI
The `QuestAPI`  class requires an authorizer(`QuestAuth`)  on init so that all requests can be authorized.

```
let api = QuestAPI(authorizor: auth)

api.accounts { res in
    switch res {
    case .failure(let error): // log error
    case .success(let actResponse):
        let accounts = actResponse.accounts
    }
}
```

### QuestAPIDelegate

#### DidRecieveError

`didRecieveError` will be called whenever the API encounters an error.
Here is some example code of how you might handle it:

```
extension LoginViewController: QuestAPIDelegate {
    func didRecieveError(_ api:QuestAPI, error: Error) {
        let titleStr = NSLocalizedString("Error!", comment: "")
        let okayStr = NSLocalizedString("Okay", comment: "")
        let act = UIAlertController(title: titleStr, message: error.localizedDescription, preferredStyle: .alert)
        let okay = UIAlertAction(title: okayStr, style: .default, handler: nil)
        act.addAction(okay)

        DispatchQueue.main.async {
            self.present(act, animated: true, completion: nil)
        }
    }
}
```

## Full Init Code
Here is a full example of setting up QuestAPI

```
// Init iOSQuestAuth class with the token store
let auth = try iOSQuestAuth(tokenStore: TokenStore())

// Init QuestAPI with the authorizer
let api = QuestAPI(authorizor: auth)
```


## Using Mock Data

For testing purposes you can set `shouldUseMockResponse` on `QuestAPI` and you will get mock data response for all API calls after.
*NOTE: there is only mock data for some requests right now (found in the MockResponses folder).


## Authors

* **Eli Slade** - *Initial work* - [Eli Slade](https://github.com/elislade)

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
