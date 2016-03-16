
import Foundation
import XCTest
@testable import Appstax

@objc class SocialLoginFacebookTest: XCTestCase {
    
    let timeout: NSTimeInterval = 5;
    var requestedAuthUrl: String?
    var redirectToUrl: String?
    var providerConfigError: String?
    var clientId: String = ""
    var sessionPostBody: [String:AnyObject]?
    var sessionPostResponse: [String:AnyObject]?
    var sessionPostError: String?
    var keychain: AXKeychain?
    
    override func setUp() {
        super.setUp()
        OHHTTPStubs.setEnabled(true)
        OHHTTPStubs.removeAllStubs()
        Appstax.setAppKey("testappkey", baseUrl:"http://localhost:3000/");
        Appstax.setLogLevel("debug");

        keychain = Appstax.defaultContext.userService.keychain
        keychain?.clear()
        
        requestedAuthUrl = nil
        redirectToUrl = nil
        clientId = ""
        sessionPostBody = nil
        sessionPostResponse = nil
        sessionPostError = nil
        providerConfigError = nil
        
        AXStubs.method("GET", urlPath: "/sessions/providers/facebook") { _ in
            if let error = self.providerConfigError {
                return OHHTTPStubsResponse(JSONObject: ["errorMessage": error], statusCode: 422, headers: [:])
            } else {
                return OHHTTPStubsResponse(JSONObject: ["clientId": self.clientId], statusCode: 200, headers: [:])
            }
        }
        
        redirectToUrl = "https://appstax.com/api/latest/sessions/auth?code=foobar"
        OHHTTPStubs.stubRequestsPassingTest({
                request in
                return request.URL?.host == "www.facebook.com"
            }, withStubResponse: {
                request in
                self.requestedAuthUrl = request.URL?.absoluteString
                if let redirect = self.redirectToUrl {
                    return OHHTTPStubsResponse(data: NSData(), statusCode: 301, headers: ["Location":redirect])
                }
                return nil
        })
        
        AXStubs.method("POST", urlPath: "/sessions") {
            request in
            let httpBody = NSURLProtocol.propertyForKey("HTTPBody", inRequest: request) as! NSData
            self.sessionPostBody = try? NSJSONSerialization.JSONObjectWithData(httpBody, options: NSJSONReadingOptions(rawValue: 0)) as! [String:AnyObject]
            if let error = self.sessionPostError {
                return OHHTTPStubsResponse(JSONObject: ["errorMessage": error], statusCode: 422, headers: [:])
            } else {
                return OHHTTPStubsResponse(JSONObject: self.sessionPostResponse ?? [:], statusCode: 200, headers: [:])
            }
        }
    }
    
    override func tearDown() {
        super.tearDown()
        OHHTTPStubs.setEnabled(false)
    }
    
    func testShoulBeAbleToMockWebViewRedirect() {
        let async = expectationWithDescription("async")
        AXStubs.method("GET", urlString: "http://example.com/") { _ in
            return OHHTTPStubsResponse(data: NSData(), statusCode: 301, headers: ["Location":"http://www.bing.com/search?q=google"])
        }
        
        let webView = UIWebView()
        webView.loadRequest(NSURLRequest(URL: NSURL(string: "http://example.com/")!))
        
        delay(timeout) { async.fulfill() }
        waitForExpectationsWithTimeout(timeout + 1) { error in
            let content = webView.stringByEvaluatingJavaScriptFromString("document.documentElement.outerHTML");
            let url = webView.stringByEvaluatingJavaScriptFromString("window.location.href");
            let queryString = webView.stringByEvaluatingJavaScriptFromString("window.location.search");
            AXAssertStringContains(content, needle: "google");
            AXAssertStringContains(url, needle: "bing.com");
            AXAssertStringContains(queryString, needle: "q=google")
        }
    }
    
