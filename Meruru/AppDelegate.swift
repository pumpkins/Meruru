//
//  AppDelegate.swift
//  Meruru
//
//  Created by castaneai on 2019/04/06.
//  Copyright © 2019 castaneai. All rights reserved.
//

import Cocoa
import VLCKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSComboBoxDelegate {
    
    @IBOutlet weak var window: NSWindow!
    
    var mirakurun: MirakurunAPI!
    
    var statusTextField: NSTextField!
    var servicesComboBox: NSComboBox!
    
    var player: VLCMediaPlayer!
    var services: [Service] = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initUI()
        
        guard let mirakurunPath = AppConfig.shared.currentData?.mirakurunPath ?? promptMirakurunPath() else {
            showErrorAndQuit(error: NSError(domain: "invalid mirakurun path", code: 0))
            return
        }

        mirakurun = MirakurunAPI(baseURL: URL(string: mirakurunPath + "/api")!)
        mirakurun.fetchStatus { result in
            switch result {
            case .success(let status):
                AppConfig.shared.currentData?.mirakurunPath = mirakurunPath
                DispatchQueue.main.async {
                    self.statusTextField.stringValue = "Mirakurun: v" + status.version
                }
                self.mirakurun.fetchServices { result in
                    switch result {
                    case .success(let services):
                        self.services = services
                        DispatchQueue.main.async {
                            self.servicesComboBox.addItems(withObjectValues: services.map { $0.name })
                            self.servicesComboBox.selectItem(at: 0)
                        }
                    case .failure(let error):
                        self.showErrorAndQuit(error: error)
                    }
                }
            case .failure(let error):
                debugPrint(error)
                self.showErrorAndQuit(error: NSError(domain: "failed to get Mirakurun's status (mirakurunPath: \(mirakurunPath))", code: 0))
            }
        }
    }
    
    func showErrorAndQuit(error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
        NSApplication.shared.terminate(self)
    }
    
    func initUI() {
        statusTextField = NSTextField(frame: NSRect(x: 250, y: 0, width: 200, height: 24))
        statusTextField.drawsBackground = false
        statusTextField.isBordered = false
        statusTextField.isEditable = false
        statusTextField.stringValue = "Mirakurun: connecting..."
        window.contentView?.addSubview(statusTextField)
        
        servicesComboBox = NSComboBox(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        servicesComboBox.delegate = self
        window.contentView?.addSubview(servicesComboBox)
        
        let videoView = VLCVideoView(frame: NSRect(x: 0, y: 24, width: window.frame.width, height: window.frame.height - 24))
        videoView.autoresizingMask = [.width, .height]
        videoView.fillScreen = true
        videoView.backColor = NSColor.red
        window.contentView?.addSubview(videoView)
        
        player = VLCMediaPlayer(videoView: videoView)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func promptMirakurunPath() -> Optional<String> {
        let alert = NSAlert()
        alert.messageText = "Please input path of Mirakurun (e.g, http://192.168.x.x:40772)"
        alert.alertStyle = .informational
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = tf
        alert.addButton(withTitle: "OK")
        let res = alert.runModal()
        if res == .alertFirstButtonReturn {
            return tf.stringValue
        }
        return nil
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        let selectedService = services[servicesComboBox.indexOfSelectedItem]
        debugPrint(selectedService)
        player.stop()
        let media = VLCMedia(url: mirakurun.getStreamURL(service: selectedService))
        player.media = media
        player.play()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        player?.stop()
        do {
            try AppConfig.shared.save()
        } catch let err {
            let alert = NSAlert(error: err)
            alert.runModal()
        }
    }
}

