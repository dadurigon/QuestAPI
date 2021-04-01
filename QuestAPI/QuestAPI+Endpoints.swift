
import Foundation

extension QuestAPI {
    
    public func serverTime(completion: @escaping APIRes<ServerTime>) {
        let endpoint = version + "/time"
        request(endpoint, completion: completion)
    }
    
    
    //MARK: - Account Requests
    
    public func accounts(completion: @escaping APIRes<AccountResponse>) {
        let endpoint = version + "/accounts"
        request(endpoint, completion: completion)
    }
    
    public func positions(for accountNumber: String, completion: @escaping APIRes<PositionResponse>) {
        let endpoint = version + "/accounts/\(accountNumber)/positions"
        request(endpoint, completion: completion)
    }
    
    public func balances(for accountNumber: String, completion: @escaping APIRes<BalanceResponse>) {
        let endpoint = version + "/accounts/\(accountNumber)/balances"
        request(endpoint, completion: completion)
    }
    
    public func orders(req: OrderRequest, completion: @escaping APIRes<OrderResponse>) {
        var endpoint = version + "/accounts/\(req.accountNumber)/orders"
        endpoint += queryString([
            "startTime" : dateFormatter.string(from: req.dateInterval.start),
            "endTime": dateFormatter.string(from: req.dateInterval.end),
            "stateFilter": req.stateFilter?.rawValue,
            "orderId": req.orderId
        ])!
        request(endpoint, completion: completion)
    }
    
    public func postOrder(req: PostOrderRequest, completion: @escaping APIRes<OrderResponse>) {
        let endpoint = version + "/accounts/\(req.accountNumber)/orders"
        let data = try? authorizer.encoder.encode(req)
        request(endpoint, methodBody:("POST", data), completion: completion)
    }
    
    public func postOrderImpact(req: PostOrderRequest, completion: @escaping APIRes<OrderImpact>) {
        let endpoint = version + "/accounts/\(req.accountNumber)/orders/impact"
        let data = try? authorizer.encoder.encode(req)
        request(endpoint, methodBody:("POST", data), completion: completion)
    }
    
    public func activities(for accountNumber: String, completion: @escaping APIRes<ActivityResponse>) {
        var endpoint = version + "/accounts/\(accountNumber)/activities"
        
        // Maximum 31 days of data can be requested at a time.
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        endpoint += queryString([
            "startTime" : "\(dateFormatter.string(from: startDate))",
            "endTime": "\(dateFormatter.string(from: now))",
        ])!
        request(endpoint, completion: completion)
    }
    
    public func executions(req: ExecutionRequest, completion: @escaping APIRes<ExecutionResponse>) {
        var endpoint = version + "/accounts/\(req.accountNumber)/executions"
        endpoint += queryString([
            "startTime": dateFormatter.string(from: req.dateInterval.start),
            "endTime": dateFormatter.string(from: req.dateInterval.end)
        ])!
        request(endpoint, completion: completion)
    }
    
    
    //MARK: - Market Requests
    
    public func markets(completion: @escaping APIRes<MarketResponse>) {
        let endpoint = version + "/markets"
        request(endpoint, completion: completion)
    }
    
    public func quotes(for symbolID: Int, completion: @escaping APIRes<QuoteResponse>) {
        let endpoint = version + "/markets/quotes/\(symbolID)"
        request(endpoint, completion: completion)
    }
    
    public func optionQuotes(req: OptionRequest, completion: @escaping APIRes<OptionQuoteResponse>) {
        let endpoint = version + "/markets/quotes/options"
        request(endpoint, completion: completion)
    }
    
    public func strategies(req: StrategyVariantRequest, completion: @escaping APIRes<StrategyQuoteResponse>) {
        let endpoint = version + "/markets/quotes/strategies"
        request(endpoint, completion: completion)
    }
    
    public func candles(req: CandleRequest , completion: @escaping APIRes<CandleResponse>) {
        var endpoint = version + "/markets/candles/\(req.symbolID)"
        endpoint += queryString([
            "interval" : req.interval.rawValue,
            "startTime": dateFormatter.string(from: req.dateInterval.start),
            "endTime"  : dateFormatter.string(from: req.dateInterval.end)
        ])!
        request(endpoint, completion: completion)
    }
    
    
    //MARK: - Symbol Requests
    
    public func symbols(for symbolID: Int, completion: @escaping APIRes<SymbolResponse>) {
        let endpoint = version + "/symbols/\(symbolID)"
        request(endpoint, completion: completion)
    }
    
    public func options(for symbolID: Int, completion: @escaping APIRes<OptionResponse>) {
        let endpoint = version + "/markets/symbols/\(symbolID)/options"
        request(endpoint, completion: completion)
    }
    
    public func search(req: SearchRequest, completion: @escaping APIRes<SearchResponse>) {
        var endpoint = version + "/symbols/search"
        endpoint += queryString([
            "prefix" : req.prefix,
            "offset": req.offset,
        ])!
        request(endpoint, completion: completion)
    }
}
