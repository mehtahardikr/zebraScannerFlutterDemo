//
//  CustomAlert.swift
//  Runner
//
//  Created by hardik on 27/12/22.
//

import UIKit


protocol CustomAlertDelegate: class {
    
    func cancelButtonPressed(_ alert: CustomAlert, alertTag: Int)
}

class CustomAlert: UIViewController {

       @IBOutlet weak var titleLabel: UILabel!
       @IBOutlet weak var cancelButton: UIButton!
       @IBOutlet weak var statusImageView: UIImageView!
       @IBOutlet weak var alertView: UIView!
    
    
       var alertTitle = ""
       var cancelButtonTitle = "Cancel"
       var alertTag = 0
       var statusImage = UIImage.init(named: "pencil")
       
    
        weak var delegate: CustomAlertDelegate?

        init() {
            super.init(nibName: "CustomAlert", bundle: Bundle(for: CustomAlert.self))
            self.modalPresentationStyle = .overCurrentContext
            self.modalTransitionStyle = .crossDissolve
            
        }
        required public init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupAlert()
    }


      func show() {
            if #available(iOS 13, *) {
                UIApplication.shared.windows.first?.rootViewController?.present(self, animated: true, completion: nil)
            } else {
                UIApplication.shared.keyWindow?.rootViewController!.present(self, animated: true, completion: nil)
            }
        }
        
        func setupAlert() {
            titleLabel.text = alertTitle
            statusImageView.image = statusImage
            cancelButton.setTitle(cancelButtonTitle, for: .normal)
        
        }
    
       
    
        @IBAction func actionOnCancelButton(_ sender: Any) {
            self.dismiss(animated: true, completion: nil)
            delegate?.cancelButtonPressed(self, alertTag: alertTag)
        }

}
