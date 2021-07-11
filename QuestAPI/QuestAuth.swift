
import Foundation

public typealias Completion<T> = (T) -> Void

public struct AuthResponse: Codable {
    let access_token: String
    let refresh_token: String
    let api_server: URL
    let token_type: String
    let expiryDate: Date
}

public protocol QuestAuthDelegate {
    func didSignOut(_ questAuth: QuestAuth)
    func didAuthorize(_ questAuth: QuestAuth)
    func didFailToAuthorize(_ questAuth: QuestAuth, with error: QuestAuth.Error)
}

public class QuestAuth: NSObject, URLRequestCodable {
    
    public enum Error: Swift.Error {
        case authInfoMissing, authAttemptsRanOut, urlParsingIssue, missingClientID, missingRedirectURL
    }
    
    let baseURL = "https://login.questrade.com/oauth2/"
    
    let clientId: String
    let redirectURL: String
    
    private let _tokenStorage: StorageCoder<AuthResponse>
    
    var auth: AuthResponse? {
        get { _tokenStorage.value }
        set { _tokenStorage.value = newValue }
    }
    
    var authURLString: String {
        let redirectURI = "redirect_uri=\(redirectURL)"
        let responseType = "response_type=token"
        let clientID = "client_id=\(clientId)"
        return baseURL + "authorize?\(clientID)&\(responseType)&\(redirectURI)"
    }
    
    public var requestDelegate: URLRequestCodableDelegate?
    
    public var encoder = JSONEncoder()
    public var decoder = JSONDecoder()
    public var session = URLSession.shared
    public var delegate: QuestAuthDelegate?
    public var isAuthorized: Bool {
        if let t = auth {
            return t.expiryDate > Date()
        }
        
        return false
    }
    
    public init(tokenStore: Storable, clientID: String, redirectURL: String) {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        decoder.dateDecodingStrategy = .formatted(formatter)
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        self.clientId = clientID
        self.redirectURL = redirectURL
        self._tokenStorage = StorageCoder<AuthResponse>(storage: tokenStore)
    }
    
    private func signOut() {
        auth = nil
        delegate?.didSignOut(self)
    }
    
    public func revokeAccess(completion: (() -> Void)? = nil) {
        print("revoke access")
        
        let _completion: APIRes<Data> = { _ in
            self.signOut()
            completion?()
        }

        let endpoint = baseURL + "revoke"
        if let req = authorizedTemplateRequest(baseURL: endpoint) {
            autoAuth(req, completion: _completion)
        }
    }
    
    func authorizedTemplateRequest(baseURL: String? = nil) -> URLRequest? {
        guard let auth = auth else { return nil }
        let u: URL = baseURL != nil ? URL(string: baseURL!)! : auth.api_server
        var r = URLRequest(url: u)
        r.addValue("\(auth.token_type) \(auth.access_token)", forHTTPHeaderField: "Authorization")
        return r
    }
    
    
    // FIXME: Needs logic improvement
    
    func autoAuth<T>(_ request: URLRequest, attempts: Int = 3, completion: @escaping APIRes<T>) {
        var executed = false
        
        if attempts == 0 {
            completion(.failure(Error.authAttemptsRanOut))
        }
    
        let _completion: APIRes<T> = { res in
            if executed { return }
            
            if case .failure(let error) = res {
                let code = (error as NSError).code
                if code == 401 {
                    self.refreshToken { err in
                        if err == nil && !executed {
                            if var newRequest = self.authorizedTemplateRequest(baseURL: request.url?.absoluteString) {
                                newRequest.httpBody = request.httpBody
                                newRequest.httpMethod = request.httpMethod
                                self.autoAuth(newRequest, attempts: attempts - 1, completion: completion)
                            }
                        }
                    }
                } else {
                    completion(res)
                    executed = true
                }
            } else {
                completion(res)
                executed = true
            }
        }
        make(request, completion: _completion)
    }
    
    public func refreshToken(completion: Completion<Swift.Error?>? = nil) {
        guard let auth = auth else {
            completion?(Error.authInfoMissing)
            return
        }
        
        let _completion: APIRes<AuthResponse> = { res in
            switch res {
            case .failure(let error):
                self.signOut()
                completion?(error)
            case .success(let _authInfo):
                self.auth = _authInfo
                completion?(nil)
            }
        }
        
        let endpoint = baseURL + "token?grant_type=refresh_token&refresh_token=\(auth.refresh_token)"
        if let req = authorizedTemplateRequest(baseURL: endpoint) {
            autoAuth(req, completion: _completion)
        }
    }
    
    public func authorize(from url: URL) {
        if let auth = parseAuthResponse(from: url) {
            self.auth = auth
            self.delegate?.didAuthorize(self)
        }
    }
    
    func parseAuthResponse(from url: URL) -> AuthResponse? {
        let u = url.absoluteString.replacingOccurrences(of: "#", with: "?")
        if let items = URLComponents(string: u)?.queryItems {
            let d = items.reduce([String: String]()) { (dict, query) -> [String: String] in
                var dict = dict
                dict[query.name] = query.value
                return dict
            }
            
            guard
                let accToken = d["access_token"],
                let refToken = d["refresh_token"],
                let apiURL = URL(string: d["api_server"] ?? ""),
                let exp = d["expires_in"],
                let type = d["token_type"]
            else { return nil }

            return AuthResponse(
                access_token: accToken,
                refresh_token: refToken,
                api_server: apiURL,
                token_type: type,
                expiryDate: Date().addingTimeInterval(Double(exp) ?? 0)
            )
        }
        return nil
    }
}
