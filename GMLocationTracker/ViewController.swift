//
//  ViewController.swift
//  GMLocationTracker
//
//  Created by Samuel Dost on 6/4/17.
//  Copyright © 2017 Samuel Dost. All rights reserved.
//

import UIKit
import GoogleMaps
import Starscream

class ViewController: UIViewController, WebSocketDelegate, GMSMapViewDelegate, CLLocationManagerDelegate {
    
    let socket = WebSocket(url: URL(string: "ws://localhost:8080/")!, protocols: ["chat", "superchat"])
    let locationManager = CLLocationManager()
    var mapView: GMSMapView?
    let regionRadius: CLLocationDistance = 200
    
    var markers: [String: GMSMarker] = [:]
    
    var currentHeading: CLLocationDirection = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.green
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
        //GMServices.provideAPIKey("AIzaSyBdVl-cTICSwYKrZ95SuvNw7dbMuDt1KG0")
        
        socket.delegate = self
        socket.connect()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.addMap()
        self.addNavigationBar()
    }

    // MARK: Add map
    
    func addMap() {
        let camera = GMSCameraPosition.camera(withLatitude: -33.86, longitude: 151.20, zoom: 6.0)
        let mapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
        mapView.delegate = self
        self.view.addSubview(mapView)
        
        self.mapView = mapView
    }
    
    // MARK: Add nav and buttons
    
    func addNavigationBar() {
        let screenSize: CGRect = UIScreen.main.bounds
        let navBar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: screenSize.width, height: 44))
        let navItem = UINavigationItem(title: "")
        
        let connectButtonItem = UIBarButtonItem(
            title: "Disconnect",
            style: .plain,
            target: self,
            action: #selector(disconnect(_:)))
        navItem.rightBarButtonItem = connectButtonItem
        
        navBar.setItems([navItem], animated: false)
        self.view.addSubview(navBar)
    }
    
    // MARK: Track location changes.
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.first else { return }
        
        let long = userLocation.coordinate.longitude
        let lat = userLocation.coordinate.latitude
        let alt = userLocation.altitude
        
        let message = [
            "email": "guy@guy.com",
            "username": "guy1",
            "message": "hi there",
            "position": [
                "lat": lat,
                "lon": long,
                "alt": alt,
                "heading": self.currentHeading
            ]
        ] as [String : Any]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: message, options: .prettyPrinted) {
            socket.write(data: jsonData)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy < 0 { return }
        
        let heading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        
        self.currentHeading = heading
    }
    
    // MARK: Websocket Delegate Methods.
    
    func websocketDidConnect(socket: WebSocket) {
        print("websocket is connected")
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        if let e = error {
            print("websocket is disconnected: \(e.localizedDescription)")
        } else {
            print("websocket disconnected")
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        print("Received text: \(text)")
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
            let dict = jsonObject as? [String: Any],
            let username = dict["username"] as? String,
            let pos = dict["position"] as? [String: Double],
            let lat = pos["lat"],
            let lon = pos["lon"],
            let alt = pos["alt"],
            let heading = pos["heading"] {
            
            let newLocation2D = CLLocationCoordinate2DMake(lat, lon)
            let newLocation = CLLocation(coordinate: newLocation2D, altitude: alt, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp:Date())
            
            // Update the map frame
            self.updateMapFrame(newLocation, zoom: 17.0)
            // Update Marker position
            self.updatePositionMarker(username, location: newLocation, heading: heading)
        }
    }
    
    // MARK: Map Helpers
    
    func updateMapFrame(_ location: CLLocation, zoom: Float) {
        let camera = GMSCameraPosition.camera(withTarget: location.coordinate, zoom: zoom)
        self.mapView?.animate(to: camera)
    }
    
    func updatePositionMarker(_ username: String, location: CLLocation, heading: CLLocationDirection) {
        if let marker = self.markers[username] {
            CATransaction.begin()
            CATransaction.setAnimationDuration(2.0)
            marker.position = location.coordinate
            marker.rotation = heading
            CATransaction.commit()
        } else {
            let marker = GMSMarker(position: location.coordinate)
            marker.rotation = heading
            marker.map = self.mapView
            marker.icon = GMSMarker.markerImage(with: UIColor.cyan)
            self.markers[username] = marker
        }
    }
    
    // MARK: Disconnect Action
    
    func disconnect(_ sender: UIBarButtonItem) {
        if socket.isConnected {
            sender.title = "Connect"
            socket.disconnect()
        } else {
            sender.title = "Disconnect"
            socket.connect()
        }
    }
}

