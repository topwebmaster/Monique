//
//  ViewController.swift
//  WebCam
//
//  Created by Shavit Tzuriel on 10/18/16.
//  Copyright © 2016 Shavit Tzuriel. All rights reserved.
//

import Cocoa
import AVKit
import AVFoundation
import CoreMedia


class ViewController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var webcam:AVCaptureDevice? = nil
    var videoOutput:AVCaptureVideoDataOutput? = nil
    var videoSession:AVCaptureSession? = nil
    var videoPreviewLayer:AVCaptureVideoPreviewLayer? = nil
    
    var sessionReady:Bool = true
    var detectionBoxView: NSView?
    
    let stream: Stream = Stream()
    
    @IBOutlet weak var playerPreview:NSView?
    @IBOutlet weak var videoPlayerView: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        videoOutput = AVCaptureVideoDataOutput()
        videoSession = AVCaptureSession()
        
    }
    
    override func viewWillAppear() {
        self.setVideoSession()
        
        // Use a m3u8 playlist
//        let streamURL:URL = URL(string: "http://localhost:3000/playlists/1.mp4")!
        // Play mp4
        let streamURL:URL = URL(string: "http://localhost:3000/stream/live")!
        let player:AVPlayer = AVPlayer(url: streamURL)
        
        let playerView = AVPlayerView()
        playerView.frame = videoPlayerView.frame
        playerView.player = player
        videoPlayerView.addSubview(playerView)
        
        // Start streaming
        player.play()
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
            print("---> Update the view if it was loaded")
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        _ = CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
//        let imageWidth: size_t = CVPixelBufferGetWidth(imageBuffer)
        let imageHeight: size_t = CVPixelBufferGetHeight(imageBuffer)
        let bytes: size_t = CVPixelBufferGetBytesPerRow(imageBuffer)
        let image = CVPixelBufferGetBaseAddress(imageBuffer)
        
        
        
        // Perform core animation in the main thread
        DispatchQueue.main.async {
            // Detect the image
            self.detectLiveImage(picture: imageBuffer)
        }
    
        // Unlock the buffer
        _ = CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // Send the live image to the server
        let imageData: NSData = NSData(bytes: image, length: (bytes * imageHeight))
        
        stream.broadcastData(message: imageData)
    }
    
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didDrop sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        print("---> Streaming (end?)")
        stream.broadcast(message: "Message from camera")

    }
    
    func detectLiveImage(picture: CVImageBuffer){
        
        let context = CIContext()
        let detector = CIDetector(ofType: CIDetectorTypeFace, context: context, options: nil)
        let image: CIImage = CIImage(cvImageBuffer: picture)
        let features = detector?.features(in: image) // [CIFeature]
        
        print("---> Detecting")
        print("---> Image: \(image)")
        
        for ciFeature in features! {
            // Display a rectangle
            print("---> Features bounds: \(ciFeature.bounds)")
            detectionBoxView?.draw(ciFeature.bounds)
        }
    }

    @IBAction func CaptureWebCamVideo(_ sender: AnyObject) {
        if (sessionReady == false){
            // Stop the session
            videoPreviewLayer?.session.stopRunning()
            sessionReady = !sessionReady
            return
        }
        
        // Start the session
        videoPreviewLayer?.session.startRunning()
        
        // Set the camera state
        sessionReady = !sessionReady
    }
    
    @IBAction func CaptureScreenVideo(_ sender: Any) {
        print("---> Capturing screen")
    }
    
    
    func setVideoSession(){
        // Web cameras
        //let devices = AVCaptureDevice.devices(withMediaType: "AVCaptureDALDevice")
        // Microphone
        // let devices = AVCaptureDevice.devices(withMediaType: "AVCaptureHALDevice")
        
        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
        // Pick the first one
        if (devices?.count)! > 0 {
            webcam = devices?[0] as? AVCaptureDevice
        } else{
            print("---> No available devices")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: webcam)
            if videoSession!.canAddInput(input){
                videoSession!.addInput(input)
                
//                videoOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_420YpCbCr8PlanarFullRange)]
                videoOutput!.alwaysDiscardsLateVideoFrames = true
                
                // Register the sample buffer callback
                let queue = DispatchQueue(label: "Streaming")
                videoOutput!.setSampleBufferDelegate(self, queue: queue)
                
                videoPreviewLayer = AVCaptureVideoPreviewLayer(session: videoSession)
                // resize the video to fill
                videoPreviewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
                videoPreviewLayer!.connection.videoOrientation = AVCaptureVideoOrientation.portrait
                
                // position the layer
                videoPreviewLayer!.position = CGPoint(x: (self.playerPreview?.frame.width)!/2, y: (self.playerPreview?.frame.height)!/2)
                videoPreviewLayer!.bounds = (self.playerPreview?.frame)!
                
                // add the preview to the view
//                playerPreview?.layer?.addSublayer(videoPreviewLayer!)
                playerPreview?.layer? = videoPreviewLayer!
                
                // Add a detection box on top of the preview layer
                self.detectionBoxView = DetectionBoxView()
                playerPreview?.addSubview(self.detectionBoxView!)
                
                // Output data
                if videoSession!.canAddOutput(videoOutput){
                    videoSession!.addOutput(videoOutput)
                }
                
            }
            
        }
        catch {
            print("---> Cannot use webcam")
        }
        
    }

}

