
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
    case noDataResponse
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
            
            if let res = res {
                let r = res as? HTTPURLResponse
                if let code = r?.statusCode {
                    if code != 200 {
                        // somthing went wrong
                        let domain = HTTPURLResponse.localizedString(forStatusCode: code)
                        let error = NSError(domain: domain, code: code, userInfo: r?.allHeaderFields as? [String:Any])
                        completion(.failure(error))
                    } else {
                        // everthing went fine
                        if let d = data {
                            if T.self == Data.self {
                                completion(.success(d as! T))
                            } else {
                                do {
                                    let _d = try self.decoder.decode(T.self, from: d)
                                    completion(.success(_d))
                                } catch let error {
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            completion(.failure(URLRequestCodableError.noDataResponse))
                        }
                    }
                }
            }
            
        }.resume()
    }
}
