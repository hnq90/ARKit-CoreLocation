//
//  ViewController.swift
//  ARKit+CoreLocation
//
//  Created by Andrew Hart on 02/07/2017.
//  Copyright © 2017 Project Dent. All rights reserved.
//

import Foundation
import UIKit
import SceneKit
import MapKit
import ARCL
import CoreLocation

@available(iOS 11.0, *)
class ViewController: UIViewController {
    let sceneLocationView = SceneLocationView()

    let mapView = MKMapView()
    var userAnnotation: MKPointAnnotation?
    var locationEstimateAnnotation: MKPointAnnotation?

    var updateUserLocationTimer: Timer?

    ///Whether to show a map view
    ///The initial value is respected
    var showMapView: Bool = false

    var centerMapOnUserLocation: Bool = true

    ///Whether to display some debugging data
    ///This currently displays the coordinate of the best location estimate
    ///The initial value is respected
    var displayDebugging = false

    var infoLabel = UILabel()

    var updateInfoLabelTimer: Timer?

    var adjustNorthByTappingSidesOfScreen = false

    override func viewDidLoad() {
        super.viewDidLoad()

        infoLabel.font = UIFont.systemFont(ofSize: 10)
        infoLabel.textAlignment = .left
        infoLabel.textColor = UIColor.white
        infoLabel.numberOfLines = 0
        sceneLocationView.addSubview(infoLabel)

        updateInfoLabelTimer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(ViewController.updateInfoLabel),
            userInfo: nil,
            repeats: true)

        // Set to true to display an arrow which points north.
        //Checkout the comments in the property description and on the readme on this.
//        sceneLocationView.orientToTrueNorth = false

//        sceneLocationView.locationEstimateMethod = .coreLocationDataOnly
        sceneLocationView.showAxesNode = true
        sceneLocationView.locationDelegate = self

        if displayDebugging {
            sceneLocationView.showFeaturePoints = true
        }

        buildDemoData().forEach { sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: $0) }

        view.addSubview(sceneLocationView)

        if showMapView {
            mapView.delegate = self
            mapView.showsUserLocation = true
            mapView.alpha = 0.8
            view.addSubview(mapView)

            updateUserLocationTimer = Timer.scheduledTimer(
                timeInterval: 0.5,
                target: self,
                selector: #selector(ViewController.updateUserLocation),
                userInfo: nil,
                repeats: true)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("run")
        sceneLocationView.run()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        print("pause")
        // Pause the view's session
        sceneLocationView.pause()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        sceneLocationView.frame = view.bounds

        infoLabel.frame = CGRect(x: 6, y: 0, width: self.view.frame.size.width - 12, height: 14 * 4)

        if showMapView {
            infoLabel.frame.origin.y = (self.view.frame.size.height / 2) - infoLabel.frame.size.height
        } else {
            infoLabel.frame.origin.y = self.view.frame.size.height - infoLabel.frame.size.height
        }

        mapView.frame = CGRect(
            x: 0,
            y: self.view.frame.size.height / 2,
            width: self.view.frame.size.width,
            height: self.view.frame.size.height / 2)
    }

    @objc func updateUserLocation() {
        guard let currentLocation = sceneLocationView.currentLocation() else {
            return
        }

        DispatchQueue.main.async {
            if let bestEstimate = self.sceneLocationView.bestLocationEstimate(),
                let position = self.sceneLocationView.currentScenePosition() {
                print("")
                print("Fetch current location")
                print("best location estimate, position: \(bestEstimate.position), location: \(bestEstimate.location.coordinate), accuracy: \(bestEstimate.location.horizontalAccuracy), date: \(bestEstimate.location.timestamp)")
                print("current position: \(position)")

                let translation = bestEstimate.translatedLocation(to: position)

                print("translation: \(translation)")
                print("translated location: \(currentLocation)")
                print("")
            }

            if self.userAnnotation == nil {
                self.userAnnotation = MKPointAnnotation()
                self.mapView.addAnnotation(self.userAnnotation!)
            }

            UIView.animate(withDuration: 0.5, delay: 0, options: UIView.AnimationOptions.allowUserInteraction, animations: {
                self.userAnnotation?.coordinate = currentLocation.coordinate
            }, completion: nil)

            if self.centerMapOnUserLocation {
                UIView.animate(withDuration: 0.45, delay: 0, options: UIView.AnimationOptions.allowUserInteraction, animations: {
                    self.mapView.setCenter(self.userAnnotation!.coordinate, animated: false)
                }, completion: { _ in
                    self.mapView.region.span = MKCoordinateSpan(latitudeDelta: 0.0005, longitudeDelta: 0.0005)
                })
            }

            if self.displayDebugging {
                let bestLocationEstimate = self.sceneLocationView.bestLocationEstimate()

                if bestLocationEstimate != nil {
                    if self.locationEstimateAnnotation == nil {
                        self.locationEstimateAnnotation = MKPointAnnotation()
                        self.mapView.addAnnotation(self.locationEstimateAnnotation!)
                    }

                    self.locationEstimateAnnotation!.coordinate = bestLocationEstimate!.location.coordinate
                } else {
                    if self.locationEstimateAnnotation != nil {
                        self.mapView.removeAnnotation(self.locationEstimateAnnotation!)
                        self.locationEstimateAnnotation = nil
                    }
                }
            }
        }
    }

    @objc func updateInfoLabel() {
        if let position = sceneLocationView.currentScenePosition() {
            infoLabel.text = "x: \(String(format: "%.2f", position.x)), y: \(String(format: "%.2f", position.y)), z: \(String(format: "%.2f", position.z))\n"
        }

        if let eulerAngles = sceneLocationView.currentEulerAngles() {
            infoLabel.text!.append("Euler x: \(String(format: "%.2f", eulerAngles.x)), y: \(String(format: "%.2f", eulerAngles.y)), z: \(String(format: "%.2f", eulerAngles.z))\n")
        }

        if let heading = sceneLocationView.locationManager.heading,
            let accuracy = sceneLocationView.locationManager.headingAccuracy {
            infoLabel.text!.append("Heading: \(heading)º, accuracy: \(Int(round(accuracy)))º\n")
        }

        let date = Date()
        let comp = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)

        if let hour = comp.hour, let minute = comp.minute, let second = comp.second, let nanosecond = comp.nanosecond {
            infoLabel.text!.append("\(String(format: "%02d", hour)):\(String(format: "%02d", minute)):\(String(format: "%02d", second)):\(String(format: "%03d", nanosecond / 1000000))")
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        guard
            let touch = touches.first,
            let touchView = touch.view
        else {
            return
        }

        if mapView == touchView || mapView.recursiveSubviews().contains(touchView) {
            centerMapOnUserLocation = false
        } else {
            let location = touch.location(in: self.view)

            if location.x <= 40 && adjustNorthByTappingSidesOfScreen {
                print("left side of the screen")
                sceneLocationView.moveSceneHeadingAntiClockwise()
            } else if location.x >= view.frame.size.width - 40 && adjustNorthByTappingSidesOfScreen {
                print("right side of the screen")
                sceneLocationView.moveSceneHeadingClockwise()
            } else {
                let image = UIImage(named: "pin")!
                let annotationNode = LocationAnnotationNode(location: nil, image: image)
                annotationNode.scaleRelativeToDistance = true
                sceneLocationView.addLocationNodeForCurrentPosition(locationNode: annotationNode)
            }
        }
    }
}

