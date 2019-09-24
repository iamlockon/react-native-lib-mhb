
# 健保署健康存摺React Native原生模組

## 適用SDK版本
Android 1.0.3 
iOS 2.0.3

## Dependencies
zip4j (Android Zip/Unzip用)
SSZipArchive (iOS Zip/Unzip用)
Alamofire(iOS), dexguard-runtime(Android), 健康存摺本身
## Getting started

`$ npm install react-native-lib-mhb --save`

### Mostly automatic installation

`$ react-native link react-native-lib-mhb`

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-lib-mhb` and add `RNLibMhb.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNLibMhb.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainApplication.java`
  - Add `import com.reactlibrary.RNLibMhbPackage;` to the imports at the top of the file
  - Add `new RNLibMhbPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-lib-mhb'
  	project(':react-native-lib-mhb').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-lib-mhb/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-lib-mhb')
  	```

## Usage
```javascript
import RNLibMhb from 'react-native-lib-mhb'; //Android
import {NativeModules} from 'react-native'; 
const {MhbSdk} = NativeModules; // iOS

/*
 * 用來啟動健保快易通UI
 * Return: Promise<void> 
 * Arguments: null
 */
RNLibMhb.startProc()
/*
 * 用來以start_time, end_time選擇SharedPreferences(Android)/UserDefaults(iOS)裡面的File Ticket，
 * 並用選中的File Ticket向SDK取得健康存摺資料
 * Return: Promise<Object> 
 * Arguments: start_time: String, end_time: String
 */
RNLibMhb.fetchData(start_time, end_time)
```
  
## Example Code
```javascript

//啟動健保快易通UI
this.setState({startTime: new Date().getTime().toString()});
try {
    if (MhbSdk) { // iOS
        await MhbSdk.startProc();
    }
    if (RNLibMhb) { // Android
        await RNLibMhb.startProc();
    }
} catch (e) {
    console.log(e.code);
}
//取檔
const {startTime} = this.state;
const endTime = new Date().getTime().toString();
if (!startTime) console.error("缺少startTime!!");
try {
    let response;
    if (MhbSdk) { //iOS
        response = await MhbSdk.fetchData(startTime, endTime);
        response = JSON.parse(response);
    }
    if (RNLibMhb) { //Android
        response = await RNLibMhb.fetchData(startTime, endTime); //should be raw json string.
        const [rawdata] = Object.values(response);
        response = JSON.parse(rawdata.trim());
    }
} catch (e) {
    if (e.code === "NO_VALID_FILE_TICKET") {
        //沒有在start_time與end_time之間的File Ticket.
    } else if (e.code === "101") {
        //處理錯誤
    } else if (e.code === "204") {
        //同上
    }
}
```

## Note

1. Android side有用gradle.properties來存放API_KEY等constant，然後用app level build.gradle的buildTypes去拉到BuildConfig裡面，可參考: https://www.jianshu.com/p/274c9d95cf76