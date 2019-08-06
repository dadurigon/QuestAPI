
import Foundation
import Locksmith

public struct AuthKeychainStore: ReadableSecureStorable, CreateableSecureStorable, GenericPasswordSecureStorable, DeleteableSecureStorable {
    // Required by GenericPasswordSecureStorable
    public let service:String
    public let account:String
    
    // Required by CreateableSecureStorable
    public var data: [String: Any] = [:]
    
    public init(service:String, account:String, data: [String: Any]) {
        self.service = service
        self.account = account
        self.data = data
    }
}

public class TokenManager<TokenType:Codable> {
    
    private let dataKey = "token"
    
    private var backingToken:TokenType?
    public var token:TokenType? {
        set(newValue) {
            backingToken = newValue
            
            if token != nil && newValue != nil {
                try! update()
            }
            
            if newValue != nil && token == nil {
                try! save(encoder: encoder)
            }
        }
        
        get {
            if let tokens = backingToken {
                return tokens
            } else {
                backingToken = try! load(decoder: decoder)
                return backingToken
            }
        }
    }
    
    public var keychain:AuthKeychainStore
    public var encoder = JSONEncoder()
    public var decoder = JSONDecoder()
    
    init(keychain:AuthKeychainStore) {
        self.keychain = keychain
    }
    
    func save(encoder:JSONEncoder) throws {
        let data = try encoder.encode(token)
        keychain.data[dataKey] = data
        try keychain.createInSecureStore()
    }
    
    func update() throws {
        let data = try encoder.encode(token)
        keychain.data[dataKey] = data
        try keychain.updateInSecureStore()
    }
    
    func load(decoder:JSONDecoder) throws -> TokenType? {
        if let result = keychain.readFromSecureStore() {
            if let tokenData = result.data?[dataKey] as? Data {
                return try decoder.decode(TokenType.self, from: tokenData)
            } else {
                return nil
            }
        }
        return nil
    }
    
    func delete() throws {
        try keychain.deleteFromSecureStore()
        token = nil
    }
}
