//
//  LoginViewController.swift
//  Messenger
//
//  Created by Muhammad Vicky on 19/09/22.
//

import UIKit
import FirebaseAuth
import FacebookLogin
import FacebookCore


class LoginViewController: UIViewController {
    
    private let imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let scrollView : UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let emailField : UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Address..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        return field
    }()
    
    private let passwordField : UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        field.isSecureTextEntry = true
        return field
    }()
    
    private let loginButton : UIButton = {
        let button = UIButton()
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let fbLoginButton : FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["public_profile", "email"]
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Log In"
        view.backgroundColor = .white
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register", style: .done, target: self, action: #selector(didTapRegister))
        
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        
        emailField.delegate = self
        passwordField.delegate = self
        fbLoginButton.delegate = self
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        
        
        fbLoginButton.center = view.center
        scrollView.addSubview(fbLoginButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width/3
        
        imageView.frame = CGRect(x: (scrollView.width - size)/2, y: 20, width: size, height: size)
        emailField.frame = CGRect(x: 30, y: imageView.bottom + 10, width: scrollView.width - 60, height: 52)
        passwordField.frame = CGRect(x: 30, y: emailField.bottom + 10, width: scrollView.width - 60, height: 52)
        loginButton.frame = CGRect(x: 30, y: passwordField.bottom + 10, width: scrollView.width - 60, height: 52)
        fbLoginButton.center = scrollView.center
        fbLoginButton.frame.origin.y = loginButton.bottom + 20
    }
    
    @objc private func loginButtonTapped(){
        
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text, let password = passwordField.text,
              !email.isEmpty, !password.isEmpty, password.count >= 6 else{
            alertUserLoginError()
            return
        }
        //Firebase Log In
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: {
            [weak self] authDataResult, error in
            guard let strongSelf = self else{
                return
            }
            guard let result = authDataResult, error == nil else{
                print("failed to log in with email \(email)")
                return
            }
            let user = result.user
            print("user successfully logged in with user \(user)")
            strongSelf.navigationController?.dismiss(animated: true)
        })
    }
    
    func alertUserLoginError(){
        let alert = UIAlertController(title: "Whoops", message: "Please enter all information to log in.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    
    @objc private func didTapRegister(){
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
}


extension LoginViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField : UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField{
            loginButtonTapped()
        }
        return true
    }
}

extension LoginViewController : LoginButtonDelegate{
    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        //no operation
    }
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else {
            print("user failed login with facebook")
            return
        }
        
        
        let fbRequest = GraphRequest(graphPath: "me", parameters: ["fields":"email, name"], tokenString: token, version: nil, httpMethod: .get)
        
        fbRequest.start(completionHandler: {
            connect, result, error in
            guard let result = result as? [String : Any], error == nil else{
                print("failed to make facebook graph request")
                return
            }
        
            print(result)
            guard let userName = result["name"] as? String,
                  let email = result["email"] as? String else{
                print("failed to get email and name from fb result")
                return
            }
            
            let nameComponents = userName.components(separatedBy: " ")
            guard nameComponents.count >= 2 else{
                return
            }
            
            let firstName = nameComponents[0]
            let lastName = nameComponents[1]
            
            DatabaseManager.shared.userExists(with: email, completion: {
                exist in
                if !exist {
                    DatabaseManager.shared.insertUser(with: ChatAppUser(firstName: firstName, lastName: lastName, emailAdress: email))
                }
            })
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            FirebaseAuth.Auth.auth().signIn(with: credential, completion: {
                [weak self] authResult, error in
                guard let strongSelf = self else{
                    return
                }
                guard authResult != nil, error == nil else{
                    if let error = error {
                        print("Facebook credential login failed - \(error)")
                    }
                    return
                }
                print("Login successful")
                strongSelf.navigationController?.dismiss(animated: true)
            })
        })
    }
}
