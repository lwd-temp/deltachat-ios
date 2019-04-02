//
//  AccountSetupController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 02.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit
import JGProgressHUD


class AccountSetupController: UITableViewController {
    
    lazy var hudHandler: HudHandler = {
        let hudHandler = HudHandler(parentView: self.tableView)
        return hudHandler
    }()
    
    lazy var emailCell:InputTableViewCell = {
       let cell = InputTableViewCell()
        cell.textLabel?.text = "Email"
        cell.inputField.placeholder = "user@example.com"
        return cell
    }()
    
    lazy var passwordCell:PasswordInputCell = {
        let cell = PasswordInputCell()
        cell.textLabel?.text = "Password"
        cell.inputField.placeholder = "Required"
        return cell
    }()
  
  init() {
    super.init(style: .grouped)
    tableView.allowsSelection = false
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
      super.viewDidLoad()
    self.title = "Login to your server"
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Login", style: .done, target: self, action: #selector(loginButtonPressed))
  }

    // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
      // #warning Incomplete implementation, return the number of sections
      return 2
  }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      // #warning Incomplete implementation, return the number of rows
        if section == 0 {
            return 2
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return "Advanced"
        } else {
            return nil 
        }
    }
    
    
    
    /*
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            return nil 
        } else {
            let label = UILabel()
            label.text = "Advanced"
            return label
        }
    }
    */
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "There are no Delta Chat servers, your data stays on your device!"
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        if row == 0 {
            return emailCell
        } else {
            return passwordCell
        }
    }
    
    @objc func loginButtonPressed() {
        guard let emailAdress = emailCell.getText() else {
            return // handle case when either email or pw fields are empty
        }
        
        let passWord = passwordCell.getText()  ?? "" // empty passwords are ok -> for oauth there is no password needed
        
        MRConfig.addr = emailAdress
        MRConfig.mailPw = passWord
        dc_configure(mailboxPointer)
        hudHandler.showBackupHud("Configuring account")
    }
}


class InputTableViewCell: UITableViewCell {
    
    lazy var inputField: UITextField = {
        let textField = UITextField()
        return textField
    }()
    
    
    init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        contentView.addSubview(inputField)
        inputField.translatesAutoresizingMaskIntoConstraints = false
        
        inputField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
        inputField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        inputField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
        inputField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 100).isActive = true
        inputField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0).isActive = true
    }
    
    public func getText() -> String? {
        return inputField.text 
    }
}

class PasswordInputCell: UITableViewCell {
    
    lazy var inputField: UITextField = {
        let textField = UITextField()
        textField.isSecureTextEntry = true
        return textField
    }()
    
    // TODO: to add Eye-icon -> uncomment -> add to inputField.rightView
    /*
    lazy var makeVisibleIcon: UIImageView = {
       let view = UIImageView(image: )
        return view
    }()
    */
    
    init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        contentView.addSubview(inputField)
        inputField.translatesAutoresizingMaskIntoConstraints = false
        
        inputField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
        inputField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        inputField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
        inputField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 100).isActive = true
        inputField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0).isActive = true
    }
    
    public func getText() -> String? {
        return inputField.text 
    }
}


class HudHandler {
    
    var backupHud: JGProgressHUD?
    var view:UIView
    
    init(parentView: UIView) {
        self.view = parentView
    }
    
    
    
    func setHudProgress(_ progress: Int) {
        if let hud = self.backupHud {
            hud.progress = Float(progress) / 1000.0
            hud.detailTextLabel.text = "\(progress / 10)% Complete"
        }
    }
    
    func showBackupHud(_ text: String) {
        DispatchQueue.main.async {
            let hud = JGProgressHUD(style: .dark)
            hud.vibrancyEnabled = true
            hud.indicatorView = JGProgressHUDPieIndicatorView()
            
            hud.detailTextLabel.text = "0% Complete"
            hud.textLabel.text = text
            hud.show(in: self.view)
            
            self.backupHud = hud
        }
    }

    
    func setHudError(_ message: String?) {
        if let hud = self.backupHud {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                UIView.animate(
                    withDuration: 0.1, animations: {
                        hud.textLabel.text = message ?? "Error"
                        hud.detailTextLabel.text = nil
                        hud.indicatorView = JGProgressHUDErrorIndicatorView()
                }
                )
                
                hud.dismiss(afterDelay: 5.0)
            }
        }
    }
    
    func setHudDone(callback: (()->())?) {
        if let hud = self.backupHud {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                UIView.animate(
                    withDuration: 0.1, animations: {
                        hud.textLabel.text = "Success"
                        hud.detailTextLabel.text = nil
                        hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                }
                )
                
                callback?()
                hud.dismiss(afterDelay: 1.0)
            }
        }
    }
}
