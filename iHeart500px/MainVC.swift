//
//  Created by FareedQ on 2016-01-26.
//  Copyright © 2016 FareedQ. All rights reserved.
//  Created as a gift/demonstration to 500px of connecting to their API
//

import UIKit
import OAuthSwift

//Setup OAuth Client object to be able to be used globally throughout the project
//Aquire your consumerKey and consumerSecret at https://500px.com/
let oauthswift = OAuth1Swift(consumerKey:"fXGxgfzz2ivSUEwnIdjUyq1XOZ5pogmLUnimVnDK", consumerSecret: "53u773HMG0zihJIGLub55N73mqSumUsqeVdRTXMv", requestTokenUrl: "https://api.500px.com/v1/oauth/request_token", authorizeUrl:"https://api.500px.com/v1/oauth/authorize", accessTokenUrl:"https://api.500px.com/v1/oauth/access_token")

class MainVC: UIViewController {
    
    @IBOutlet weak var displayImages: UIButton!
    @IBOutlet weak var imageCollectionView: UICollectionView!
    
    var imageItemArray = [ImageItem]()
    var imagesArray = [UIImage]() //exist because of a confusion with multithreading
    
    struct ImageItem {
        let image:UIImage
        let id:Int
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupImages()
        overrideNativeGuestures()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func login(_ sender: UIButton) {
        oauthswift.authorize(withCallbackURL: "iHeart500px://OAuth-Callback",
            success: {
                credential, response, parameters in
                sender.isEnabled = false
            }, failure: { error in
        })
    }
    
    @IBAction func displayImages(_ sender: AnyObject) {
        imageCollectionView.reloadData()
        displayImages.isHidden = true
    }
}

//This area of code is used to setup my own guesture reconigizers
extension MainVC {
    
    func overrideNativeGuestures(){
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(MainVC.likeImage(_:)))
        gestureRecognizer.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(gestureRecognizer)
        
        guard let gestures = imageCollectionView.gestureRecognizers else { return }
        for gesture in gestures {
            gestureRecognizer.require(toFail: gesture)
        }
    }
    
    func likeImage(_ sender: UITapGestureRecognizer){
        let locationInCollectionView = sender.location(in: imageCollectionView)
        guard let indexPath = imageCollectionView.indexPathForItem(at: locationInCollectionView) else {return}
        let _ = oauthswift.client.post("https://api.500px.com/v1/photos/\(imageItemArray[indexPath.row].id)/vote?vote=1", success: { (response) in
            guard let cell = self.imageCollectionView.cellForItem(at: indexPath) as? ImageCell else {return}
            cell.expandLikeImage()
        }) { (error) in
            alertMessage("Error",message: error.localizedDescription, theCurrentViewController: self)
        }
    }
    
}

extension MainVC {
    
    // Very large function that I had difficulty refactoring so I commented for the time being
    func setupImages(){
        let _ = oauthswift.client.get("https://api.500px.com/v1/photos?feature=highest_rated&sort=created_at&image_size", success: { (response) -> Void in
            do {
                let json = try JSONSerialization.jsonObject(with: response.data, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String:Any]
                
                //Parses JSON from manually looking at JSON object
                guard let jsonArray0 = json?["photos"] as? [[String:Any]] else {return}
                for n in 0...jsonArray0.count-1{
                    guard let jsonPhoto = jsonArray0[n] as? NSDictionary else {return}
                    
                    //Created temporary holder objects
                    var imageHolder = UIImage()
                    var idHolder = Int()
                    
                    //Extract Image Item
                    guard let imageUrl = jsonPhoto["image_url"] as? String else {return}
                    guard let url = URL(string: imageUrl) else {return }
                    DispatchQueue.main.async{
                    self.getDataFromUrl(url) { (data, response, error)  in
                        guard let safeData = data, error == nil else { return }
                        guard let returnedImage = UIImage(data: safeData as Data) else {return}
                        imageHolder = returnedImage
                        
                        //Adppending to an imagesArray because I couldn't get this getting of data to run async with the other thread
                        self.imagesArray.append(returnedImage)
                        }
                    }
                    
                    //Wasn't allowed to extract the id from the JSON file because that key wasn't a string
                    //Extracted the id from the URL with string manipulation
                    let myStringArray = imageUrl.components(separatedBy: "/")
                    guard let tempIntHolder = Int(myStringArray[4]) else {
                        print("Couldn't extract the id from URL properly")
                        return
                    }
                    idHolder = tempIntHolder
                    
                    //Add to the image struct array
                    self.imageItemArray.append(ImageItem(image: imageHolder, id: idHolder))
                }
                
                DispatchQueue.main.async {
                    //Unsure why self.imageCollectionView.reloadData() isn't executing need to consult my network of programming associates
                    //Had to create this display image button instead
                    self.displayImages.isEnabled = true
                }
                
            } catch _ as NSError {
            }
            }) { (error) -> Void in
                print(error)
        }
    }
    
    //This is a simple network call without the OAuth framework to get the image
    func getDataFromUrl(_ url:URL, completion: @escaping ((_ data: NSData?, _ response: URLResponse?, _ error: NSError? ) -> Void)) {
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            completion(data as NSData?, response, error as NSError?)
            }.resume()
    }
}

//This extension is to manage the CollectionView
extension MainVC: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageItemArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath) as? ImageCell else { return UICollectionViewCell()}
        cell.imageView.image = imagesArray[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
            let mySize = CGSize(width: collectionView.bounds.size.width, height: collectionView.bounds.size.width*0.7)
            return mySize
    }
}

// Extension in the AppDelegate to manage the OAuth Callback
extension AppDelegate {
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        if (url.host == "OAuth-Callback") {
            OAuthSwift.handle(url: url)
        }
        return true
    }
}

// Extension in ImageCell to animate the liking of the image
extension ImageCell {
    func expandLikeImage(){
        self.likeImage.alpha = 1
        likeImage.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        UIView.animate(withDuration: 0.2, animations: { () -> Void in
            self.likeImage.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            }, completion: { (complete) -> Void in
                if complete {
                    UIView.animate(withDuration: 0.1, animations: { () -> Void in
                        self.likeImage.transform = CGAffineTransform(scaleX: 1, y: 1)
                        }, completion: { (complete) -> Void in
                            if complete {
                                UIView.animate(withDuration: 0.3, animations: { () -> Void in
                                    self.likeImage.alpha = 0
                                })
                            }
                    })
                }
        }) 
    }
}

//I like to have the Alert Message function as a global helper function accessable by any ViewController
func alertMessage(_ title:String, message:String, theCurrentViewController:UIViewController){
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    let okay = UIAlertAction(title: "Okay", style: .default) { (UIAlertAction) -> Void in
    }
    alert.addAction(okay)
    theCurrentViewController.present(alert, animated: true, completion: nil)
}
