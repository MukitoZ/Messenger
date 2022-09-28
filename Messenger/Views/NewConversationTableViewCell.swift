//
//  NewConversationCell.swift
//  Messenger
//
//  Created by Muhammad Vicky on 28/09/22.
//

import Foundation
import SDWebImage

class NewConversationTableViewCell: UITableViewCell {
    
    static let identifier = "NewConversationTableViewCell"
    
    private let userImageView : UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 35
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let userNameLabel : UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        userImageView.frame = CGRect(x: 10, y: 10, width: 70, height: 70)
        userNameLabel.frame = CGRect(x: userImageView.right + 10, y: 20, width: contentView.width - 20 - userImageView.width, height: 50)
    }
    
    public func configure(with model : SearchResult){
        self.userNameLabel.text = model.name
        
        let path = "images/\(model.email)_profile_picture.png"
        StorageManager.shared.downloadURL(for: path, completion: {
            [weak self] result in
            guard let strongSelf = self else{
                return
            }
            switch result{
            case .success(let url):
                DispatchQueue.main.async {
                    strongSelf.userImageView.sd_setImage(with: url)
                    
                }
            case .failure(let error):
                print("failed to get image url : \(error)")
            }
        })
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