// MARK: - MKMapViewDelegate
@available(iOS 11.0, *)
extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }

        guard let pointAnnotation = annotation as? MKPointAnnotation else {
            return nil
        }

        let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
        marker.displayPriority = .required

        if pointAnnotation == self.userAnnotation {
            marker.glyphImage = UIImage(named: "user")
        } else {
            marker.markerTintColor = UIColor(hue: 0.267, saturation: 0.67, brightness: 0.77, alpha: 1.0)
            marker.glyphImage = UIImage(named: "compass")
        }

        return marker
    }
}

// MARK: - SceneLocationViewDelegate
@available(iOS 11.0, *)
extension ViewController: SceneLocationViewDelegate {
    func sceneLocationViewDidAddSceneLocationEstimate(sceneLocationView: SceneLocationView, position: SCNVector3, location: CLLocation) {
        print("add scene location estimate, position: \(position), location: \(location.coordinate), accuracy: \(location.horizontalAccuracy), date: \(location.timestamp)")
    }

    func sceneLocationViewDidRemoveSceneLocationEstimate(sceneLocationView: SceneLocationView, position: SCNVector3, location: CLLocation) {
        print("remove scene location estimate, position: \(position), location: \(location.coordinate), accuracy: \(location.horizontalAccuracy), date: \(location.timestamp)")
    }

    func sceneLocationViewDidConfirmLocationOfNode(sceneLocationView: SceneLocationView, node: LocationNode) {
    }

    func sceneLocationViewDidSetupSceneNode(sceneLocationView: SceneLocationView, sceneNode: SCNNode) {

    }

    func sceneLocationViewDidUpdateLocationAndScaleOfLocationNode(sceneLocationView: SceneLocationView, locationNode: LocationNode) {

    }
}

// MARK: - Data Helpers
@available(iOS 11.0, *)
private extension ViewController {
    func buildDemoData() -> [LocationAnnotationNode] {
        var nodes: [LocationAnnotationNode] = []

        // TODO: add a few more demo points of interest.
        // TODO: use more varied imagery.

        let spaceNeedle = buildNode(latitude: 21.0171254, longitude: 105.7792757, altitude: 70, imageName: "pin")
        nodes.append(spaceNeedle)

        let empireStateBuilding = buildNode(latitude: 21.0165001, longitude: 105.7794534, altitude: 80, imageName: "pin")
        nodes.append(empireStateBuilding)

        let canaryWharf = buildNode(latitude: 21.0169342, longitude: 105.7805702, altitude: 60, imageName: "pin")
        nodes.append(canaryWharf)

        return nodes
    }

