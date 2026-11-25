//
//  main.swift
//  touchbar-browser-helper
//
//  Created by Viktor Strate Kløvedal on 07/11/2020.
//

import Cocoa
import Darwin

signal(SIGPIPE, SIG_IGN)

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate

app.run()
