Day 14 - CD 與 Kubernetes 的整合
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



上篇文章中我們探討了 CD 過程的各種議題，而本篇文章則會開始探討 CD 與 Kubernetes 的部署整合

這邊要特別強調的是 CI 跟 CD 兩件事情本來就不需要一定在一起，最簡單的情況下就是將 CI 與 CD 兩個步驟整合到同一個 pipeline 系統

上。但是有時候會希望透過手動部署，但是部署中間的過程希望自動化，所以會透過手動觸發 CD 的流程來達成自動部署。



此外， CI 與 CD 使用的流水線系統也不一定要用同一套系統，就如同前一篇文章提到專門針對 CD 這個步驟去列出相關的工具。

以下將會列出四種用法，這四種用法可以分成兩大類

1. Push Mode
2. Pull Mode

其中 Push Mode 的概念是由我們的 CD Pipeline 主動將新的應用程式推到遠方的 Kubernetes Cluster 內

然而 Pull Mode 的概念是由 Kuberentes 主動去更新，藉由監聽遠方目標的變化來確保是否要自動更新版本



# CI/CD pipeline (Push)

![](https://i.imgur.com/Qup5mjg.jpg)



第一個是我認為最直接且直觀，我們把 CI/CD 兩個流程都放到同一個 Pipeline 系統內，其設計上也相對簡單

1. 當 CI 流程結束後，接下來就跑下個步驟，這個步驟包含
   a. 準備相關執行檔案
   b. 透過相關工具部署到遠方的 Kubernetes
2. 這種架構下，因為要存取遠方的 kubernetes，也是會需要將 KUBECONFIG 這個檔案放到 Pipeline 系統中，所以使用上要特別注意
   安全性的問題，避免別人存取到這個 KUBECONFIG，否則攻擊者可以控制你的 Kubernetes 叢集



# 人員觸發 (Push)

![](https://i.imgur.com/GMzaUxw.jpg)



這種架構下，我們將 CI pipeline 與 CD pipeline 給分開執行，這兩套 pipeline 要不要使用同一套系統無所謂，至少 Job 是分開的。

叢集管理員或是其他有權限的人可以透過直接執行當前的 `CD pipeline` 來觸發自動化部屬。這種的好處在於，對於一些正式的生產環境

下，太過於自動的部署不一定是完全好的，有時候會需要一些人為介入的確認，確認一切都沒有問題後才會繼續執行自動部署。

因此這個架構下可能的一個流程是

1. 透過 CI pipeline 通過測試以及產生出最後要使用的 Image 檔案
2. 部署團隊與 PM 等經過確認，公告更新時間後在手動觸發自動部署的工作來完成部署
3. 如同前面部署，這邊也會需要將 Kubernetes 存取所需要的 KUBECONFIG 放到 CD pipeline 內，所以也是有安全性的問題需要注意



# Container Image 觸發 (Push)

![](https://i.imgur.com/BTyDW7b.jpg)



這是另外一種不同的架構，我們將人為觸發的部分提供了一個新的選擇，當 Container Registry 本身發現有新版本的 Container Image 更新時，會透過不同的方式通知遠方的 CD pipeline 去觸發自動更新。

這個使用方法會依賴你使用的 Container Registry 是否有支援這種的架構，譬如 Harbor 這個開源專案就有支援，當 image 更新後可以透過 webhook 的方式將訊息打到遠方。而遠方的 CD pipeline 如果也有這種機制可以透過 webhook 來觸發的話，就可以實作上面的機制。

由於是透過 container registry 所觸發的工作，所以這種架構可以支援更多的觸發方式，譬如管理員今天緊急需求，手動推動新版的 Container Image 到遠方 Registry，這樣也能夠觸發

因為跟前述架構完全類似，所以 KUBECONFIG 也是會放到環境之中，必須要有安全性的考量。

# Pull Mode

![](https://i.imgur.com/b5l63Om.jpg)



最後我們來看另外一種不同的架構，這種架構下我們就不會從 Pipeline 系統中主動地將新版應用程式推到 Kubernetes 中，相反的是我們的 Kubernetes 內會有一個 Controller，這個 Controller 會自己去判斷是否要更新這些應用程式，譬如說當遠方的 Contaienr Image 有新版更新時，就會自動抓取新的 Image 並且更新到系統之中。

這種架構下，我們不需要一個 CD Piepline 來維護這些事情，此外，因為沒有主動與 Kubernetes 溝通的需求，所以也不需要把 KUBECONFIG 給放到外部系統 (CD Pipeline) 中，算是減少了一個可能的安全性隱憂。

當然這種架構下，整個部署的流程都必須依賴 Controller 的邏輯來處理，如果今天有任何客製化的需求就變成全部都讓 Controller 來處理，可能要自行修改開源軟體，或是依賴對方更新，相較於完全使用 CD Pipeline 處理來說，彈性會比較低，擴充性也比較低，同時整個架構的極限都會被侷限在 Controller 本身的能力。



最後要說的是，以上介紹的架構沒有一個是完美的，都只是一個參考架構，真正適合的架構還是取決於使用者團隊，透過理解不同部署方

式所帶來的優缺點，評估哪些優勢我團隊需要，哪些缺點是團隊可以接受，不可以接受，最後綜合評量後取捨出一套適合團隊工作的方式。

