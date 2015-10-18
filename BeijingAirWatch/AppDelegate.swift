//
//  AppDelegate.swift
//  BeijingAirWatch
//
//  Created by Di Wu on 10/15/15.
//  Copyright © 2015 Beijing Air Watch. All rights reserved.
//

import UIKit
import WatchConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WCSessionDelegate {

    var window: UIWindow?

    private var isLoadingData: Bool = false
    private var aqi: Int = -1
    private var concentration: Double = -1.0
    private var time: String? = "Invalid"
    var wcSession: WCSession?
    private var session: NSURLSession?
    private var bgTaskID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    private var task: NSURLSessionDataTask?
    private var gregorianCal: NSCalendar?
    
    func getLatestDataHour() -> Int? {
        if time != nil && time?.containsString(",") == true {
            let isAm = (time?.componentsSeparatedByString(" ")[4] == "AM")
            if isAm == true {
                return Int((time?.componentsSeparatedByString(" ")[3])!)
            } else {
                return Int((time?.componentsSeparatedByString(" ")[3])!)! + 12
            }
        } else {
            return nil
        }
    }
    
    func getCurrentHour() -> Int? {
        let date: NSDate = NSDate.init()
        if gregorianCal == nil {
            gregorianCal = NSCalendar.init(calendarIdentifier: NSCalendarIdentifierGregorian)
        }
        let comps: NSDateComponents? = gregorianCal?.componentsInTimeZone(NSTimeZone.init(abbreviation: "HKT")!, fromDate: date)
        return comps?.hour
    }
    
    func alreadyFetchedLatestData() -> Bool {
        let currHour: Int? = getCurrentHour()
        let dataHour: Int? = getLatestDataHour()
        if currHour != nil && dataHour != nil && currHour! == dataHour! {
            self.sendLocalNotif("当前时间:\(currHour),数据时间:\(dataHour).暂停刷新", badge: -1)
            return true
        } else {
            self.sendLocalNotif("当前时间:\(currHour),数据时间:\(dataHour).继续刷新", badge: -1)
            return false
        }
    }
    
    func registerBackgroundVOIPCallback() {
        let ret = UIApplication.sharedApplication().setKeepAliveTimeout(600) { () -> Void in
            NSLog("voip called...")
            self.properlyEndBgTaskIfThereIsOne()
            if self.alreadyFetchedLatestData() == true {
                return
            }
            self.bgTaskID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
                self.properlyEndBgTaskIfThereIsOne()
            })
//            let interval: dispatch_time_t = UInt64(TIME_OUT_LIMIT_IOS) * NSEC_PER_SEC
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(interval)), dispatch_get_main_queue(), { () -> Void in
                self.fetchNewData()
//            })
        }
        self.sendLocalNotif("\(ret) 尝试注册VOIP回调", badge: -1)
    }
    
    func startWCSession() {
        if (WCSession.isSupported() && wcSession == nil) {
            wcSession = WCSession.defaultSession()
            wcSession?.delegate = self
            wcSession?.activateSession()
        } else if (WCSession.isSupported() && wcSession != nil) {
            wcSession?.activateSession()
        }
    }
    
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
        if message["selected_city"] != nil {
            let city: String = message["selected_city"] as! String
            NSUserDefaults.standardUserDefaults().setObject(city, forKey: "selected_city")
            NSUserDefaults.standardUserDefaults().synchronize()
            print("ios app sourcel url: \(sourceDescription())")
            sendLocalNotif("更新城市为:\(selectedCity())", badge: -1)
        }
        print("did receive wc session msg (ios app side): \(message)")
        replyHandler(["xxx":"xxx"])
        registerBackgroundVOIPCallback()
    }
    
    /*
    func session(session: WCSession, didReceiveUserInfo userInfo: [String : AnyObject]) {
        if userInfo["selected_city"] != nil {
            let city: String = userInfo["selected_city"] as! String
            NSUserDefaults.standardUserDefaults().setObject(city, forKey: "selected_city")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
        print("did receive info (ios app side): \(userInfo)")
        print("ios app sourcel url: \(sourceDescription())")
    }
*/
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)

        startWCSession()
        
        if NSUserDefaults.standardUserDefaults().integerForKey("a") > 1 {
            aqi = NSUserDefaults.standardUserDefaults().integerForKey("a")
        }
        if NSUserDefaults.standardUserDefaults().doubleForKey("c") > 1.0 {
            concentration = NSUserDefaults.standardUserDefaults().doubleForKey("c")
        }
        if NSUserDefaults.standardUserDefaults().stringForKey("t") != nil {
            time = NSUserDefaults.standardUserDefaults().stringForKey("t")
        }
        
        let settings = UIUserNotificationSettings(forTypes: [UIUserNotificationType.Alert, UIUserNotificationType.Badge,UIUserNotificationType.Sound], categories: nil)
        application.registerUserNotificationSettings(settings)

        return true
    }
    
    /*
    func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {

        completionHandler(.NoData)

        print("called... complication enabled = \(wcSession?.complicationEnabled)");
        if wcSession?.complicationEnabled == true {
            test(completionHandler)
        } else {
            completionHandler(.NoData)
        }

    }
*/
    
    func fetchNewData() {
        print("called... complication enabled = \(wcSession?.complicationEnabled)");
        startWCSession()
        
        test(nil)

        /*
        if wcSession?.complicationEnabled == true {
            test(nil)
        } else {
            sendLocalNotif("\(selectedCity()):未激活，不刷新", badge: -1)
            properlyEndBgTaskIfThereIsOne()
        }
*/
    }
    
    func properlyEndBgTaskIfThereIsOne() {
        if self.bgTaskID != UIBackgroundTaskInvalid {
            UIApplication.sharedApplication().endBackgroundTask(self.bgTaskID)
            self.bgTaskID = UIBackgroundTaskInvalid
        }
    }
    
    func sendLocalNotif(text: String, badge: Int) {
        let notif = UILocalNotification()
        notif.fireDate = NSDate.init(timeIntervalSinceNow: 1)
        notif.alertBody = text
        notif.timeZone = NSTimeZone.defaultTimeZone()
        notif.soundName = UILocalNotificationDefaultSoundName
        if badge > 0 {
            notif.applicationIconBadgeNumber = badge
        }
        UIApplication.sharedApplication().scheduleLocalNotification(notif)
    }
    
    func test(completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        sendLocalNotif("\(selectedCity()):尝试获取数据", badge: -1)
        let request = createRequest()
        if session == nil {
            session = sharedSessionForIOS()
        }
        self.task?.cancel()
        self.task = createHttpGetDataTask(session, request: request){
            (data, error) -> Void in
            if error != nil {
                print(error)
                self.sendLocalNotif("\(selectedCity()):获取数据出错", badge: -1)
            } else {
                let tmpAQI = parseAQI(data)
                let tmpConcentration = parseConcentration(data)
                let tmpTime = parseTime(data)
                if tmpAQI > 1 && tmpConcentration > 1.0 && (tmpAQI != self.aqi || tmpConcentration != self.concentration || tmpTime != self.time) {
                    self.aqi = tmpAQI
                    self.concentration = tmpConcentration
                    self.time = tmpTime
                    NSUserDefaults.standardUserDefaults().setInteger(self.aqi, forKey: "a")
                    NSUserDefaults.standardUserDefaults().setDouble(self.concentration, forKey: "c")
                    NSUserDefaults.standardUserDefaults().setObject(self.time, forKey: "t")
                    NSUserDefaults.standardUserDefaults().synchronize()
                    print("data loaded: api = \(self.aqi), concentration = \(self.concentration), time = \(tmpTime)")
                    self.wcSession?.transferCurrentComplicationUserInfo(["a": tmpAQI, "c": tmpConcentration, "t": tmpTime])
                    self.sendLocalNotif("\(selectedCity()):解析得到新数据，刷新手表", badge: tmpAQI)
                    completionHandler?(.NewData)
                    self.properlyEndBgTaskIfThereIsOne()
                    return
                }
                if tmpAQI < 1 || tmpConcentration < 1 {
                    self.sendLocalNotif("\(selectedCity()):解析数据出错", badge: -1)
                }
                if tmpAQI == self.aqi && tmpConcentration == self.concentration {
                    self.sendLocalNotif("\(selectedCity()):数据未变", badge: -1)
                }
                self.sendLocalNotif("\(selectedCity()):网络请求因故终止", badge: -1)
            }
            self.isLoadingData = false
            completionHandler?(.NoData)
            self.properlyEndBgTaskIfThereIsOne()
        }
        self.task?.resume()
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        print("ios app did become active")
        registerBackgroundVOIPCallback()
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

