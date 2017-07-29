//
//  FitBitApi.swift
//  Fitbit
//
//  Created by Lett, Jeff on 7/28/17.
//  Copyright © 2017 Jeff Lett. All rights reserved.
//

import Foundation

struct FitBitApiConfig {
    let clientId: String
    let callbackUrl: String
}

public class FitBitApi {
    
    // MARK: - Variables
    
    let config: FitBitApiConfig
    
    // MARK: - Init
    
    init(config: FitBitApiConfig) {
        self.config = config
    }
    
    // MARK: - Public Methods
    
    func login() {
        if let loginUrl = self.authorizeURL(config: self.config) {
            print("Login Url: \(loginUrl.absoluteString)")
        }
    }
    
    func logout() {
        
    }
    
    // MARK: - Private
    
    private func authorizeURL(config: FitBitApiConfig) -> URL? {
        
        var urlComponents = URLComponents()
        
        // scheme
        urlComponents.scheme = "https:"
        
        // host
        urlComponents.host = "www.fitbit.com"
        
        // url
        urlComponents.path = "oauth2/authorize"
        
        // get query params
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "response_type", value: "token"))
        queryItems.append(URLQueryItem(name: "client_id", value: config.clientId))
        urlComponents.queryItems = queryItems
        
        return urlComponents.url
    }
    
}
