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
import GoogleSignIn
import JGProgressHUD


class LoginViewController: UIViewController {
    
    private let signInConfig = GIDConfiguration(clientID: "191864337865-r1ljgk7m0kmh3lnqp3dcvb32pc81plu7.apps.googleusercontent.com")
    
    private let spinner = JGProgressHUD(style: .dark)
    
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
        field.backgroundColor = .secondarySystemBackground
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
        field.backgroundColor = .secondarySystemBackground
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
        //        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let googleLoginButton : GIDSignInButton = {
        let button = GIDSignInButton()
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        return button
    }()
    
    private var loginObserver : NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLoginNotification, object: nil, queue: .main, using: {[weak self] _ in
            guard let strongSelf = self else{
                return
            }
            strongSelf.navigationController?.dismiss(animated: true)
        })
        
        title = "Log In"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register", style: .done, target: self, action: #selector(didTapRegister))
        
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        googleLoginButton.addTarget(self, action: #selector(googleLoginButtonTapped), for: .touchUpInside)
        
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
        scrollView.addSubview(googleLoginButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width/3
        
        imageView.frame = CGRect(x: (scrollView.width - size)/2, y: 20, width: size, height: size)
        emailField.frame = CGRect(x: 30, y: imageView.bottom + 10, width: scrollView.width - 60, height: 52)
        passwordField.frame = CGRect(x: 30, y: emailField.bottom + 10, width: scrollView.width - 60, height: 52)
        loginButton.frame = CGRect(x: 30, y: passwordField.bottom + 10, width: scrollView.width - 60, height: 52)
        googleLoginButton.frame = CGRect(x: 30, y: loginButton.bottom + 10, width: scrollView.width - 60, height: 52)
        fbLoginButton.frame = CGRect(x: 30, y: googleLoginButton.bottom + 10, width: scrollView.width - 60, height: 52)
    }
    
    @objc private func googleLoginButtonTapped(_ sender : Any){
        GIDSignIn.sharedInstance.signIn(with: signInConfig, presenting: self){
            user, error in
            guard let user = user, error == nil else{
                return
            }
            
            guard let email = user.profile?.email,
                  let firstName = user.profile?.givenName else{
                print("failed to get email and name from google result")
                return
            }
            
            let lastName = user.profile?.familyName
            
            UserDefaults.standard.set(email, forKey: "email")
            if lastName == nil{
                UserDefaults.standard.set("\(firstName)", forKey: "name")
            } else{
                guard let lastName = lastName else{
                    return
                }
                UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
            }
            
            DatabaseManager.shared.userExists(with: email, completion: {
                exist in
                print("exist = \(exist)")
                if !exist {
                    let chatUser = ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email)
                    DatabaseManager.shared.insertUser(with: chatUser, completion: {
                        success in
                        if success{
                            //upload image
                            guard let isImageExist = user.profile?.hasImage else{
                                return
                            }
                            if isImageExist{
                                guard let url = user.profile?.imageURL(withDimension: 200) else{
                                    return
                                }
                                
                                URLSession.shared.dataTask(with: url, completionHandler: {
                                    data,_,_ in
                                    guard let data = data else{
                                        return
                                    }
                                    let fileName = chatUser.profilePictureFileName
                                    StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName, completion: {
                                        result in
                                        switch result{
                                        case .success(let downloadURL):
                                            UserDefaults.standard.set(downloadURL, forKey: "profile_picture_url")
                                            print(downloadURL)
                                        case.failure(let error):print("storage manager error \(error)")
                                        }
                                    })
                                }).resume()
                            }
                        }
                    })
                }
            })
            let accessToken = user.authentication.accessToken
            guard let idToken = user.authentication.idToken else {
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            FirebaseAuth.Auth.auth().signIn(with: credential, completion: {
                [weak self] authResult, error in
                guard let strongSelf = self else{
                    return
                }
                guard authResult != nil, error == nil else{
                    if let error = error {
                        print("Google credential login failed - \(error)")
                    }
                    return
                }
                print("Login successful")
                strongSelf.navigationController?.dismiss(animated: true)
            })
        }
    }
    
    @objc private func loginButtonTapped(){
        
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text, let password = passwordField.text,
              !email.isEmpty, !password.isEmpty, password.count >= 6 else{
            alertUserLoginError()
            return
        }
        
        spinner.show(in: view)
        
        //Firebase Log In
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: {
            [weak self] authDataResult, error in
            guard let strongSelf = self else{
                return
            }
            
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss(animated: true)
            }
            
            guard let result = authDataResult, error == nil else{
                print("failed to log in with email \(email)")
                return
            }
            
            let user = result.user
            
            let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
            DatabaseManager.shared.getDataFor(path: safeEmail, completion: { [weak self] result in
                switch result{
                case .success(let data):
                    guard let userData = data as? [String : Any],
                          let firstName = userData["first_name"] as? String,
                          let lastName = userData["last_name"] as? String else{
                        return
                    }
                    if lastName.isEmpty{
                        UserDefaults.standard.setValue("\(firstName)", forKey: "name")
                    } else{
                        UserDefaults.standard.setValue("\(firstName) \(lastName)", forKey: "name")
                    }
                    NotificationCenter.default.post(name: .didLoginNotification, object: nil)
                case.failure(let error):
                    print("failed to read data from database with error \(error)")
                }
            })
            
            UserDefaults.standard.setValue(email, forKey: "email")
            
            
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
        
        
        let fbRequest = GraphRequest(graphPath: "me", parameters: ["fields":"email, first_name, last_name, picture.type(large)"], tokenString: token, version: nil, httpMethod: .get)
        
        fbRequest.start(completionHandler: {
            connect, result, error in
            guard let result = result as? [String : Any], error == nil else{
                print("failed to make facebook graph request")
                return
            }
            
            guard let firstName = result["first_name"] as? String,
                  let email = result["email"] as? String,
                  let picture = result["picture"] as? [String : Any],
                  let data = picture["data"] as? [String : Any],
                  let pictureUrl = data["url"] as? String else{
                print("failed to get email and name from fb result")
                return
            }
            
            let lastName = result["last_name"] as? String
            
            UserDefaults.standard.set(email, forKey: "email")
            if lastName == nil{
                UserDefaults.standard.set("\(firstName)", forKey: "name")
            } else{
                guard let lastName = lastName else{
                    return
                }
                UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
            }
            
            DatabaseManager.shared.userExists(with: email, completion: {
                exist in
                let chatUser = ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email)
                if !exist {
                    DatabaseManager.shared.insertUser(with: chatUser, completion: {
                        success in
                        if success{
                            //Upload image
                            guard let url = URL(string: pictureUrl) else{
                                return
                            }
                            
                            print("downloading data from facebook image")
                            
                            URLSession.shared.dataTask(with: url, completionHandler: {
                                data, _, _ in
                                guard let data = data else {
                                    print("failed to get data from facebook")
                                    return
                                }
                                
                                print("got data from fb, uploading...")
                                
                                let fileName = chatUser.profilePictureFileName
                                StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName, completion: {
                                    result in
                                    switch result{
                                    case .success(let downloadURL):
                                        UserDefaults.standard.set(downloadURL, forKey: "profile_picture_url")
                                        print(downloadURL)
                                    case.failure(let error):print("storage manager error \(error)")
                                    }
                                })
                            }).resume()
                        }
                    })
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
