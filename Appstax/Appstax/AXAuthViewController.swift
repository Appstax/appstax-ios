
import Foundation

struct AXAuthResult {
    var redirectUri: String
    var authCode: String?
    var error: String?
}

class AXAuthViewController: UIViewController, UIWebViewDelegate {
    
    @IBOutlet weak var webView: UIWebView!
    
    private var running = false
    private var result: AXAuthResult?
    private var completion: ((AXAuthResult?, NSError?) -> ())?
    
    convenience init() {
        self.init(nibName: "AXAuthViewController", bundle: Appstax.frameworkBundle())
    }

    override func viewDidLoad() {
        webView.delegate = self
    }
    
    func ensureViewLoaded() {
        _ = self.view
    }
    
    func runOAuth(uri uri:String, redirectUri: String, clientId: String, completion: (AXAuthResult?, NSError?) -> ()) {
        AXLog.debug("AXAuthViewController.runOAuth")
        if(running) {
            return
        }
        running = true
        
        self.completion = completion
        ensureViewLoaded()
        
        let uri = uri
                    .stringByReplacingOccurrencesOfString("{redirectUri}", withString: AXApiClient.urlEncode(redirectUri))
                    .stringByReplacingOccurrencesOfString("{clientId}", withString: clientId)
                    .stringByReplacingOccurrencesOfString("{nonce}", withString: generateNonce())
        
        AXLog.debug("Opening auth: \(uri)")
        
        result = AXAuthResult(redirectUri: redirectUri, authCode: "", error: nil)
        webView.loadRequest(NSURLRequest(URL: NSURL(string: uri)!))
    }
    
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        let url = request.URL?.absoluteString ?? ""
        AXLog.debug("Auth WebView loading url: \(url)")
        if url.hasPrefix(result!.redirectUri) {
            handleRedirect(url)
            return false
        }
        return true
    }
    
    func handleRedirect(url: String) {
        NSURLComponents(string: url)?.queryItems?.forEach() {
            item in
            switch item.name {
                case "code": result?.authCode = item.value ?? ""
                case "error_description": result?.error = item.value
                default: break
            }
        }
        completed()
    }
    
    @IBAction func handleCloseTapped(sender: AnyObject) {
        result?.error = "Authentication cancelled"
        completed()
    }
    
    func completed() {
        if(running) {
            if let error = result?.error {
                completion?(nil, NSError(domain: "AXAuthViewController", code: 0, userInfo: ["errorMessage": error]))
            } else {
                completion?(result, nil)
            }
        }
        running = false
        completion = nil
        result = nil
    }
    
    func generateNonce() -> String {
        return NSUUID().UUIDString.stringByReplacingOccurrencesOfString("-", withString: "")
    }
    
    deinit {
        if webView != nil {
            webView.delegate = nil
        }
    }

}