    func buildNode(latitude: CLLocationDegrees, longitude: CLLocationDegrees, altitude: CLLocationDistance, imageName: String) -> LocationAnnotationNode {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(coordinate: coordinate, altitude: altitude)
        let image = UIImage(named: imageName)!
        return LocationAnnotationNode(location: location, image: image)
    }
}

extension DispatchQueue {
    func asyncAfter(timeInterval: TimeInterval, execute: @escaping () -> Void) {
        self.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(timeInterval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: execute)
    }
}

extension UIView {
    func recursiveSubviews() -> [UIView] {
        var recursiveSubviews = self.subviews

        for subview in subviews {
            recursiveSubviews.append(contentsOf: subview.recursiveSubviews())
        }

        return recursiveSubviews
    }
}

@available(iOS 11.0, *)
extension SceneLocationView {
    
    func addAnnotation(_ annotation: MKAnnotation) {
        guard let altitude = currentLocation()?.altitude else { return }
        
        let node = LocationAnnotationNode(annotation: annotation, altitude: altitude)
        addLocationNodeWithConfirmedLocation(locationNode: node)
    }
    
    func addAnnotations(_ annotations: [MKAnnotation]) {
        annotations.forEach(addAnnotation)
    }
    
    func addPolyline(_ polyline: MKPolyline) {
        guard let altitude = currentLocation()?.altitude else { return }
        
        LocationNode.create(polyline: polyline, altitude: altitude - 2)
            .forEach(addLocationNodeWithConfirmedLocation)
    }
    
    func addPolylines(_ polylines: [MKPolyline]) {
        polylines.forEach(addPolyline)
    }
    
}

@available(iOS 11.0, *)
extension LocationAnnotationNode {
    
    convenience init(annotation: MKAnnotation, image: UIImage? = nil, altitude: CLLocationDistance? = nil) {
        
        let location = CLLocation(coordinate: annotation.coordinate, altitude: altitude ?? 0)
        
        self.init(location: location, image: image ?? #imageLiteral(resourceName: "pin"))
        
        scaleRelativeToDistance = false
    }
    
}

@available(iOS 11.0, *)
extension LocationNode {
    
    static func create(polyline: MKPolyline, altitude: CLLocationDistance)  -> [LocationNode] {
        let points = polyline.points()
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .ambient
        lightNode.light!.intensity = 25
        lightNode.light!.attenuationStartDistance = 100
        lightNode.light!.attenuationEndDistance = 100
        lightNode.position = SCNVector3(x: 0, y: 10, z: 0)
        lightNode.castsShadow = false
        lightNode.light!.categoryBitMask = 3
        
        let lightNode3 = SCNNode()
        lightNode3.light = SCNLight()
        lightNode3.light!.type = .omni
        lightNode3.light!.intensity = 100
        lightNode3.light!.attenuationStartDistance = 100
        lightNode3.light!.attenuationEndDistance = 100
        lightNode3.light!.castsShadow = true
        lightNode3.position = SCNVector3(x: -10, y: 10, z: -10)
        lightNode3.castsShadow = false
        lightNode3.light!.categoryBitMask = 3
        
        var nodes = [LocationNode]()
        
        for i in 0..<polyline.pointCount - 1 {
            let currentPoint = points[i]
            let currentCoordinate = currentPoint.coordinate
            let currentLocation = CLLocation(coordinate: currentCoordinate, altitude: altitude)
            
            let nextPoint = points[i + 1]
            let nextCoordinate = nextPoint.coordinate
            let nextLocation = CLLocation(coordinate: nextCoordinate, altitude: altitude)
            
            let distance = currentLocation.distance(from: nextLocation)
            
            let box = SCNBox(width: 1, height: 0.2, length: CGFloat(distance), chamferRadius: 0)
            box.firstMaterial?.diffuse.contents =  UIColor(hue: 0.589, saturation: 0.98, brightness: 1.0, alpha: 1)
            
            let bearing = 0 - bearingBetweenLocations(point1: currentLocation, point2: nextLocation)
            
            let boxNode = SCNNode(geometry: box)
            boxNode.pivot = SCNMatrix4MakeTranslation(0, 0, 0.5 * Float(distance))
            boxNode.eulerAngles.y = Float(bearing).degreesToRadians
            boxNode.categoryBitMask = 3
            boxNode.addChildNode(lightNode)
            boxNode.addChildNode(lightNode3)
            
            let locationNode = LocationNode(location: currentLocation)
            locationNode.addChildNode(boxNode)
            nodes.append(locationNode)
        }
        return nodes
    }
    
    private static func bearingBetweenLocations(point1 : CLLocation, point2 : CLLocation) -> Double {
        let lat1 = point1.coordinate.latitude.degreesToRadians
        let lon1 = point1.coordinate.longitude.degreesToRadians
        
        let lat2 = point2.coordinate.latitude.degreesToRadians
        let lon2 = point2.coordinate.longitude.degreesToRadians
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        return radiansBearing.radiansToDegrees
    }
    
}
