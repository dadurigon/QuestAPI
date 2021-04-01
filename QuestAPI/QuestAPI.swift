
import Foundation

public protocol QuestAPIDelegate {
    func didRecieveError(_ api: QuestAPI, error: Error)
}

public enum QuestAPIError: Error {
    case missingMockDataBundle, missingAuthorizedRequest
}

public class QuestAPI: NSObject {
    
    let version = "v1"
    let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return f
    }()
    
    public let authorizer: QuestAuth
    
    public var delegate: QuestAPIDelegate?
    
    // if enabled API requests will responed with mock data when available
    public var shouldUseMockResponse = false
    
    public init(authorizor:QuestAuth) {
        self.authorizer = authorizor
    }
    
    private func mockResponse<T>(_ completion: @escaping APIRes<T>) {
        guard
            let bundleUrl = Bundle(for: type(of: self)).resourceURL?.appendingPathComponent("QuestAPIMockData.bundle"),
            let bundle = Bundle(url: bundleUrl)
        else {
            completion(.failure(QuestAPIError.missingMockDataBundle))
            return
        }
        
        func loadJson(file: URL) {
            do {
                let data = try Data(contentsOf: file, options: .mappedIfSafe)
                let p = try authorizer.decoder.decode(T.self, from: data)
                completion(.success(p))
            } catch let error {
                completion(.failure(error))
            }
        }
        
        if let path = bundle.path(forResource: "\(T.self)", ofType: "json") {
            loadJson(file: URL(fileURLWithPath: path))
        }
    }
    
    private func errorMiddleware<T>(_ completion: @escaping APIRes<T>) -> APIRes<T> {
        let _completion: APIRes<T> = { res in
            if case .failure(let error) = res {
                self.delegate?.didRecieveError(self, error: error)
            }
            completion(res)
        }
        return _completion
    }
    
    func queryString(_ dict: [String : Any?]) -> String? {
        var c = URLComponents()
        c.queryItems = dict.compactMap {
            if let value = $0.1 {
                return URLQueryItem(name: $0.0, value: "\(value)")
            }
            return nil
        }
        return c.url?.relativeString
    }
    
    typealias MethodBody = (method: String, body: Data?)
    
    func request<T>(_ endpoint: String, methodBody: MethodBody? = nil, completion: @escaping APIRes<T>) {
        if shouldUseMockResponse {
            mockResponse(completion)
            return
        }
        
        if var request = authorizer.authorizedTemplateRequest() {
            if let meth = methodBody {
                request.httpMethod = meth.method
                request.httpBody = meth.body
            }

            request.url = URL(string: endpoint, relativeTo: request.url)
            authorizer.autoAuth(request, completion: errorMiddleware(completion))
        } else {
            completion(.failure(QuestAPIError.missingAuthorizedRequest))
        }
    }
}
