
import Foundation

public typealias Completion<T> = (T) -> Void

public struct AuthResponse: Codable {
    let access_token:String
    let refresh_token:String
    let api_server:URL
    let expires_in:Int
    let token_type:String
}

public protocol QuestAuthDelegate {
    func didSignOut(_ questAuth:QuestAuth)
}

public enum QuestAuthError: Error {
    case authInfoMissing, authAttemptsRanOut, urlParsingIssue, missingClientID, missingRedirectURL
}

public class QuestAuth: NSObject, URLRequestCodable {
    public var apiDelegate: URLRequestCodableDelegate?
    
    public var encoder = JSONEncoder()
    public var decoder = JSONDecoder()
    public var session = URLSession.shared
    public var delegate:QuestAuthDelegate?
    
    let baseURL = "https://login.questrade.com/oauth2/"
    
    private let clientId:String
    private let redirectURL:String
    
    private let tokenManager:TokenManager<AuthResponse>
    public var token:AuthResponse? {
        get {
            return tokenManager.token
        }
        set {
            tokenManager.token = newValue
        }
    }
    
    public init(keychainStore:AuthKeychainStore) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        decoder.dateDecodingStrategy = .formatted(formatter)
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        var _clientID:String?
        var _redirect:String?
        
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist") {
            if let infoDictionary = NSDictionary(contentsOfFile: path) {
                _clientID = infoDictionary["QuestAuthClientId"] as? String
                _redirect = infoDictionary["QuestAuthRedirect"] as? String
            }
        }
        
        if let client = _clientID {
            clientId = client
        } else {
            throw QuestAuthError.missingClientID
        }
        
        if let redirect = _redirect {
            redirectURL = redirect
        } else {
            throw QuestAuthError.missingRedirectURL
        }
        
        tokenManager = TokenManager<AuthResponse>(keychain: keychainStore)
    }
    
    private func signOut() {
        do {
            try self.tokenManager.delete()
            self.delegate?.didSignOut(self)
        } catch _ {
        }
    }
    
    public func revokeAccess(completion:(() -> Void)? = nil) {
        let _completion:APIRes<Data> = { _ in
            self.signOut()
            completion?()
        }

        let endpoint = baseURL + "revoke"
        if let req = authorizedTemplateRequest(baseURL: endpoint) {
            autoAuth(req, completion: _completion)
        }
    }
    
    func authorizedTemplateRequest(baseURL:String? = nil) -> URLRequest? {
        guard let token = token else { return nil }
        let u:URL = baseURL != nil ? URL(string: baseURL!)! : token.api_server
        var r = URLRequest(url: u)
        r.addValue("Bearer \(token.access_token)", forHTTPHeaderField: "Authorization")
        return r
    }
    
    func autoAuth<T: Decodable>(_ request:URLRequest, completion:@escaping APIRes<T>, attempts:Int = 3) {
        var executed = false
        
        if attempts == 0 {
            completion(.failure(QuestAuthError.authAttemptsRanOut))
        }
    
        let _completion:APIRes<T> = { res in
            if executed { return }
            
            if case .failure(let error) = res {
                let code = (error as NSError).code
                if code == 401 {
                    self.refreshToken { err in
                        if err == nil && !executed {
                            if var newRequest = self.authorizedTemplateRequest(baseURL: request.url?.absoluteString) {
                                newRequest.httpBody = request.httpBody
                                newRequest.httpMethod = request.httpMethod
                                self.autoAuth(newRequest, completion: completion, attempts: attempts - 1)
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
    
    public func refreshToken(completion:Completion<Error?>? = nil) {
        guard let auth = token else {
            completion?(QuestAuthError.authInfoMissing)
            return
        }
        
        let _completion: APIRes<AuthResponse> = { res in
            switch res {
            case .failure(let error):
                self.signOut()
                completion?(error)
            case .success(let _authInfo):
                self.tokenManager.token = _authInfo
                completion?(nil)
            }
        }
        
        let endpoint = baseURL + "token?grant_type=refresh_token&refresh_token=\(auth.refresh_token)"
        if let req = authorizedTemplateRequest(baseURL: endpoint) {
            autoAuth(req, completion: _completion)
        }
    }
    
    var authURLString: String {
        let redirectURI = "redirect_uri=\(redirectURL)"
        let responseType = "response_type=token"
        let clientID = "client_id=\(clientId)"
        return baseURL + "authorize?\(clientID)&\(responseType)&\(redirectURI)"
    }
    
    func parseAuthResponse(from url: URL) -> AuthResponse? {
        let u = url.absoluteString.replacingOccurrences(of: "#", with: "?")
        if let items = URLComponents(string: u)?.queryItems {
            let d = items.reduce([String: String]()) { (dict, query) -> [String: String] in
                var dict = dict
                dict[query.name] = query.value
                return dict
            }
            
            guard let a = d["access_token"], let r = d["refresh_token"], let s = d["api_server"], let sURL = URL(string: s), let exp = d["expires_in"], let expInt = Int(exp), let type = d["token_type"] else {
                return nil
            }
            
            return AuthResponse(access_token: a, refresh_token: r, api_server: sURL, expires_in: expInt, token_type: type)
        }
        return nil
    }
}
