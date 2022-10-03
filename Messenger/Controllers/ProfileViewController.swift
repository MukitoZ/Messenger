//
//  ProfileViewController.swift
//  Messenger
//
//  Created by Muhammad Vicky on 20/09/22.
//

import UIKit
import FirebaseAuth
import FacebookLogin
import GoogleSignIn
import JGProgressHUD
import SDWebImage


class ProfileViewController: UIViewController {
    
    
    @IBOutlet var tableView : UITableView!
    var data = [ProfileViewModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        fetchUserProfile()
                
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        data = []
        fetchUserProfile()
        tableView.tableHeaderView = createTableHeader()
        tableView.reloadData()
    }
    
    func fetchUserProfile(){
        print(UserDefaults.standard.value(forKey: "name") as? String)
        data.append(ProfileViewModel(viewModelType: .info, title: UserDefaults.standard.value(forKey: "name") as? String ?? "", handler: nil))
        data.append(ProfileViewModel(viewModelType: .info, title: UserDefaults.standard.value(forKey: "email") as? String ?? "", handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", handler: { [weak self] in
            guard let strongSelf = self else{
                return
            }
            
            let actionSheet = UIAlertController(title: "", message: "", preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "Log out", style: .destructive, handler: {
                [weak self] _ in
                guard let strongSelf = self else{
                    return
                }
                
                // Log out
                
                UserDefaults.standard.setValue(nil, forKey: "email")
                UserDefaults.standard.setValue(nil, forKey: "name")
                
                //Log out facebook
                LoginManager().logOut()
                
                //Log out google
                GIDSignIn.sharedInstance.signOut()
                
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    strongSelf.present(nav, animated: true)
                } catch{
                    print("failed logout")
                }
            }))
            actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            strongSelf.present(actionSheet, animated: true)
        }))
    }
    
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let fileName = "\(safeEmail)_profile_picture.png"
        
        let path = "images/\(fileName)"
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 300))
        
        headerView.backgroundColor = .blue
        
        let imageView = UIImageView(frame: CGRect(x: (headerView.width - 150) / 2, y: 75, width: 150, height: 150))
        
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .white
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width / 2
        headerView.addSubview(imageView)
        
        StorageManager.shared.downloadURL(for: path, completion: { result in
            switch result{
            case .success(let url):
                imageView.sd_setImage(with: url)
            case .failure(let error):
                print("Failed to get download url: \(error)")
            }
        })
        return headerView
    }
}


extension ProfileViewController : UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        cell.setUp(with: viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].handler?()
    }
}

class ProfileTableViewCell: UITableViewCell{
    
    static let identifier = "ProfileTableViewCell"
    
    public func setUp(with viewModel : ProfileViewModel){
        self.textLabel?.text = viewModel.title
        switch viewModel.viewModelType {
        case .info:
            self.textLabel?.textAlignment = .left
            self.textLabel?.textColor = .label
            self.selectionStyle = .none
        case .logout:
            self.textLabel?.textColor = .red
            self.textLabel?.textAlignment = .center
        }
    }
}
