//
//  FitBitApi.swift
//  Fitbit
//
//  Created by Lett, Jeff on 7/28/17.
//  Copyright © 2017 Jeff Lett. All rights reserved.
//

import Foundation
import SafariServices

public enum Scope: String {
    case nutrition
    case activity
}

public struct FitBitApiConfig {
    let clientId: String
    let callbackUrl: String
    let scopes: [Scope]
    
    public init(clientId: String, callbackUrl: String, scopes: [Scope]) {
        self.clientId = clientId
        self.callbackUrl = callbackUrl
        self.scopes = scopes
    }
}

public enum MealType: Int {
    case breakfast = 1
    case morningSnack = 2
    case lunch = 3
    case afternoonSnack = 4
    case dinner = 5
    case anytime = 7
}

public struct FoodItem {
    var id: String?
    var foodName: String?
    let mealType: MealType
    let unit: Int
    let amount: Float
    let date: Date
    var calories: Int?
    
    public init(id: String, mealType: MealType, unit: Int, amount: Float, date: Date = Date()) {
        self.id = id
        self.mealType = mealType
        self.unit = unit
        self.amount = amount
        self.date = date
    }
    
    public init(name: String, mealType: MealType, unit: Int, amount: Float, calories: Int, date: Date = Date()) {
        self.foodName = name
        self.mealType = mealType
        self.unit = unit
        self.amount = amount
        self.date = date
        self.calories = calories
    }
}

extension UserDefaults {
    var fitBitToken: String? {
        get { return value(forKeyPath: #function) as? String }
        set { setValue(newValue, forKeyPath: #function)}
    }
    var fitBitUserId: String? {
        get { return value(forKey: #function) as? String }
        set { setValue(newValue, forKey: #function) }
    }
}

public class FitBitApi {
    
    public enum Notifications: String {
        case loggedIn
        case loggedOut
    }
    
    public enum FitBitApiError: Error {
        case noData
        case unableToParse
        case notLoggedIn
        case invalidUrl
    }
    
    
    // MARK: - Variables
    
    public let config: FitBitApiConfig
    
    // MARK: - Init
    
    public init(config: FitBitApiConfig) {
        self.config = config
        if let _ = token() {
            recreateSession()
        }
    }
    
    // MARK: - Public Methods
    
    public func isLoggedIn() -> Bool {
        return token() != nil && userId() != nil
    }
    
    public func login(from: UIViewController) {
        if let url = self.authorizeURL(config: self.config) {
            let webview = SFSafariViewController(url: url)
            print("using \(url.absoluteString)")
            from.present(webview, animated: true, completion: nil)
        } else {
            print("No Login URL!")
        }
    }
    
    public func logout() {
        UserDefaults.standard.fitBitToken = nil
        UserDefaults.standard.fitBitUserId = nil
        NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.loggedOut.rawValue), object: nil)
    }
    
    public func getFoodLogs(completionHandler: @escaping ([String: Any]) -> Void, errorHandler: @escaping (Error) -> Void) {
        let url = getFoodLogsURL(config: self.config)
        makeApiCall(url: url, completionHandler: completionHandler, errorHandler: errorHandler)
    }
    
    public func getDailyActivity(completionHandler: @escaping ([String: Any]) -> Void, errorHandler: @escaping (Error) -> Void) {
        let url = getDailyActivityURL(config: self.config)
        makeApiCall(url: url, completionHandler: completionHandler, errorHandler: errorHandler)
    }
    
    public func postFoodLogs(foodItem: FoodItem, completionHandler: @escaping ([String: Any]) -> Void, errorHandler: @escaping (Error) -> Void) {
        var parameters = [String: Any]()
        parameters["foodId"] = foodItem.id
        parameters["foodName"] = foodItem.foodName
        parameters["amount"] = foodItem.amount
        parameters["mealTypeId"] = foodItem.mealType.rawValue
        parameters["unitId"] = foodItem.unit
        parameters["date"] = dateFormatter.string(from: foodItem.date)
        parameters["calories"] = foodItem.calories
        
        let url = postFoodLogsURL(config: self.config)
        var urlRequest = URLRequest(url: url!)
        urlRequest.httpMethod = "POST"
        
        let body = parameters.map({
            return "\($0.0)=\($0.1)"
        }).joined(separator: "&")
        urlRequest.httpBody = body.data(using: .utf8)
        
        guard let urlSession = urlSession else {
            errorHandler(FitBitApiError.notLoggedIn)
            return
        }
        
        urlSession.dataTask(with: urlRequest) { (data, response, error) in
            if let error = error {
                errorHandler(error)
            } else if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []),
                    let jsonDictionary = json as? [String: Any] {
                    completionHandler(jsonDictionary)
                } else {
                    errorHandler(FitBitApiError.unableToParse)
                }
            } else {
                errorHandler(FitBitApiError.noData)
            }
        }.resume()
    }
    
    public func handle(url: URL) {
        let tokenOpt = getValue(key: "access_token", url: url)
        let userIdOpt = getValue(key: "user_id", url: url)
        
        guard let token = tokenOpt else {
            print("No Token found!")
            return
        }
        
        guard let userId = userIdOpt else {
            print("No userId found!")
            return
        }
        
        print("token found! \(token)")
        UserDefaults.standard.fitBitToken = token
        recreateSession()
        print("userId found: \(userId)")
        UserDefaults.standard.fitBitUserId = userId
        NotificationCenter.default.post(name: Notification.Name(rawValue: Notifications.loggedIn.rawValue), object: nil)
    }
    
    
    
    // MARK: - Private
    
    private var urlSession: URLSession?
    
    // this needs to be called whenever the user logs in again to get the new token for headers
    private func recreateSession() {
        urlSession = createSession()
    }
    
    private func createSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        var headers = configuration.httpAdditionalHeaders ?? [:]
        headers["Authorization"] = "Bearer \(token() ?? "")"
        configuration.httpAdditionalHeaders = headers
        let urlSession = URLSession(configuration: configuration)
        return urlSession
    }
    
    private func token() -> String? {
        return UserDefaults.standard.fitBitToken
    }
    
    private func userId() -> String? {
        return UserDefaults.standard.fitBitUserId
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private func makeApiCall(url: URL?, completionHandler: @escaping ([String: Any]) -> Void, errorHandler: @escaping (Error) -> Void) {
        guard let urlSession = urlSession else {
            print("No urlsession!")
            errorHandler(FitBitApiError.notLoggedIn)
            return
        }
        
        guard let url = url else {
            print("Invalid URL.")
            errorHandler(FitBitApiError.invalidUrl)
            return
        }
        
        print("url: \(url.absoluteString)")
        
        urlSession.dataTask(with: url) { (data, response, error) in
            if let error = error {
                errorHandler(error)
            } else if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []),
                    let jsonDictionary = json as? [String: Any] {
                    completionHandler(jsonDictionary)
                } else {
                    errorHandler(FitBitApiError.unableToParse)
                }
            } else {
                errorHandler(FitBitApiError.noData)
            }
        }.resume()
    }
   
    private func getValue(key: String, url: URL) -> String? {
        guard let urlComponents = URLComponents(string: url.absoluteString) else {
            print("There was a problem getting the components from url: \(url.absoluteString)")
            return nil
        }
        
        let components = urlComponents.fragment?.components(separatedBy: "&")
        let filteredComponents = components?.filter { return $0.contains(key) }
        let comps = filteredComponents?.first?.components(separatedBy: "=") ?? []
        
        guard comps.count > 1 else {
            print("no value found for key: \(key). \(url.absoluteString)")
            return nil
        }
        
        return comps[1]
    }
    
    private func authorizeURL(config: FitBitApiConfig) -> URL? {
        
        var urlComponents = URLComponents()
        // scheme
        urlComponents.scheme = "https"
        
        // host
        urlComponents.host = "www.fitbit.com"
        
        // url
        urlComponents.path = "/oauth2/authorize"
        
        // get query params
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "response_type", value: "token"))
        queryItems.append(URLQueryItem(name: "client_id", value: config.clientId))
        queryItems.append(URLQueryItem(name: "redirect_uri", value: config.callbackUrl.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)))
        queryItems.append(URLQueryItem(name: "scope", value: config.scopes.map { return $0.rawValue }.joined(separator: " ")))
        queryItems.append(URLQueryItem(name: "expires_in", value: "31536000"))
        urlComponents.queryItems = queryItems
        
