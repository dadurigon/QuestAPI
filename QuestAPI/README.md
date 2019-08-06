# QuestAPI

A native Swift API for Questrade. The QuestAPI is made up of three main pieces:
1. KeychainStore
2. QuestAuth
3. QuestAPI


## KeychainStore
The KeychainStore is a [Locksmith](https://github.com/matthewpalmer/Locksmith) abstraction responsible for encrypting and decrypting your API access tokens behind the scenes so you don't have to worry about it.
```
let keychain = AuthKeychainStore(service: ..., account: ..., data: [:])
```

## QuestAuth
The `QuestAuth` class requires a `KeychainStore` instance for init. `QuestAuth` is responsible for authorizing and deauthorizing requests.
```
let auth = try iOSQuestAuth(keychainStore: keychain)
```

## QuestAPI
`QuestAPI` is what you interact with. It requires an authorizer(`QuestAuth`) so that all requests can be authorized. You make a call by 

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

## Getting Started

Right now there is only [cocoapods](https://cocoapods.org) support.

```

pod install QuestAPI
```

Before using `QuestAPI` you need to setup both the QuestAuthRedirect and QuestAuthClientId in your Info.plist from the values that Questrade provides in it's developer portal.

Here is a full example of setting up QuestAPI

```
// First setup the keychain store for your app
// The keychain store is responsible for encrypting and decrypting your API access tokens behind the scenes so you don't have to worry about doing it.
let keychain = AuthKeychainStore(service: ..., account: ..., data: [:])

// since the init could throw errors you will have to wrap it in a do catch

do {
    // hand the keychain store to the iOSQuestAuth class
    // The QuestAuth class is responsible for authenticating all api requests to the api.
    let auth = try iOSQuestAuth(keychainStore: keychain)
    auth.refreshToken()
    
    // Finally hand the authorizer to the API.
    // The API is where you make all requests
    let api = QuestAPI(authorizor: auth)
    QuestAPI.shared = api
} catch let err {
   // handle error
}
```


## Using Mock Data

For testing purposes you can set `shouldUseMockResponse` on `QuestAPI` and you will get mock data response for all API calls after.
*NOTE: there is only mock data for some requests right now (found in the MockResponses folder).


## Deployment

Add additional notes about how to deploy this on a live system


## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **Eli Slade** - *Initial work* - [Eli Slade](https://github.com/eli_slade)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
