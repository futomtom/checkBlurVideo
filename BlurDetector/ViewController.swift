//
//  ViewController.swift
//  BlurDetector
//
//  Created by Alex on 4/30/17.
//  Copyright © 2017 alex. All rights reserved.
//

import UIKit
import CoreImage
import GPUImage
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet weak var renderView: RenderView!
    var shouldDetectFaces = true
    lazy var circleGenerator: CircleGenerator = {
        let gen = CircleGenerator(size: Size(width: 100 , height: 100))
        return gen
    }()
    var saturationFilter = SaturationAdjustment()
    let laplacianFilter = Laplacian()
    
    let blendFilter = AlphaBlend()
    var camera:Camera!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        do {
            saturationFilter.saturation = 0
            camera = try Camera(sessionPreset:AVCaptureSessionPreset640x480)
            camera.runBenchmark = false
            camera.delegate = self
           
            camera --> saturationFilter --> laplacianFilter --> blendFilter  --> renderView
     /*     should NOT apply filter in preview ,  Since checkblur Agorithm does not work. so I apply filter here
            camera  --> blendFilter  --> renderView
       */
            
            circleGenerator --> blendFilter
            camera.startCapture()
        } catch {
            fatalError("Could not initialize rendering pipeline: \(error)")
        }
    }
    

}

extension ViewController: CameraDelegate {
    func didCaptureBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))!
            let ciimage = CIImage(cvPixelBuffer: pixelBuffer, options: attachments as? [String: AnyObject])
            let image = convertCIImagetoUIimage(ciimage)
            var saturation = SaturationAdjustment()
            let laplacian = Laplacian()
            
            saturation.saturation = 0
            
            let resultImage = image.filterWithPipeline { input, output in
                input --> saturation --> laplacian  --> output
            }
        
            if checkBlur(resultImage) {
                circleGenerator.renderCircleOfRadius(0.1, center: Position(0.5, 0.5),circleColor:Color.red, backgroundColor:Color.transparent)
            }
        
        }
    }
    
    func convertCIImagetoUIimage(_ cmage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
    
    func checkBlur(_ image:UIImage) -> Bool{
        let cgImage = image.cgImage
        let pixelData = cgImage!.dataProvider!.data
        
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let bytesPerPixel = cgImage!.bitsPerPixel / 8
    
        let width = Int(image.size.width)
        let high = Int(image.size.height)
        
        var maxLap = -16777216;
        for y in 0..<high {
            for x in 0..<width {
                let pixelIndex = ((width * y) + x) * bytesPerPixel
                print (data[pixelIndex + 0],data[pixelIndex + 1],data[pixelIndex + 2] )
                let pixel  = Int(data[pixelIndex + 0]) * 256 * 256  + Int(data[pixelIndex + 1]) * 256 + Int(data[pixelIndex + 2])
                print(pixel)
                maxLap = pixel > maxLap ? pixel :maxLap
            }
        }
        print ("maxLap =\(maxLap)")
        let  soglia = -6118750;
        if (maxLap < soglia || maxLap == soglia) {
            print("blur image")
            return true
        } else {
        print("NOT a blur image")
        return false
       }
    }
    
  

    
  }
