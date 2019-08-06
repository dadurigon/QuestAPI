
import Foundation

public typealias APIRes<T> = (Res<T>) -> Void

public enum Res<T> {
    case success(T)
    case failure(Error)
}

public protocol URLRequestCodableDelegate {
    func willMake(request:URLRequest)
    func didMake(request:URLRequest)
}

public protocol URLRequestCodable {
    var encoder: JSONEncoder {get set}
    var decoder: JSONDecoder {get set}
    var session: URLSession {get set}
    var apiDelegate: URLRequestCodableDelegate? {get set}
}

public enum URLRequestCodableError: Error {
    case noDataResponse
}

extension URLRequestCodable {
    
    public func make<T: Decodable>(_ request: URLRequest, completion:@escaping APIRes<T>, shouldWriteResponseToFile:Bool = false) {
        
        self.apiDelegate?.willMake(request: request)

        let task = session.dataTask(with: request) {  data, res, err in
            
            self.apiDelegate?.didMake(request: request)
            
            if let e = err {
                completion(.failure(e))
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
                            if shouldWriteResponseToFile {
                                do {
                                    // let json = try JSONSerialization.jsonObject(with: d)
                                    guard let documentDirectoryUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
                                    let fileUrl = documentDirectoryUrl.appendingPathComponent("\(T.self).json")
                                    try d.write(to: fileUrl)
                                } catch {
                                    completion(.failure(error))
                                }
                            }
                            
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
            
        }
        task.resume()
    }
}
