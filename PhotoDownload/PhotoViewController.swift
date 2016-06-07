//
//  PhotoViewController.swift
//  PhotoDownload
//
//  Created by David Shore on 2016-06-06.
//  Copyright © 2016 Foggy Media. All rights reserved.
//

import UIKit

let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
var dataTask: NSURLSessionDataTask?

class PhotoViewController: UITableViewController {
    
    var numPhotos = 10000
    var photos = [PhotoRecord]()
    let pendingOperations = PendingOperations()
    
    override func viewDidLoad() {
        generateUrls()
        super.viewDidLoad()
        self.title = "Cat Photos"
        self.tableView.backgroundColor = UIColor.lightGrayColor()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func generateUrls() {
        for i in 1...self.numPhotos {
            let url = NSURL(string:"http://loremflickr.com/320/240?random=\(i)")
            let photoRecord = PhotoRecord(index:i, url:url!)
            self.photos.append(photoRecord)
        }
    }
    
    // #pragma mark - Table view data source
    
    override func tableView(tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
        return self.numPhotos
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("CellIdentifier", forIndexPath: indexPath)
        cell.backgroundColor = UIColor.clearColor()
        
        if cell.accessoryView == nil {
            let indicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
            cell.accessoryView = indicator
        }
        let indicator = cell.accessoryView as! UIActivityIndicatorView
        
        let photoDetails = photos[indexPath.row]
        
        cell.textLabel?.text = String(photoDetails.index)
        
        cell.imageView?.image = photoDetails.image
        cell.imageView?.layer.cornerRadius = 10
        cell.imageView?.layer.borderWidth = 10
        cell.imageView?.layer.borderColor = UIColor.whiteColor().CGColor
        cell.imageView?.clipsToBounds = true
        
        switch (photoDetails.state){
        case .Downloaded:
            indicator.stopAnimating()
        case .Failed:
            indicator.stopAnimating()
            cell.textLabel?.text = "Failed to load"
        case .New:
            indicator.startAnimating()
            if (!tableView.dragging && !tableView.decelerating) {
                self.startDownloadForRecord(photoDetails, indexPath: indexPath)
            }
        }
        
        return cell
    }
    
    func startDownloadForRecord(photoRecord: PhotoRecord, indexPath: NSIndexPath){
        
        if pendingOperations.downloadsInProgress[indexPath] != nil || photoRecord.state == .Downloaded{
            return
        }
        
        let completionBlock = {
            dispatch_async(dispatch_get_main_queue(), {
                self.pendingOperations.downloadsInProgress.removeValueForKey(indexPath)
                self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            })
        }
        
        let downloader = ImageDownloader(photoRecord: photoRecord, completion: completionBlock)
        pendingOperations.downloadsInProgress[indexPath] = downloader
        pendingOperations.downloadQueue.addOperation(downloader)
    }
        
    override func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        suspendAllOperations()
    }
    
    override func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            loadImagesForOnscreenCells()
            resumeAllOperations()
        }
    }
    
    override func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        loadImagesForOnscreenCells()
        resumeAllOperations()
    }
    
    func suspendAllOperations () {
        pendingOperations.downloadQueue.suspended = true
        pendingOperations.filtrationQueue.suspended = true
    }
    
    func resumeAllOperations () {
        pendingOperations.downloadQueue.suspended = false
        pendingOperations.filtrationQueue.suspended = false
    }
    
    func loadImagesForOnscreenCells () {
        
        
        if let pathsArray = tableView.indexPathsForVisibleRows {
            var allPendingOperations = Set(pendingOperations.downloadsInProgress.keys)
            allPendingOperations.unionInPlace(pendingOperations.filtrationsInProgress.keys)
            
            var toBeCancelled = allPendingOperations
            let visiblePaths = Set(pathsArray )
            toBeCancelled.subtractInPlace(visiblePaths)
            
            var toBeStarted = visiblePaths
            toBeStarted.subtractInPlace(allPendingOperations)
            
            for indexPath in toBeCancelled {
                if let pendingDownload = pendingOperations.downloadsInProgress[indexPath] {
                    pendingDownload.cancel()
                }
                pendingOperations.downloadsInProgress.removeValueForKey(indexPath)
                if let pendingFiltration = pendingOperations.filtrationsInProgress[indexPath] {
                    pendingFiltration.cancel()
                }
                pendingOperations.filtrationsInProgress.removeValueForKey(indexPath)
            }
            
            for indexPath in toBeStarted {
                let indexPath = indexPath as NSIndexPath
                let recordToProcess = self.photos[indexPath.row]
                startDownloadForRecord(recordToProcess, indexPath: indexPath)
            }
        }
    }
    
}


