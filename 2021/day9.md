Day 9 - Rancher 叢集管理指南 - 架設 K8s(下)
========================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言

前篇文章探討了 Rancher 其中一種安裝 Kubernetes(RKE) 的方式，該方式會先透過 API 請求 Service Provider(Azure) 幫忙創建相關的 VM，接者於這些 VM 上面搭建一個符合需求的 RKE 叢集。

為了讓簡化整個設定過程，我們學到了如何透過 Cloud Credential 以及 Node Template 兩種方式來事先解決繁瑣的操作，接者真正創建 RKE 叢集時則使用 Node Template 與 RKE Template 兩個方式讓整個創建過程變得很簡單，不需要填入太多資訊，只需要利用這兩個 Template 的內容加上自行設計要多少個 VM 節點，這些節點要屬於什麼身份以及該叢集最後要給哪個使用者/群組使用即可。

本篇文章將繼續把剩下兩種安裝方式給走一遍，三種安裝方式都玩過後會對 Rancher 的能力有更多的瞭解，同時也會為之後 Rancher Fleet 的使用先行搭建環境。

之前探討使用者管理與部署時於系統中創建了三種不同群組的使用者，包含了 DEV, QA 以及 IT。而這兩個章節探討的三種部署方式其實剛好就會剛好拿來搭配這些不同的使用者，期望透過不同方式搭造出來的三套 RKE 叢集本身權限控管上就有不同的設定。

目標狀況是三套叢集擁有的權限如下
1. DEV 叢集 -> IT & DEV 可以使用
2. QA 叢集 -> IT & QA 可以使用
3. IT 叢集 -> IT 可以使用

基本上因為 IT 群組的使用者會被視為系統管理員，因此本身就有能力可以存取其他叢集，所以創建時只需要針對 DEV 以及 QA 兩個叢集去設計。
實務上到底會如何設計取決於團隊人數與分工狀況，這邊的設計單純只是一個權限控管的示範，並不代表真實應用就需要這樣做。


# Existing Cluster

前篇文章探討的是動態創建 VM 並且於搭建 RKE 叢集，與之相反的另外一種架設方式就是於一個已經存在的節點上去搭建 RKE 叢集。

這個安裝方式大部分都會用於地端環境，部分使用者的地端環境沒有 vSphere/Openstack 等專案可以幫忙自動創建 VM，這種情況下一台又一台的 bare-metal 機器就會採用這種方式來安裝。

我先於我的 Azure 環境中創建兩個 VM，想要用這兩個 VM 搭建一個屬於 QA 群組使用者的 RKE 叢集

