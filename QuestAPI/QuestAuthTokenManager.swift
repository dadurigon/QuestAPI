
import Foundation

public protocol TokenStorable {
    func getToken() -> Data
    func setToken(_ token: Data)
}

public class TokenManager<Token: Codable> {
    
    private var _token: Token?
    
    public var token: Token? {
        set(newValue) {
            _token = newValue
            saveToken()
        }
        
        get {
            if let tokens = _token {
                return tokens
            } else {
                _token = loadToken()
                return _token
            }
        }
    }
    
    var storage: TokenStorable
    var encoder = JSONEncoder()
    var decoder = JSONDecoder()
    
    init(storage: TokenStorable) {
        self.storage = storage
    }
    
    private func saveToken() {
        let data = try? encoder.encode(token)
        storage.setToken(data ?? Data())
    }
    
    private func loadToken() -> Token? {
        return try? decoder.decode(Token.self, from: storage.getToken())
    }
    
}
