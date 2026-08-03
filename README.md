<img alt="Logo" src="https://upload.cc/i1/2023/06/21/6QwkDb.png" width="128px" height="128px" align="left"/>


# Taiwan Early Earthquake Warning (EEW)
台灣地震速報

## 關於 Taiwan EEW
Taiwan EEW 是一款 iOS 地震速報軟體，提供給您即時的地震資訊，在地震發生的第一時間取得強震即時警報訊息

## 強震即時警報來源
* [交通部中央氣象署](https://www.cwa.gov.tw/)

## 注意事項
1. **地震無法預測**，任何資訊均以中央氣象署(CWA)發布之內容為準。
2. 強震即時警報是利用少數幾個地震測站快速演算之結果，與最終地震報告可能存有若干差異，請理解並謹慎使用。
3. 測報可能誤報，請勿散播資訊，保持公共秩序，避免觸法。
5. 此軟體僅供研究、學術及教育用途（不得營利），若使用則需接受相關風險
7. 本程式**不保證**能永久營運，且非生命安全系統，請勿作為唯一警報來源。
10. 本程式內資源均由網際網路收集而來， 當權利人發現在本程式所提供的內容侵犯其著作權時，**請聯繫我們並請權利人提供相關文件連結**， 本站將依法採取措施移除相關內容或斷開相關鏈接

## 載點
- [iOS App Store](https://apps.apple.com/tw/app/id6450436314)

## 授權 License
本專案為 **原始碼公開（source-available），並非開源授權**。歡迎閱讀程式碼並向本專案提交貢獻，但**不得**將程式碼用於其他專案、再散布、自行發布或商業使用。本 App 另受**新型專利**保護（專利證書號 M664996）。詳見 [LICENSE.md](LICENSE.md)。

This project is **source-available, not open source** — you may read the code and
contribute back here, but may not reuse it in other projects, redistribute it, ship your
own build, or use it commercially. See [LICENSE.md](LICENSE.md).

## 如何編譯 Building
需自備後端帳號 — 本專案的真實憑證不會公開。

1. Clone 後開啟 `TaiwanEEW.xcodeproj`（已無 workspace，依賴皆為 Swift Package Manager）。
2. 建立你自己的設定檔：
   ```bash
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   cp TaiwanEEW/GoogleService-Info.plist.example TaiwanEEW/GoogleService-Info.plist
   ```
   填入你自己的：Apple Developer team ID、Firebase 專案（下載其 `GoogleService-Info.plist`）、
   AWS（SNS platform application + Cognito identity pool 的 region／account id／pool id／app name）、
   以及 RevenueCat 的 public SDK key。兩個真實檔案皆已 gitignore；`AppConfig` 會在執行時讀取，
   缺值即會明確報錯。
3. 編譯執行。若無真實後端，App 仍可編譯啟動，但不會收到即時資料或通知。

CI 使用 `.example` 佔位設定做未簽章的模擬器編譯，因此 PR 不需真實憑證即可通過。

## 如何貢獻 Contributing
歡迎向**本專案**提交貢獻。開啟 Pull Request 即代表你同意 [LICENSE.md](LICENSE.md) 中的貢獻條款
（包含將你的變更授權予本專案）。較大的修改請先開 Issue 討論。

## 安全性回報 Security
請私下回報安全性問題，見 [SECURITY.md](SECURITY.md)，**請勿**以公開 Issue 回報漏洞。

## 特別感謝
- joelin79 `程式開發`
- 地牛 Wake Up `速報提供`
- 中央氣象署 `速報提供`
- NTT DOCOMO `通知音效`

## 聯絡 Contact
taiwan.eew@gmail.com
