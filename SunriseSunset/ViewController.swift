import UIKit
import GooglePlaces

class ViewController: UIViewController {
    
    var placesClient: GMSPlacesClient!
    let locationManager = CLLocationManager()
    var latitude = Double()
    var longitude = Double()
    
    var resultsViewController: GMSAutocompleteResultsViewController?
    var searchController: UISearchController?
    var resultView: UITextView?

    @IBOutlet var addressLabel: UILabel!
    
    @IBOutlet weak var sunsetLabel: UILabel!
    @IBOutlet weak var sunriseLabel: UILabel!
    @IBOutlet weak var timezoneLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        placesClient = GMSPlacesClient.shared()
        locationManager.requestAlwaysAuthorization()
        
        resultsViewController = GMSAutocompleteResultsViewController()
        resultsViewController?.delegate = self
        
        searchController = UISearchController(searchResultsController: resultsViewController)
        searchController?.searchResultsUpdater = resultsViewController
        
        let subView = UIView(frame: CGRect(x: 0, y: 65.0, width: self.view.frame.width, height: 45.0))
        
        subView.addSubview((searchController?.searchBar)!)
        view.addSubview(subView)
        searchController?.searchBar.sizeToFit()
        searchController?.searchBar.searchBarStyle = .minimal
        searchController?.hidesNavigationBarDuringPresentation = false
        
        definesPresentationContext = true
    }
    
    @IBAction func getCurrentPlace(_ sender: UIButton) {
        
        placesClient.currentPlace(callback: { (placeLikelihoodList, error) -> Void in
            if let error = error {
                print("Pick Place error: \(error.localizedDescription)")
                return
            }
            self.addressLabel.text = ""
            
            if let placeLikelihoodList = placeLikelihoodList {
                let place = placeLikelihoodList.likelihoods.first?.place
                if let place = place {
                    self.addressLabel.text = place.name
                    self.sendRequestWithCoordinates(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
                }
            }
        })
    }
    
    func sendRequestWithCoordinates(latitude: Double, longitude: Double) {
        var request = URLRequest(url: URL(string: "https://api.sunrise-sunset.org/json?lat=\(latitude)&lng=\(longitude)")!)
        request.httpMethod = "GET"
        let session = URLSession.shared
        
        session.dataTask(with: request) {data, response, err in
            if err != nil {
                print(err!.localizedDescription)
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: []) as! [String: AnyObject]
                
                if let results = json["results"] as? [String: String],
                    let sunrise = results["sunrise"] as? String,
                    let sunset = results["sunset"] as? String {
                    
                    self.getTimezoneByLoc(latitude: latitude, longitude: longitude)
                    
                    //Trying to convert time, but not working
                    //let sunriseF = self.UTCToLocal(time: sunrise, timezoneID: timezoneID)
                    //let sunsetF = self.UTCToLocal(time: sunset, timezoneID: timezoneID)
                    
                    DispatchQueue.main.async {
                        self.sunsetLabel.text = sunset
                        self.sunriseLabel.text = sunrise
                    }
                    
                }
            } catch let error as NSError {
                print("Failed to load: \(error.localizedDescription)")
            }
            }.resume()
    }
    
    func UTCToLocal(time:String, timezoneID: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss a"
        
        let dt = dateFormatter.date(from: time)
        dateFormatter.timeZone = TimeZone(identifier: timezoneID)
        dateFormatter.dateFormat = "HH:mm:ss"
        
        return dateFormatter.string(from: dt!)
    }
    
    func getTimezoneByLoc(latitude: Double, longitude: Double){
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        var timezoneID = String()
        
        CLGeocoder().reverseGeocodeLocation(location, completionHandler:
            {(placemarks, error)-> Void in
                if let placemarks = placemarks {
                    do {
                        let placeMark = placemarks.last
                        let placeDesc = placeMark?.description as NSString?
                        let regex : NSRegularExpression = try NSRegularExpression(pattern: "\"[a-z]*\\/[a-z]*_*[a-z]*\"", options: .caseInsensitive)
                        let newSearchString : NSTextCheckingResult? = regex.firstMatch(in: placeDesc as! String, options: NSRegularExpression.MatchingOptions(), range: NSRange(location: 2, length: ((placeDesc?.length)!-2)))
                        let substr = placeDesc?.substring(with: (newSearchString?.range)!) as! String
                        
                        var str = String(substr.characters.dropLast())
                        str = String(str.characters.dropFirst())
                        timezoneID = str as! String
                        
                        DispatchQueue.main.async {
                            self.timezoneLabel.text = timezoneID
                        }
                    } catch let error as NSError {
                        print(error.localizedDescription)
                    }
                } else if let error = error {
                    print("reverse geodcode fail: \(error.localizedDescription)")
                }
        })
    }
}




extension ViewController: GMSAutocompleteResultsViewControllerDelegate {
    func resultsController(_ resultsController: GMSAutocompleteResultsViewController,
                           didAutocompleteWith place: GMSPlace) {
        searchController?.isActive = false
        self.addressLabel.text = place.name
        sendRequestWithCoordinates(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
    }
    
    func resultsController(_ resultsController: GMSAutocompleteResultsViewController,
                           didFailAutocompleteWithError error: Error){
        print("Error: ", error.localizedDescription)
    }
    
    // Turn the network activity indicator on and off again.
    func didRequestAutocompletePredictions(forResultsController resultsController: GMSAutocompleteResultsViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func didUpdateAutocompletePredictions(forResultsController resultsController: GMSAutocompleteResultsViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
}
