
import UIKit

class AXLoginViewController: UIViewController {
    
    
    @IBOutlet var facebookButton: UIButton!
    @IBOutlet var googleButton: UIButton!
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var goToLoginButton: UIButton!
    @IBOutlet weak var backgroundContainer: UIView!
    @IBOutlet weak var providerButtonsContainer: UIView!
    @IBOutlet weak var providerButtonsHeightConstraint: NSLayoutConstraint!
    
    var submitTitle: String = ""
    var goToLoginHidden: Bool = false
    
    private var viewLoaded = false
    private var loginUIManager: AXLoginUIManager!
    
    var backgroundView: UIView? {
        willSet {
            backgroundView?.removeFromSuperview()
        }
        didSet {
            ensureViewLoaded()
            if let bg = backgroundView {
                bg.frame = backgroundContainer.bounds
                backgroundContainer.addSubview(bg)
            }
        }
    }
    
    var providers: [String] = [] {
        didSet {
            updateProviderButtons();
        }
    }
    
    var username: String {
        get {
            return usernameTextField.text ?? ""
        }
    }
    var password: String {
        get {
            return passwordTextField.text ?? ""
        }
    }
    
    convenience init(manager: AXLoginUIManager) {
        self.init(nibName: "AXLoginViewController", bundle:Appstax.frameworkBundle())
        self.loginUIManager = manager
    }
    
    override func viewDidLoad() {
        viewLoaded = true
        submitButton.setTitle(submitTitle, forState: .Normal)
        goToLoginButton.hidden = goToLoginHidden
    }
    
    func ensureViewLoaded() {
        _ = self.view
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField === usernameTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            textField.resignFirstResponder()
            pressedSignUpButton(nil)
        }
        return true
    }
    
    @IBAction func pressedSignUpButton(sender: AnyObject?) {
        disableInputs()
        activityIndicator.startAnimating()
        errorLabel.hidden = true
        loginUIManager.viewControllerDidPressSubmitButton(self)
    }
    
    @IBAction func pressedGoToLoginButton(sender: AnyObject?) {
        loginUIManager.viewControllerDidPressGoToLoginButton(self)
    }
    
    func updateProviderButtons() {
        let buttonHeight: CGFloat = 44
        let buttonSpacing: CGFloat = 10
        let buttonWidth = providerButtonsContainer.frame.width
        
        var y = CGFloat(0)
        
        providerButtonsContainer.subviews.forEach({ v in v.removeFromSuperview() })
        providers.enumerate().forEach({
            index, provider in
            
            if let button = buttonForProvider(provider) {
                button.tag = index
                button.frame = CGRect(x: 0, y: y, width: buttonWidth, height: buttonHeight)
                button.removeTarget(nil, action: nil, forControlEvents: .AllEvents)
                button.addTarget(self, action: #selector(AXLoginViewController.didPressProviderButton(_:)), forControlEvents: .TouchUpInside)
                
                providerButtonsContainer.addSubview(button)
                y += buttonHeight + buttonSpacing
            }
        })
        
        providerButtonsHeightConstraint.constant = y
    }
    
    func buttonForProvider(provider: String) -> UIButton? {
        switch(provider) {
            case "facebook": return facebookButton
            case "google":   return googleButton
            default: return nil
        }
    }
    
    func didPressProviderButton(button: UIButton) {
        if providers.count > button.tag {
            let provider = providers[button.tag]
            loginUIManager.viewControllerDidPressProviderButton(self, provider: provider)
        }
    }
    
    func clear() {
        usernameTextField.text = ""
        passwordTextField.text = ""
        errorLabel.text = ""
        activityIndicator.stopAnimating()
        enableInputs()
    }
    
    func showError(errorMessage: String) {
        errorLabel.hidden = false
        errorLabel.text = errorMessage
        enableInputs()
        activityIndicator.stopAnimating()
    }
    
    func disableInputs() {
        self.view.endEditing(true)
        usernameTextField.enabled = false
        passwordTextField.enabled = false
        submitButton.enabled = false
    }
    
    func enableInputs() {
        usernameTextField.enabled = true
        passwordTextField.enabled = true
        submitButton.enabled = true
    }
}