![](https://i.imgur.com/S8sLUOQ.png)

上圖中標示為 qa-rke{1,2} 的機器就是為了這個情況手動創建起來的。
準備好了相關 VM 之後，就切換到 Rancher 的介面去創建一個 RKE 叢集。

![](https://i.imgur.com/C81donD.png)

介面中選擇非常簡單，只有一個 Existing Nodes 可以選擇，點進去後可以看到類似下方頁面

![](https://i.imgur.com/GZNh44H.png)

與之前的安裝方式不同，這邊沒有所謂的 Node Pool 的概念，畢竟是要安裝到一個已存在的節點，所以沒有 Node Pool 需要設定也是合理的。
這邊我將該叢集分配給 QA 群組的使用者，令其為 Owner，擁有整個叢集的管理權限，同時下方繼續使用先前設定好的 RKE 叢集。

一切完畢後點選 Next 到下一個頁面，該頁面才是真正安裝的方式

![](https://i.imgur.com/XX2MzK2.png)

該介面有三個地方要注意
1. 最下方是安裝的指令，實際上是到該節點上透過 Docker 的方式去運行一個 Rancher Agent 的容器，該容器會想辦法跟安裝 RKE 並且跟遠方的 Rancher 註冊以方便被管理
2. 最上方兩個區塊都是用來調整該節點到底要於 RKE 叢集中扮演什麼角色，這些變動都會影響下方 Docker 指令
3. 就如同先前安裝一樣，這邊也需要選擇當前節點到底要當 ETCD/Control Plane/Worker 等
4. Show advanced options 選項打開可以看到的是 Labels/Taints 等相關設定

我透過上述介面設定了兩種介面，分別是
1. 單純的 worker
2. 全包，同時兼任 worker/etcd/controlplane

接者複製這些 docker 指令到事先準備好的 VM 上去執行

![](https://i.imgur.com/NVheVRv.png)



到兩個機器上貼上指令後，就慢慢的等 Rancher 將整個 RKE 架設起來。

可以看到透過這種方式創建的叢集，其 Provider 會被設定成 Custom，跟之前創立的 Azure 有所需別。

![](https://i.imgur.com/VQ1uZpg.png)

點選該叢集名稱進去後，切換到節點區塊可以看到兩台機器正在建立中，這邊要特別注意，節點的 hostname 必須要不同，如果 hostname 一致的話會讓 Rancher 搞混，所以使用 bare-metal 機器建立時千萬要注意 hostname 不要衝突。

![](https://i.imgur.com/hUDKW6n.png)

一切結束後，就可以於最外層的介面看到三個已經建立的叢集，一個是用來維護 Rancher 本身，兩個則是給不同群組的 RKE 叢集。

![](https://i.imgur.com/YKMLAu6.png)

# Managed Kubernetes Service
接者來看最後一個安裝方式，這個方式想要直接透過 Rancher 去創造 AKS 這種 Kubernetes 服務，並且安裝完畢後將 Rancher 的相關服務部署進去，這樣 Rancher 才有辦法控管這類型的叢集。

回到叢集安裝畫面，這時候針對最下面的服務，預設情況下這邊的選擇比較少，但是如果有到 Tools->Driver 去將 Cluster Driver 給打開的話，這邊就會出現更多的 Service Provider 可以選擇。

![](https://i.imgur.com/l7gw88c.png)

根據我的環境，我選擇了 Azure AKS，點選進去後就可以看到如下圖的設定頁面

![](https://i.imgur.com/QGWJ6AZ.png)

進到畫面後的第一個選項就是 Azure 相關的認證資訊，這邊我認為是 Rancher 還沒有做得很完善的部分，先前創建 Node Template 時使用的 Cloud Credential 這邊沒有辦法二次使用，變成每次創建一個 AKS 叢集時都要重新輸入一次相關的資訊，這部分我認為還是有點不方便。
不過仔細觀察需要的資訊有些許不同，創造 Node Template 時不需要 Tenant ID，但是使用 AKS 卻需要。有可能因為這些設定不同導致 Cloud Credential 這邊就沒有辦法很輕鬆的共用。
不過作為使用者也是希望未來能夠簡化這些操作，否則每次創建都要翻找算是有點麻煩。

![](https://i.imgur.com/KV1GL0D.png)

通過存取資訊驗證後，就可以來到設定頁面，因為這個是 AKS 叢集，因此並沒有辦法使用 RKE Template 來客製化內容，所有的設定內容都是跟 AKS 有關，因此不同的 K8S 服務提供的操作選項就不同。

![](https://i.imgur.com/zSEEaSJ.png)

一切準備就緒後，就可以看到最外層的叢集列表多出了一個全新的 Kubernetes 叢集，其 Provider 則是 Azure AKS。

![](https://i.imgur.com/HEIW0uD.png)

此時觀看 Azure AKS 的頁面可以發現到也多了一個正在創建中的 AKS 叢集，名稱 c-xxxx 就是 Rancher 創造的證明，每個 Rancher 管理的 Kubernetes 叢集都會有一個內部ID，都是 c-xxxx 的形式。

等待一段時間待節點全部產生完畢，就可以看到一個擁有三個節點的 AKS 叢集被創建了

![](https://i.imgur.com/9gwB4Ps.png)

最後到外層叢集介面可以看到目前有四個 K8S 叢集被 Rancher 管理，其中一個是管理 Rancher 本身，剩下三個則是新創立的 K8s 叢集。同時這三個叢集都分配給不同群組的使用者使用。

![](https://i.imgur.com/HeWrk3x.png)


如果這時候用 QA 使用者登入，就只會看到一個叢集，整個運作的確有符合當初的設計。
![](https://i.imgur.com/ZHrSYO2.png)


叢集都創立完畢後，下一章節將來探討如何使用 Rancher 的介面來管理 Kubernetes，以及 Rancher 介面還提供了哪些好用的功能可以讓叢集管理員更加方便的去操作叢集。
