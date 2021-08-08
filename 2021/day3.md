Day 3 - Rancher 架構與安裝方式介紹
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言
前篇文章探討了 Rancher 的基本概念與 Rancher 帶來的好處，本章節則要探討 Rancher 的架構
對其架構瞭解愈深，未來使用時要除錯就會更知道要從什麼角度去偵錯同時部署時也比較會有些基本概念為什麼官方會有不同的部署方式。

由於 Rancher 本身是一個管理 Kubernetes 的平台，同時又要提供 UI 介面給使用者管理，因此其本身就是由多個內部元件組成的，如下圖(該圖節錄自[官方網站](https://rancher.com/docs/rancher/v2.5/en/overview/architecture/#rancher-server-architecture))

註: 此為 v2.5 的架構

![](https://rancher.com/docs/img/rancher/rancher-architecture-rancher-api-server.svg)

從官方的架構圖中可以觀察到， Rancher 本身除了 API Server 作為整體邏輯處理之外，還有額外的元件譬如
1. Cluster Controller
2. Authentication Proxy
3. etcd

其中 Cluster Controller 可以用來控制不同類型的 Kubernetes Cluster，不論是透過 Rancher 所架設的 RKE 或是其他如 EKS/AKS 等。
這邊要特別注意的，任何要給 Rancher 給控管的 Kubernetes Cluster 都會必須要於其叢集中安裝一個 Cluster Agent。 Rancher 要透過 Agent 的幫忙才可以達到統一控管的效用。

API Server 方面本身面對的 Client 很多，有使用 UI 瀏覽的，有使用 CLI 操作，甚至連 Kubernetes API 也都是由 API 處理的。
    這邊解釋一下為什麼 Kubernetes API 需要走 Rancher API Server，試想一個純地端的網路環境，如果使用者想要透過 kubectl/helm 等指令去存取該 Kubernetes，這意味者該地端環境需要將 API Server 的 6443 port 給放出來，同時還要準備好相關憑證等。如果該 Kubernetes Cluster 是由 Rancher 所創立的，那 Rancher 可以透過與 Agent 的溝通過程來交換這些 Kubernetes API 的操作，這意味者使用者只要對 Rancher API Server 發送 Kubernetes API 等相關的指令，這些最後都會被 Rancher API Server 給轉發到底下 Kubernetes Cluster 的 API Server。這樣地端環境也不需要開啟 6443 port，只要本身叢集內的 Agent 有跟 Rancher API Server 有保持連線即可。使用上大幅度簡化整個操作流程。
    最後提醒的是此功能並非一定要使用，針對 RKE 叢集也是有辦法不經由 Rancher 而直接存取 Kubernetes 。

上述的架構圖也清楚的告訴使用者，要架設一個 Rancher 服務要準備上述這些元件，而官方網站本身則提供的數種不同的安裝方式，而這些方式又會分成兩大類，單一節點或是多節點。
單一節點的安裝方式適合測試使用，而生產環境下會建議採用多節點的方式去部署 Rancher Server，畢竟 Rancher 本身是管理多套 Kubernetes 叢集的服務，因此本身最好要有 HA 的機制去確保不會因為單一節點損毀而導致後面一連串的錯誤。

下圖節錄自[官方網站](https://rancher.com/docs/rancher/v2.5/en/overview/architecture-recommendations/)

![](https://rancher.com/docs/img/rancher/rancher-architecture-separation-of-rancher-server.svg)

該架構圖呈現了兩種不同模式下的架構，最大的差別就只是 Rancher Server 本身到底如何被外界存取以及 Rancher Server 有無 HA 等特性。

單一節點的安裝非常簡單，只要使用 docker 指令就可以很輕鬆的起一個 Rancher Server，不過要特別注意的是透過這種方法部署的 Rancher 不建議當作生產環境，最好只是拿來測試即可。
其原理其實是透過一個 docker container 起 Rancher 服務，服務內會用 RKE 創建一個單一節點的 Kubernetes 節點，該節點內會把 Rancher 的服務都部署到該 Kubernetes 內。

多節點安裝的安裝概念很簡單，就是把 Rancher 的服務安裝到一個 Kubernetes 叢集內即可， Rancher 本身提供 Helm 的安裝方式，所以熟悉 Helm 指令就可以輕鬆的安裝一套 Rancher 到 Kubernetes 叢集內。
官方文件提供了不同種 Kubernetes 叢集的安裝方式，包含
1. RKE (使用 RKE 指令先行創建一個 K8S 叢集，再用 Helm 把 Rancher 安裝進去)
2. EKS
3. GKE
4. K3s (輕量級 RKE，針對 IoT 等環境設計的 Kubernetes 版本)
5. RKE2 (針對美國安全相關部門所開發更為安全性的 RKE 版本)

除了上述所描述的一些安裝方式外， Rancher 也跟 AWS 有相關整合，能夠透過 CloudFormation 的方式透過 EKS 部署 Rancher 服務，詳細的可以參閱[Rancher on the AWS Cloud
Quick Start Reference Deployment](https://aws-quickstart.github.io/quickstart-eks-rancher/)

最後為了讓整體的安裝更加簡化，Rancher 於 v2.5.4 後釋出了一個實驗的新安裝方式，稱為 RancherD
該服務會先創建一個 RKE2 的叢集，並且使用 Helm 將相關服務都安裝到該 RKE2 叢集中。

最後要注意的是，不論是哪種安裝方式，都需要針對 SSL 憑證去進行處理，這部分可以用 Rancher 自行簽署，自行準備或是透過 Let's Encrypt 來取得都可以，所以安裝時也需要對 SSL 有點概念會比較好，能的話最好有一個屬於自已的域名來方便測試。
單一節點的 Docker Container 部署方式有可能會遇到 RKE 內部 k8s 服務憑證過期的問題，如果遇到可以參閱下列解決方式處理 [Rancher container restarting every 12 seconds, expired certificates](https://github.com/rancher/rancher/issues/26984#issuecomment-712233261)

下一篇文章便會嘗試透過 RKE + Helm 的方式來看看如何架設 Rancher