
import UIKit

class AXLoginViewController: UIViewController {
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var goToLoginButton: UIButton!
    @IBOutlet weak var backgroundContainer: UIView!
    
    var submitTitle: String = ""
    var goToLoginHidden: Bool = false
    
    private var viewLoaded = false
    private var loginUIManager: AXLoginUIManager!
    
    var backgroundView: UIView? {
        willSet {
            backgroundView?.removeFromSuperview()
        }
        didSet {
            if viewLoaded {
                if let bg = backgroundView {
                    bg.frame = backgroundContainer.bounds
                    backgroundContainer.addSubview(bg)
                }
            }
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
