
package com.reactlibrary;

import android.content.SharedPreferences;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.bridge.WritableMap;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.util.Map;
import java.util.List;
import java.util.ArrayList;
import java.util.Properties;

import net.lingala.zip4j.ZipFile;
import net.lingala.zip4j.exception.ZipException;
import net.lingala.zip4j.model.FileHeader;

import com.nhi.mhbsdk.MHB;
public class RNLibMhbModule extends ReactContextBaseJavaModule {

  private final ReactApplicationContext reactContext;
  public static MHB mhb;
  public RNLibMhbModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
    try {
        mhb = MHB.configure(getReactApplicationContext(), BuildConfig.API_KEY);
    } catch(Exception e) {
        System.err.println(e);
    }
  }

  @Override
  public String getName() {
    return "RNLibMhb";
  }

  public File fisToFile(FileInputStream fis, String filename) throws IOException {
    File directory = this.reactContext.getFilesDir();
    File outputFile = new File(directory, filename);
    try {
        FileOutputStream fos = new FileOutputStream(outputFile);
        int c;

        while ((c = fis.read()) != -1) {
           fos.write(c);
        }
        fis.close();
        fos.close();
    } catch (FileNotFoundException e) {
        throw e;
    } catch (IOException e) {
        throw e;
    }
    return outputFile;
  }

  public String fileToString(File file) throws IOException {
    int length = (int) file.length();

    byte[] bytes = new byte[length];
    FileInputStream in;
    try {
        in = new FileInputStream(file);
        in.read(bytes);
        in.close();
    } catch (FileNotFoundException e) {
        throw e;
    } catch (IOException e) {
        throw e;
    }
    return new String(bytes);
  }

  public List<String> getFNListFromZipFP(String path) throws ZipException{
    List<String> list = new ArrayList<String>();
    try {
        List<FileHeader> fileHeaders = new ZipFile(path).getFileHeaders();
        for (FileHeader fh : fileHeaders) {
            list.add(fh.getFileName());
        }
    } catch (ZipException e) {
        throw e;
    }
    return list;
  }
  @ReactMethod
  public void startProc(
    final Promise promise
  ) {
      //先清File Tickets, 避免errorCode 101
      SharedPreferences sharedPreferences= this.reactContext.getSharedPreferences(this.reactContext.getPackageName(), android.app.Activity.MODE_PRIVATE);
      SharedPreferences.Editor editor = sharedPreferences.edit();
      Map<String, ?> allKey = sharedPreferences.getAll();
      for (Map.Entry<String, ?> entry : allKey.entrySet()) {
          String key = entry.getKey();
          if (key.startsWith("File_Ticket_")) {
              editor.remove(key);
              editor.apply();
          }
      }

      mhb.startProc(new MHB.StartProcCallback() {
          @Override
          public void onStarProcSuccess() {
              //畫面已render
              System.out.print("onUIProcStart...");
              promise.resolve("OK");
          }

          @Override
          public void onStartProcFailure(String errorCode) {
              promise.reject(errorCode, new Error(errorCode));
          }
      });
  }

  @ReactMethod
  public void fetchData(
      final String startTimestamp,
      final String endTimestamp,
      final Promise promise
  ) {
      //初始化 SharedPreferences
      SharedPreferences sharedPreferences= this.reactContext.getSharedPreferences(this.reactContext.getPackageName(), android.app.Activity.MODE_PRIVATE);
      //以下列出檔案識別碼遞回查尋範例供參考使用
      Map<String, ?> allKey = sharedPreferences.getAll();
      //先iterate一遍檢查有沒有符合的File Ticket
      boolean hasValidFileTicket = false;
      for (Map.Entry<String, ?> entry : allKey.entrySet()) {
          String key = entry.getKey();
          if (key.startsWith("File_Ticket_")) {
              String timeStamp = key.split("ket_")[1];
              if (
                  startTimestamp.compareTo(timeStamp) < 0 && endTimestamp.compareTo(timeStamp) > 0
              ) {
                  hasValidFileTicket = true;
              }
          }
      }
      if (!hasValidFileTicket) {
          promise.reject(BuildConfig.ENOVALFT, new Error(BuildConfig.ENOVALFT));
      }
      for (Map.Entry<String, ?> entry : allKey.entrySet()) {
        String key = entry.getKey();
        if (key.startsWith("File_Ticket_")) {
          //可依已紀錄的起始/結束時間戳記區間內查詢前次 SDK 存入的檔案識別碼
          String timeStamp = key.split("ket_")[1];
          if (
            startTimestamp.compareTo(timeStamp) < 0 &&
            endTimestamp.compareTo(timeStamp) > 0
          ) {
            //此key為要送給fetchData的File Ticket Name.
            //實作取檔 callback
            final WritableMap map = new WritableNativeMap();
            mhb.fetchData(key, new MHB.FetchDataCallback(){
                @Override
                public void onFetchDataSuccess(FileInputStream fis,String serverKey){
                    //解密時，需以[Api_Key][Server_Key]組成字串做為解密金鑰，之後以此解密 金鑰來解密該檔案，並將結果儲存為.json 檔
                    String decryptKey = BuildConfig.API_KEY + serverKey;
                    //保存為zip
                    String filename = "tmp.zip";
                    try {
                        File tmp = fisToFile(fis, filename);
                        String path = tmp.getAbsolutePath();
                        //找出內含檔案名稱List
                        List<String> filenameList = getFNListFromZipFP(path);
                        //使用zip4j unzip, zip4j 定義在LibMHB的android build gradle/dependencies block裡面
                        new ZipFile(path, decryptKey.toCharArray()).extractAll(reactContext.getFilesDir().getAbsolutePath());
                        //把檔案內容read到res變數
                        for(int i = 0; i < filenameList.size(); i++) {
                            File f = new File(reactContext.getFilesDir().getAbsolutePath(), filenameList.get(i));
                            String res = fileToString(f);
                            map.putString(filenameList.get(i), res);
                        } 
                    } catch (Exception e) {
                        promise.reject(e.getMessage(), e.getMessage());
                    }

                    //回傳給JS端
                    promise.resolve(map);
                }
                @Override
                public void onFetchDataFailure(String errorCode){ //回傳 Error Code
                    promise.reject(errorCode, new Error(errorCode));
                }
            });
          }
        }
      }
  }

}