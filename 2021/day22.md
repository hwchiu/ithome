Day 22 - Rancher Fleet 環境架設與介紹
==================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

---

# 前言
前述文章探討了關於 Rancher Fleet 的基本架構與概念介紹，瞭解到 Rancher Fleet 本身是個主從式的架構。環境中會有一個 Kubernetes 叢集專門用來部署 Fleet Controller 作為 Fleet Manager，而所有要被託管的 Kubernetes 叢集都必須要部署一個 Fleet Agent 來連接 Fleet Manager。

本篇文章將針對實際部署情況去觀察。

# 安裝

[官方網站](http://fleet.rancher.io/multi-cluster-install/) 有列出非常詳細的安裝步驟，針對 Fleet Manager 安裝要用到的憑證與除錯方式，如何使用 Helm 安裝 CRD 與 Fleet Controller 都有介紹。
當 Fleet Manager 安裝與設定完畢後，接下來就可以參考 [Cluster Registration Overview](http://fleet.rancher.io/cluster-overview/) 這篇官方文章來學習如何將一個 Kubernetes 叢集作為 Fleet Agent 加入到 Fleet Manager 的管理中。

不過這邊要特別注意的是，以上所提的安裝方式都是針對純 Fleet 解決方案時才需要考慮的部分，因為 Fleet 是 Rancher 開發與維護的，因此任何由 Rancher 管理與創建的 Kubernetes 叢集都已經內建 Fleet Agent，大幅度簡化使用者的安裝方式。

當初安裝 Rancher 時會先準備一個 Kubernetes 叢集專門用來負責 Rancher 本身的維運，其他所有的叢集都會透過這個 Rancher 去創建與維護，Rancher Fleet 會採用相同的架構與方式去處理。專門用來部署 Rancher 的 Kubernetes 叢集會被安裝 Fleet Controller。

基於以上兩點，只要所有叢集都是由 Rancher 去創建與管理的， Fleet 就不需要自己手動安裝，Fleet Manager 與 Fleet Agent 都會自動的被安裝與部署到相關叢集中。

# 觀察

前述所述，用來安裝 Rancher 服務的 Kubernetes 叢集本身也會安裝 Fleet Controller，這部分可以到 Apps 的頁面去看到底有哪些應用程式被安裝到叢集中。同時透過畫面中提供的 kubectl 指令去觀察 fleet-system namespace 中安裝的 Pod，如下圖。

![](https://i.imgur.com/D26BxGL.png)

可以觀察到 local 也就是部署 Rancher 的 Kubernetes 叢集有部署三個 Pod，其中 fleet-controller 以及 gitjob 兩個 pod 是針對 fleet manager 而部署的 Pod，而 fleet-agent 則是給 fleet-agent 使用的。

此架構意味者管理者可以透過該 Fleet 來管理 local 這套 Kubernetes 叢集。
之前提到 Fleet 與大部分的 Operator 有相同的開發流程，所以會使用一個 Kubernetes Controller 配上很多預先設定的 CRD 物件，所以透過 kubectl get crd 就可以看到 local 叢集上有各式各樣關於 Fleet 的 CRD。

接下來觀察要被管理的 Kubernetes 叢集，譬如給 Dev 使用的叢集，這時候使用相同的方式去觀察該叢集內安裝的資源，可以觀察到 fleet-system 內只有安裝一個 Pod，該 Pod 就是扮演 Fleet Agent 的角色，讓該叢集能夠順利的 Fleet Manager 溝通，範例如下。

![](https://i.imgur.com/6NkmYFP.png)

確認完畢之後就可以移動到 Rancher Fleet 的專屬頁面，移動的方式很簡單，不論當前是處於哪個叢集，點選左上方就可以找到一個名為 Continuous Delivery 的選項，點進去就會進入到 Rancher Fleet 的畫面。

![](https://i.imgur.com/2MnLVYF.png)

進去畫面中後會看到如下的畫面，畫面中有非常多的新東西，接下來針對這些新東西慢慢探索

![](https://i.imgur.com/RKvXvYl.png)

首先畫面最上方有一個下拉式選單可以選擇，該選單會列出所有可以使用的 Fleet Workspace，那到底什麼是 workspace 呢?

Fleet workspace 是一個管理單位，就如同大部分專案的 workspace 概念一樣，每個 workspace 都會有自己獨立的 GitRepo, Group, Bundle 等概念。
一個實務上的上作法會創立多種不同的 workspace，譬如 dev, qa 及 prod。

每個 workspace 內都可包含多個不同的 cluster 與其他的資源。

預設的情況下有兩個 workspace，分別是 fleet-local 以及 fleet-default. 所有剛加入到 Rancher 的叢集都會被加入到 fleet-default 這個 workspace 中。

畫面左邊有六個不同的資源

Git Repos:
Git Repos 內的資源是告訴 Fleet 希望追蹤哪些 Git 專案，該 Git 專案中哪些資料夾的哪些檔案要讓 Fleet 幫忙管理與安裝。

因為 Fleet 什麼都還沒有安裝與設定，所以 Git Repo 內目前是空空的，沒有任何要被安裝的應用程式。

Clusters/Cluster Groups:
這邊顯示的是該 workspace 中有多少個 cluster，目前的環境中先前創立三個不同的 Kubernetes 叢集，而這些叢集預設都會被放入到 fleet-default workspace 內的 group。

假設 cluster 數量過多，還可以透過 Cluster Group 的概念來簡化操作，將相容用途的 cluster 用群組的方式來簡化之後的操作。

![](https://i.imgur.com/crKNn9J.png)

Workspace:
Workspace 可以看到目前系統有多少個 workspace，可以看到系統中有 fleet-default 以及 fleet-local，同時也會顯示這些 workspace 中目前管理多少個 cluster 。

![](https://i.imgur.com/JR4XHU6.png)

Bundles:
之前提過 Bundle 是 Fleet controller 掃過 GitRepo 專案後會產生的安裝資源檔案。
可以當前的範例非常奇妙，沒有任何 Git Repo 的內容卻擁有這些 Bundle 檔案，主要是因為這三個 Bundle 是非常奇妙與特殊的 Bundle，仔細看的話可以觀察到這些 Bundle 的名稱都是 Fleet-agent-c-xxxx，這些 bundle 是用來安裝 fleet-agent 到目前 Rancher 下的所有 Kubernetes 叢集。
這些安裝是 Rancher 內建強迫的，所以使用上會稍微跟正常用法有點不同。

![](https://i.imgur.com/rbOOOtQ.png)

ClusterRegistrationTokens:
最後一個則是 Cluster(Fleet Agent) 要加入到 Fleet Manager 使用的 Token，不過因為目前的叢集全部都是由 Rancher 去管理與創造的，所以不需要參考官網自行安裝，因此 Rancher 會走比較特別的方式來將 Rancher 管理的叢集給加入到 Fleet manager 中，因此這邊就是空的。


此外透過 Cluster 內的操作，可以將該 workspace 下的 cluster 給移轉到其他的 workspace，所以之後根據需求創立不同的 workspace 後，就可以透過這個方式將 cluster 給移轉到屬於該用途的 workspace。

![](https://i.imgur.com/4PM93aR.png)

到這邊為止，稍微看了一下關於 Fleet 介面的操作與基本概念，下一篇就會正式嘗試透過 Git Repo 這個物件來管理試試看 GitOps 的玩法，此外因為 Fleet 內的操作基本上都可以轉化為 Kubernetes 的 CRD 物件，所以很多 UI 的設定都可以使用 YAML 來管理，透過這個概念就可以達到跟 ArgoCD 一樣的想法，用 GitOps 來管理 Fleet 本身。
