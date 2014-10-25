//
//  ViewController.swift
//  FilmLoupe
//
//  Created by Mike Meyer on 2014/10/23.
//  Copyright (c) 2014 Meyer Co. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate , AVCaptureMetadataOutputObjectsDelegate {

    let screenWidth = UIScreen.mainScreen().bounds.size.width
    
    let captureSession = AVCaptureSession()
    var previewLayer : CALayer!
    var captureDevice : AVCaptureDevice?

    var currentSampleTime : CMTime?
    var currentVideoDimensions : CMVideoDimensions?
    var ciImage : CIImage!
    
    lazy var context: CIContext = {
        let eaglContext = EAGLContext(API: EAGLRenderingAPI.OpenGLES2)
        let options = [kCIContextWorkingColorSpace : NSNull()]
        return CIContext(EAGLContext: eaglContext, options: options)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        captureSession.beginConfiguration()

        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    
        if captureDevice != nil {
            println("Capture device found: \(captureDevice)")
        } else {
            println("No capture device found :(")
            return
        }
    
        let deviceInput = AVCaptureDeviceInput.deviceInputWithDevice(captureDevice, error: nil) as AVCaptureDeviceInput
        
        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
        }
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA]
        dataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
        }
        
        let queue = dispatch_queue_create("VideoQueue", DISPATCH_QUEUE_SERIAL)
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        
        captureSession.commitConfiguration()

        previewLayer = CALayer()
        self.view.layer.addSublayer(previewLayer)

        previewLayer.anchorPoint = CGPointZero
        previewLayer.bounds = view.bounds
        
        captureSession.startRunning()
    }
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        let oldHeight = view.bounds.height
        let oldWidth = view.bounds.width
        
        println("About to rotate: \(oldWidth) x \(oldHeight)")

//        :C
        previewLayer.anchorPoint = CGPointZero
        previewLayer.bounds = CGRectMake(0, 0, oldHeight, oldWidth)
    }
    
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
//        previewLayer.anchorPoint = CGPointZero
//        previewLayer.bounds = view.bounds
    }
    
    func focusTo(value : Float) {
        if let device = captureDevice {
            if(device.lockForConfiguration(nil)) {
                device.setFocusModeLockedWithLensPosition(value, completionHandler: { (time) -> Void in
                    //
                })
                device.unlockForConfiguration()
            }
        }
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)

        self.currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        self.currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)

        var outputImage = CIImage(CVPixelBuffer: imageBuffer)

        let orientation = UIDevice.currentDevice().orientation
        var t: CGAffineTransform!
        if orientation == UIDeviceOrientation.Portrait {
            t = CGAffineTransformMakeRotation(CGFloat(-M_PI / 2.0))
        } else if orientation == UIDeviceOrientation.PortraitUpsideDown {
            t = CGAffineTransformMakeRotation(CGFloat(M_PI / 2.0))
        } else if (orientation == UIDeviceOrientation.LandscapeRight) {
            t = CGAffineTransformMakeRotation(CGFloat(M_PI))
        } else {
            t = CGAffineTransformMakeRotation(0)
        }
        outputImage = outputImage.imageByApplyingTransform(t)
        
//        Invert!
        var invertFilter = CIFilter(name: "CIColorInvert")
        invertFilter.setValue(outputImage, forKey: kCIInputImageKey)

        outputImage = invertFilter.outputImage
        
        let cgImage = self.context.createCGImage(outputImage, fromRect: outputImage.extent())
        self.ciImage = outputImage
        
        dispatch_sync(dispatch_get_main_queue(), {
            self.previewLayer.contents = cgImage
        })
    }
    
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        var anyTouch = touches.anyObject() as UITouch
        var touchPercent = anyTouch.locationInView(self.view).x / screenWidth
        focusTo(Float(touchPercent))
    }
    
    override func touchesMoved(touches: NSSet, withEvent event: UIEvent) {
        var anyTouch = touches.anyObject() as UITouch
        var touchPercent = anyTouch.locationInView(self.view).x / screenWidth
        focusTo(Float(touchPercent))
    }
}
