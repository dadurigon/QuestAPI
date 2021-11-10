
import Foundation

public typealias APIRes<T: Decodable> = (Result<T, Swift.Error>) -> Void

public protocol URLRequestCodableDelegate {
    func willMake(request: URLRequest)
    func didMake(request: URLRequest)
}

public protocol URLRequestCodable {
    var encoder: JSONEncoder {get set}
    var decoder: JSONDecoder {get set}
    var session: URLSession {get set}
    var requestDelegate: URLRequestCodableDelegate? {get set}
}

public enum URLRequestCodableError: Error {
    case noData, noResponse
}

extension URLRequestCodable {
    
    public func make<T>(_ request: URLRequest, completion: @escaping APIRes<T>) {
        
        requestDelegate?.willMake(request: request)

        session.dataTask(with: request) {  data, res, err in
            
            self.requestDelegate?.didMake(request: request)
            
            if let e = err {
                completion(.failure(e))
                return
            }
            
            guard let data = data else {
                completion(.failure(URLRequestCodableError.noData))
                return
            }
            
            guard let res = res as? HTTPURLResponse else {
                completion(.failure(URLRequestCodableError.noResponse))
                return
            }

            if res.statusCode != 200 {
                let domain = HTTPURLResponse.localizedString(forStatusCode: res.statusCode)
                let error = NSError(domain: domain, code: res.statusCode, userInfo: res.allHeaderFields as? [String:Any])
                completion(.failure(error))
            } else {
                if T.self == Data.self {
                    completion(.success(data as! T))
                } else {
                    do {
                        let decoded = try self.decoder.decode(T.self, from: data)
                        completion(.success(decoded))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
}
