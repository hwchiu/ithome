Day 7 - Rancher 系統管理指南 - RKE Template
=========================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言

前篇文章探討如何透過 Rancher 整合既有的帳號管理系統，同時如何使用 Rancher 提供的 RBAC 來為不同的使用者與群組設定不同的權限。
本文將繼續探討從 Rancher 管理人員角度來看還有哪些功能是執得注意與使用的。



# 系統設定
當今天透過認證與RBAC等功能完成權限控管後，下一個部分要探討的就是團隊的運作流程。
Rancher 作為一個 Kubernetes 管理平台，最大的一個特色就是能夠輕鬆地於各種架構下去安裝一個 Kubernetes 叢集並且管理它，
雖然到現在為止我們還沒有正式的示範如何創建叢集，但是可以先由下圖看一下大概 Rancher 支援哪些不同類型的架構

![](https://i.imgur.com/WIlL788.png)

圖中分成四種不同類型，這四種類型又可以分成兩大類
1. 已經存在的 Kubernetes 叢集，請 Rancher 幫忙管理。
2. 請 Rancher 幫忙創建一個全新的 Kubernetes 叢集並且順便管理。

圖中第一個類型就屬於第一大類，這部分目前整合比較好的有 EKS 與 GKE
這意味者如果你有已經運行的 EKS/GKE 叢集，是有機會讓 Rancher 幫忙管理，讓團隊可以使用一個共同的介面(Rancher)來管理所有的 Kubernetes 叢集。

圖中剩下的(2,3,4)都屬於第二大類，只是這三大類的安裝方式有些不同，分別是
1. 使用者要事先準備好節點， Rancher 會於這些節點上去創建 RKE 叢集
2. Rancher 會透過 API 要求服務供應商去動態創建 VM，並且創建 VM 後會自動的建立起 RKE 叢集
3. 針對部分有提供 Kubernetes 服務的業者， Rancher 也可以直接透過 API 去使用這些 Kubernetes 服務(AKS/EKS/GKE) 並且把 Rancher Agent 安裝進去，接者就可以透過 Rancher 頁面去管理。

這邊點選第三類別的 Azure 作為一個範例來看一下，透過 RKE 安裝 Kubernetes 會有什麼樣的資訊需要填寫
![](https://i.imgur.com/rmXfoZN.png)

首先上圖看到關於 Cluster Options 下有四大項，這四大項裡面都問題都跟 Kubernetes 叢集，更精準的說是 RKE 有關

![](https://i.imgur.com/TWYgcWP.png)

首先第一個類別就是 Kubernetes 的基本資訊，包含了
1. RKE 的版本，版本跟 Kubernetes 版本是一致走向的。
2. CNI 使用哪套，目前有 Flannel, Calico 以及 Canal。
3. CNI 需不需要額外設定 MTU
4. 該環境要不要啟用一些 Cloud Provider 的功能，要的話還要填入一些機密資訊

![](https://i.imgur.com/ZmfmDd6.png)

往下看還有更多選項可以用，譬如該 RKE 創建時，所有用到的 Registry 是否要從一個 Private Registry 來抓取，這功能對某些團隊來說會非常有用，因為部分團隊會希望用到的所有 Container Image 都要有一份備份以免哪天 quay, docker.io 等出現問題導致整個安裝失敗。

因此如果團隊事先將 RKE 用到的 Container Image 都複製一份到自己團隊的 private container registry 的話，就可以打開這個功能讓 Rancher 知道去哪邊抓 Image。

後續則是更多的進階選項，譬如説
1. RKE 中預設要不要安裝 Nginx 作為 Ingress Controller?
2. 系統中的 NodePort 用到的範圍多少?
3. 是否要導入一組預設的 PodSecurityPolicy 來限制叢集內所有Pod的安全性規則
4. Docker 有沒有特別指定的版本
5. etcd 要如何備份，要本地備份還是要透過 s3 將 etcd 上傳
6. 要不要定期透過 CIS 進行安全性相關的掃描？

可以看到上述的設定其實滿多的，如果每次創建一個叢集都要一直輸入一樣的資訊難免會出錯，同時有一些設定 IT 人員會有不同的顧慮與要求。為了讓團隊內的所有 RKE 叢集都可以符合團隊的需求，Rancher 就有提供基於全面系統地 RKE Template.

# RKE Template
RKE Template 的概念就是讓系統人員與安全人員針對需求去規範 Kubernetes 的要求，所有使用者都必須要使用這個事先創立的 RKE Template 來創立 RKE 叢集。
透過這個方式有幾個好處
1. 使用者創立的所有 RKE 叢集都可以符合團隊需求
2. 使用者使用 Template 去創建 RKE 的話就可以省略那些不確定該怎麼填寫的資訊，簡化整個創造步驟
3. Template 本身也是一個物件，所以 Rancher 前述提到的權限控管就可以針對 Template 去進行設定，譬如 DEV/QA 人員只能使用已經創建的 Template 來創立 RKE 叢集

以下是一些常見使用 RKE Template 的使用範例
1. 系統管理人員強迫要求所有新創立的 RKE 叢集都只能使用事先創立好的 RKE Template
2. 系統管理人員創建不同限制的 RKE Template，針對不同的使用者與群組給予不同的 RKE Template
3. RKE Template 本身是有版本的概念，所以如果今天公司資安團隊希望調整資安方面的使用，只需要更新 RKE Template 即可。所有使用到的使用者再進行 RKE Template 更新的動作即可

此外 RKE Template 內所有的設定都有一個覆蓋的概念存在，創建該 RKE Template 時可以決定該設定是否能夠被使用者覆蓋，這對於某些很重要的設定來說非常有用。

以下是一個 RKE Template 創建的方式 (Tools->Template 進入)

![](https://i.imgur.com/39a4G9w.png)

圖中最上方代表的是該 RKE Template 的名稱與版本，同時每個 RKE Template 有很多個版本，更新的時候可以選擇當前版本是否要作為當前 Template 的預設版本。

中間部分則是到底誰可以使用這個 RKE Template，裡面可以針對使用者與群組去設定身份總共分成兩個身份，分別是 User 以及 Owner。

1. Owner: 符合這個身份的使用者可以執行 更新/刪除/分享 這些關於 RKE Template 的設定，概念來說就是這個 RKE Template 的擁有者。
2. User: 簡單來說就是使用這個 RKE Template 的人，使用者再創建 RKE 叢集的時候可以從這些 Template 中去選擇想要使用的 Template。


最下面的部分跟前述探討安裝 RKE 要使用的權限都差不多，唯一要注意的是每個選項旁邊都有一個 "Allow user override?" 的選項，只要該選項沒有打開，那使用者(User)使用時就不能覆蓋這些設定。

# 實驗
接下來針對 RKE Template 進行一個實驗，該實驗想到達到以下目的。

1. IT 管理員創建一個 RKE Template，並且設定 DEV 群組的使用者可以使用
2. DEV 群組的使用者可以創建 Cluster，但是被強迫只能使用 RKE Template 創造，並不是自己填寫任何資訊。

為了達到這個目的，我們有三個步驟要做，分別是
1. 透過 Rancher 的設定，強迫所有創建 RKE 叢集一定要使用 RKE Template，不得自行填寫資訊。
2. 創造一個 RKE Template，並且設定 DEV 群組的人是使用者，同時該 RKE Template 內讓 Kubernetes 版本是一個可以被使用者覆蓋的設定。
3. 登入 DEV 使用者嘗試創造 RKE 叢集，看看上述設定是否可以達到我們的需求。


首先到首頁上方的 Setting，進去後搜尋 template-enforcement 就會找到類似下列這張圖片的樣子
![](https://i.imgur.com/MIasPAC.png)

預設狀況下，該設定是 False，透過旁邊的選項把它改成 True，該選項一打開後，所有新的 RKE 叢集都只能透過 RKE Template 來創建。

接者用 IT 人員登入作為一個系統管理員，創建一個如下的 RKE Template

![](https://i.imgur.com/O94oboJ.png)

中間部分表示任何屬於 DEV 群組的人都可以使用這個 RKE Template，同時該 RKE Template 允許使用者去修改 Kubernetes 版本，其餘部分都採用 RKE Template 的設定。

最後用 DEV 的身份登入 Rancher 並且嘗試創造一個 RKE 叢集。
從下述畫面可以觀察到一些變化

![](https://i.imgur.com/pgtPTNz.png)

1. RKE Template 相關選項 "Use an existing RKE Template and revision" 被強迫打勾，這意味使用者一定要使用 RKE Template
2. 選擇了前述創造的 RKE Template 後就可以看到之前創造好的設定
3. 只有 Kubernetes 的版本是可以調整的，其餘部分如 CNI 等都是不能選擇的。

註: 當透過 RKE Template 賦予權限給予 DEV 群組後， 群組那邊的設定會被修改，這時候的 DEV 群組會被自動加上 "Creating new Clusters" 這個權限，範例如下

![](https://i.imgur.com/za6r1wr.png)

透過上述的範例操作成功地達到預期目標的設定，讓團隊內所有需要創建 RKE 叢集的使用者都必須要使用事先創造好的 RKE Template 來確保所有叢集都可以符合團隊內的需求。