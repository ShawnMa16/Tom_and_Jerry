# Tom_and_Jerry
This is an AR multiuser game based on ARKit 2 and Multipeerconnectivity.

It allow users to controll the characters to interact with.

Also see a simplified version [here](https://github.com/ShawnMa16/iOS_ARkit2_Multiusers)
![](Tom_and_Jerry.gif)


## Prerequisites
* Two iOS 12 devices in the same Wi-Fi
* Xcode 10

## Installing
* CocoaPods
```
$ sudo gem install cocoapods
```
* SnapKit
```
$ cd Tom_and_Jerry-master
$ pod install
```
## Running
The better you match the AR worldmap, the better lighting shadow you will get

### Host the game with one device

1. Find and scan the ground plane

2. Wait for the ARKit status label to show "Maped"

**DO NOT ADD GAME OBJECT FOR NOW**

### Join the game 

1. Find and scan the same ground plane

2. Wait for the ARKit status label to show "Maped" on the second device

### Place the game objects on all devices
* Game objects will be placed on the center of the yellow Four Square
* Don't place objects too close when beginning

## Features 
* Multiuser
* Lighting in SceneKit
* Joystick
* Animation in SceneKit with [Mixamo](https://www.mixamo.com)


## Authors

* **Shawn Ma**  - [portfolio](https://xiaoma.space)
* **Yiyao Nie**