        return urlComponents.url
    }
    
    
    private func getFoodLogsURL(config: FitBitApiConfig) -> URL? {
        
        guard let userId = userId() else {
            print("No UserId found for get food logs.")
            return nil
        }
        
        let formattedDate = dateFormatter.string(from: Date())
        
        var urlComponents = getBaseURLComponents()
        
        urlComponents.path = "/1/user/\(userId)/foods/log/date/\(formattedDate).json"
        
        return urlComponents.url
    }
    
    private func postFoodLogsURL(config: FitBitApiConfig) -> URL? {
        //https://api.fitbit.com/1/user/[user-id]/foods/log.json
        
        var urlComponents = getBaseURLComponents()
        
        urlComponents.path = "/1/user/-/foods/log.json"
        
        return urlComponents.url
        
    }
    
    private func getDailyActivityURL(config: FitBitApiConfig) -> URL? {
        
        guard let userId = userId() else {
            print("No UserId found for get daily activity.")
            return nil
        }
        
        let formattedDate = dateFormatter.string(from: Date())
        
        var urlComponents = getBaseURLComponents()
        
        urlComponents.path = "/1/user/\(userId)/activities/date/\(formattedDate).json"
        
        return urlComponents.url
        
    }
    
    private func getBaseURLComponents() -> URLComponents {
        var urlComponents = URLComponents()
        
        // scheme
        urlComponents.scheme = "https"
        
        // host
        urlComponents.host = "api.fitbit.com"

        return urlComponents
    }
    
}
