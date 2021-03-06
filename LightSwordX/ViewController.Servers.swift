//
//  UserServersDataSource.swift
//  LightSwordX
//
//  Created by Neko on 12/23/15.
//  Copyright © 2015 Neko. All rights reserved.
//

import Cocoa
import SINQ

extension ViewController: NSTableViewDataSource {
    
    @objc func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return servers.count
    }
    
    @objc func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        return servers[row].address
    }
    
    @IBAction func addServer(sender: NSButton) {
        let server = UserServer()
        server.id = servers.count
        
        if servers.count == 0 {
            server.address = "public1.lightsword.org"
            server.port = 443
        }
        
        servers.append(server)
        serversTableView.reloadData()
        
        selectedRow = servers.count - 1
        let indexSet = NSIndexSet(index: selectedRow)
        serversTableView.selectRowIndexes(indexSet, byExtendingSelection: false)
        
        serverDetailsView.hidden = false
        keepConnectionCheckBox.state = server.keepConnection ? NSOnState : NSOffState
        serverAddressTextField.stringValue = server.address
        serverPortTextField.stringValue = String(server.port)
        cipherAlgorithmComboBox.stringValue = server.cipherAlgorithm
        proxyModeComboBox.selectItemAtIndex(server.proxyMode.rawValue)
        passwordTextField.stringValue = server.password
        listenAddressTextField.stringValue = server.listenAddr
        listenPortTextField.stringValue = String(server.listenPort)
        
        saveServers(true)

        if (server.keepConnection) {
            startServer(server)
        }
    }
    
    @IBAction func removeServer(sender: NSButton) {
        let selectedRow = serversTableView.selectedRow
        if (selectedRow == -1) {
            return
        }
        
        let removed = servers.removeAtIndex(selectedRow)
        serversTableView.reloadData()
        
        if (servers.count == 0) {
            serverDetailsView.hidden = true
        }
        
        saveServers(true)
        stopServer(removed)
    }
    
    @IBAction func setAsDefaultServer(sender: NSButton) {
        let selectedServer = servers[selectedRow]
        
        selectedServer.keepConnection = !selectedServer.keepConnection
        saveServers(true)
        
        if selectedServer.keepConnection {
            startServer(selectedServer)
            return
        }
        
        stopServer(selectedServer)
    }
    
    @IBAction func testConnectionSpeed(sender: NSButton) {
        let ip = servers[selectedRow].address
        let port = servers[selectedRow].port
        
        sender.enabled = false
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let start = StatisticsHelper.getUptimeInMilliseconds()
            
            let con = TCPClient(addr: ip, port: port)
            let (success, _) = con.connect(timeout: 10)
            con.close()
            
            let message = success ? "\(NSLocalizedString("Elapsed Time", comment: "")): \(StatisticsHelper.getUptimeInMilliseconds() - start)ms\n\(ip) ✓" : NSLocalizedString("Connection Timeout", comment: "")
            
            let notification = NSUserNotification()
            notification.title = NSLocalizedString("Test Connection Speed", comment: "")
            notification.informativeText = message
            
            NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(notification)
            
            dispatch_async(dispatch_get_main_queue()) {
                sender.enabled = true
            }
        }
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {

        let info = servers[row]
        selectedRow = row
        
        serverAddressTextField.stringValue = info.address
        serverPortTextField.stringValue = String(info.port)
        cipherAlgorithmComboBox.stringValue = info.cipherAlgorithm
        proxyModeComboBox.selectItemAtIndex(info.proxyMode.rawValue)
        passwordTextField.stringValue = info.password
        keepConnectionCheckBox.state = info.keepConnection ? NSOnState : NSOffState
        listenAddressTextField.stringValue = info.listenAddr
        listenPortTextField.stringValue = String(info.listenPort)
        
        saveServers()
        return true
    }
}

extension ViewController: NSComboBoxDelegate {
    
    override func controlTextDidChange(obj: NSNotification) {
        let textField: NSTextField! = obj.object as? NSTextField
        if textField == nil {
            return
        }
        
        var newValue = textField.stringValue
        let selectedServer = servers[selectedRow]
        
        switch textField.identifier! {
            
        case "serverAddress":
            if (newValue.length == 0) {
                newValue = "127.0.0.1"
            }
            
            selectedServer.address = newValue
            serversTableView.reloadData()
            break
            
        case "serverPort":
            let port = Int(newValue) ?? 8900
            selectedServer.port = port
            serverPortTextField.stringValue = String(port)
            break
            
        case "password":
            if (newValue.length == 0) {
                newValue = "lightsword.neko"
            }
            
            selectedServer.password = newValue
            break
            
        case "listenAddr":
            if (newValue.length == 0) {
                newValue = "127.0.0.1"
            } else if (newValue == "localhost") {
                newValue = "127.0.0.1"
            }
            
            if ipv4Regex.test(newValue) && !["127.0.0.1", "0.0.0.0"].contains(newValue) {
                newValue = "127.0.0.1"
            }
            
            selectedServer.listenAddr = newValue
            listenAddressTextField.stringValue = newValue
            break
            
        case "listenPort":
            let port = Int(newValue) ?? 1080
            selectedServer.listenPort = port
            listenPortTextField.stringValue = String(port)
            break
            
        default:
            return
        }
        
        isDirty = true
    }
    
    override func controlTextDidEndEditing(obj: NSNotification) {
        saveServers()
    }
    
    func comboBoxSelectionDidChange(notification: NSNotification) {
        let comboBox = notification.object as! NSComboBox
        let handlers = [
            "cipherAlgorithm": cipherAlgorithmComboBoxChanged,
            "proxyMode": proxyModeComboBoxChanged
        ]
        
        handlers[comboBox.identifier!]?(comboBox)
    }
    
    private func cipherAlgorithmComboBoxChanged(comboBox: NSComboBox) {
        let methods = ["aes-256-cfb", "aes-192-cfb", "aes-128-cfb"]
        let selectedIndex = comboBox.indexOfSelectedItem
        if (servers[selectedRow].cipherAlgorithm == methods[selectedIndex]) {
            return
        }
        
        servers[selectedRow].cipherAlgorithm = methods[selectedIndex]
        isDirty = true
    }
    
    private func proxyModeComboBoxChanged(comboBox: NSComboBox) {
        let modes = [
            ProxyMode.GLOBAL.rawValue: ProxyMode.GLOBAL,
            ProxyMode.BLACK.rawValue: ProxyMode.BLACK,
            ProxyMode.WHITE.rawValue: ProxyMode.WHITE
        ]
        
        let selectedIndex = comboBox.indexOfSelectedItem
        if let selectedMode = modes[selectedIndex] {
            if (servers[selectedRow].proxyMode == selectedMode) {
                return
            }
            
            servers[selectedRow].proxyMode = selectedMode
            if let running = sinq(self.runningServers).firstOrNil({ s in s.tag as? Int == self.servers[self.selectedRow].id }) {
                running.proxyMode = selectedMode
            }
            isDirty = true
        }
    }
}