    func testShouldOpenFacebookAuthPage() {
        let async = expectationWithDescription("async")

        AXUser.login(provider: "facebook", fromViewController: nil) { _ in
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(timeout + 1) { error in
            AXAssertStringContains(self.requestedAuthUrl, needle: "facebook.com/dialog/oauth")
        }
    }
    
    func testShouldUseAppstaxRedirecUri() {
        let async = expectationWithDescription("async")
        
        AXUser.login(provider: "facebook", fromViewController: nil) { _ in
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(timeout + 1) { error in
            let encodedRedirectUri = "https%3A%2F%2Fappstax.com%2Fapi%2Flatest%2Fsessions%2Fauth"
            AXAssertStringContains(self.requestedAuthUrl, needle: "redirect_uri=" + encodedRedirectUri)
        }
    }
    
    func testShouldUseClientIdFromProviderConfig() {
        let async = expectationWithDescription("async")
        
        clientId = "the-client-id-1234"
        AXUser.login(provider: "facebook", fromViewController: nil) { _ in
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(timeout) { error in
            AXAssertStringContains(self.requestedAuthUrl, needle: "client_id=the-client-id-1234")
        }
    }
    
    func testShouldSendAuthCodeAndRedirectUriFromDialogToServer() {
        let async = expectationWithDescription("async")
        
        redirectToUrl = "https://appstax.com/api/latest/sessions/auth?code=the-auth-code-2345"
        AXUser.login(provider: "facebook", fromViewController: nil) { _ in
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(timeout + 1) { error in
            let provider = self.sessionPostBody?["sysProvider"] as? [String:AnyObject]
            let providerData = provider?["data"]
            AXAssertEqual(provider?["type"], "facebook")
            AXAssertEqual(providerData?["code"], "the-auth-code-2345")
            AXAssertEqual(providerData?["redirectUri"], "https://appstax.com/api/latest/sessions/auth")
        }
    }
    
    func testShouldReturnUserAndSessionWhenLoginIsSuccessful() {
        let async = expectationWithDescription("async")
        
        sessionPostResponse = ["sysSessionId": "the-session-id-9876", "user": ["sysObjectId": "the-user-id-4123", "sysUsername": "theusername"]]
        
        var user: AXUser?
        var error: NSError?
        AXUser.login(provider: "facebook", fromViewController: nil) {
            user = $0; error = $1;
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(timeout + 1) { _ in
            AXAssertNil(error)
            
            AXAssertNotNil(user)
            AXAssertEqual(user?.username, "theusername")
            AXAssertEqual(user?.objectID, "the-user-id-4123")
            AXAssertEqual(user, AXUser.currentUser())
            AXAssertEqual(Appstax.defaultContext.apiClient.sessionID, "the-session-id-9876")
            
            AXAssertEqual(self.keychain?.objectForKeyedSubscript("SessionID"), "the-session-id-9876")
            AXAssertEqual(self.keychain?.objectForKeyedSubscript("Username"), "theusername")
            AXAssertEqual(self.keychain?.objectForKeyedSubscript("UserObjectID"), "the-user-id-4123")
        }
    }
    
    func testShouldFailIfProviderConfigFails() {
        let async = expectationWithDescription("async")
        
        providerConfigError = "This config is not the config you are looking for"
        
        var user: AXUser?
        var error: NSError?
        AXUser.login(provider: "facebook", fromViewController: nil) {
            user = $0; error = $1;
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(timeout + 1) { _ in
            AXAssertNotNil(error)
            AXAssertEqual(error?.userInfo["errorMessage"], "This config is not the config you are looking for")
            AXAssertNil(user)
            AXAssertNil(AXUser.currentUser())
        }
    }
    
    func testShouldFailIfAuthDialogFails() {
        let async = expectationWithDescription("async")
        
        redirectToUrl = "https://appstax.com/api/latest/sessions/auth?error_description=The%20user%20denied%20your%20request"
        
        var user: AXUser?
        var error: NSError?
        AXUser.login(provider: "facebook", fromViewController: nil) {
            user = $0; error = $1;
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(timeout + 1) { _ in
            AXAssertNotNil(error)
            AXAssertEqual(error?.userInfo["errorMessage"], "The user denied your request")
            AXAssertNil(user)
            AXAssertNil(AXUser.currentUser())
        }
    }
    
    func testShouldFailIfSessionPostFails() {
        let async = expectationWithDescription("async")
        
        sessionPostError = "Something terrible happened just now"
        
        var user: AXUser?
        var error: NSError?
        AXUser.login(provider: "facebook", fromViewController: nil) {
            user = $0; error = $1;
            async.fulfill()
        }
        
        waitForExpectationsWithTimeout(timeout + 1) { _ in
            AXAssertNotNil(error)
            AXAssertEqual(error?.userInfo["errorMessage"], "Something terrible happened just now")
            AXAssertNil(user)
            AXAssertNil(AXUser.currentUser())
        }
    }
    
    
    
}