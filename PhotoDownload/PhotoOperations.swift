//
//  PhotoOperations.swift
//  PhotoDownload
//
//  Created by David Shore on 2016-06-06.
//  Copyright © 2016 Foggy Media. All rights reserved.
//

import UIKit

// This enum contains all the possible states a photo record can be in
enum PhotoRecordState {
    case New, Downloaded, Failed
}

class PhotoRecord {
    let index:Int
    let url:NSURL
    var state = PhotoRecordState.New
    var image = UIImage(named: "Placeholder")
    
    init(index:Int, url:NSURL) {
        self.index = index
        self.url = url
    }
}

class PendingOperations {
    lazy var downloadsInProgress = [NSIndexPath:NSOperation]()
    lazy var downloadQueue:NSOperationQueue = {
        var queue = NSOperationQueue()
        queue.name = "Download queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    lazy var filtrationsInProgress = [NSIndexPath:NSOperation]()
    lazy var filtrationQueue:NSOperationQueue = {
        var queue = NSOperationQueue()
        queue.name = "Image Filtration queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}

class ImageDownloader: NSOperation {
    
    let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    var dataTask: NSURLSessionDataTask?
    
    let photoRecord: PhotoRecord
    let completion: () -> Void
    
    init(photoRecord: PhotoRecord, completion: () -> Void) {
        self.photoRecord = photoRecord
        self.completion = completion
    }
    
    override func main() {
    
        if self.cancelled {
            return
        }
        
        dataTask = defaultSession.dataTaskWithURL(self.photoRecord.url) {
            data, response, error in
        
            dispatch_async(dispatch_get_main_queue()) {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            }
            var imageData:NSData = NSData()
            
            if let error = error {
                print(error.localizedDescription)
                self.photoRecord.image = UIImage(named: "Failed")
                self.photoRecord.state = .Failed
                self.completion()
            } else if (response as? NSHTTPURLResponse) != nil {
                
                if self.cancelled {
                    self.dataTask?.cancel()
                    return
                }
                
                imageData = NSData(data: data!)
                
                if imageData.length > 0 {
                    self.photoRecord.image = UIImage(data:imageData)
                    self.photoRecord.state = .Downloaded
                }
                else
                {
                    self.photoRecord.image = UIImage(named: "Failed")
                    self.photoRecord.state = .Failed
                }
                self.completion()
            }
        }
        dataTask?.resume()
        
        if self.cancelled {
            dataTask?.cancel()
            return
        }
    }
}
