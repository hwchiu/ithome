Day 2 - 何謂 Rancher
====================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# Rancher

Rancher 是一個由 Rancher Labs 的公司所維護的 Kubernetes 相關開源專案，Rancher Lab 於 2020 年底被 Suse 據傳已 600萬 ~ 700萬美金左右收購，因此如果目前搜尋
Rancher 相關的資源有時候會看到跟 Suse 這間公司有關的消息就不要太意外。

簡單來說，Rancher 是一個 Kubernetes 管理平台，希望能夠讓團隊用更簡單及有效率的方式去管理各式各樣的 Kubernetes 叢集，其支援幾種不同方式
1. Rancher 自行維護的 Kubernetes 版本，Rancher Kubernetes Engine(RKE)
2. 各大公有雲所提供的 Kubernetes 服務，如 AKS, EKS 以及 GKE
3. 任何使用者自己創建的 Kubernetes 叢集

除了上述 Kubernetes 叢集外， Rancher 也支援眾多公有雲平台來簡化整個部署流程，譬如可以讓公有雲自動創建 VM 並且於 VM 上創建 RKE 叢集，而且這些 VM
還可以根據不同的需求設定不同的能力，譬如某些節點設定 4c8g(4vCPU, 8G Memory)，某些給予 16c32g，同時有些專門當 worker，有些可以當 etcd/control plan等不同角色。

註: 不同來源的 Kubernetes 叢集功能上會有些許差異，詳細可以參閱[官網介紹](https://rancher.com/docs/rancher/v2.5/en/overview/)，RKE 跟 EKS/GKE 於 2.5.8 版本則擁有全部的操作能力，但是 AKS 或是其他使用者自行架設的 Kubernetes 叢集會有些功能沒辦法使用。

有些人會好奇，如果自己都已經有方式去架設跟管理自己的 Kubernetes 叢集，那為什麼還需要使用 Rancher 的管理平台?
就如同 Kubernetes 一樣，要不要導入 Rancher 也是要評估的，我認為符合下列情況的團隊其實並不一定要使用 Rancher，譬如
1. 雲端環境直接採用 Kubernetes 服務，如 EKS/AKS/GKE
2. 直接尋找系統整合商購買 Kubernetes 服務
3. 沒有地端(On-premises)環境需求
4. 公司不太想要使用開源專案，希望專案都要有人員提供技術服務

如果團隊都沒有符合上述需求時，其實可以評估看看是否要導入 Rancher
導入的第一個問題就是導入 Rancher 能夠帶來什麼好處?，為什麼要使用 Rancher?



我個人認為 Rancher 對於團隊帶來的好處有
1. 很輕鬆地去架設一套 RKE 的環境，雖然本身是 Rancher 所維護的版本，但是大部分情況跟原生 Kubernetes 使用起來沒有差異。
2. 如果團隊同時有地端跟雲端的混合環境，可以透過 Rancher 方便管理多套 Kubernetes
3. 如果今天地端環境本身擁有網路防火牆限制，導致想要從外部使用 Kubectl 來存取與管理該地端上的 Kubernetes 叢集會有困難時，使用 Rancher 能夠輕鬆地處理這個問題。
4. Rancher 提供的 Dashboard 提供滿多訊息，可以一目明瞭目前所有 Kubernetes 叢集的健康狀態，非工程人員也可以容易閱讀
5. Rancher 本身支援不同的認證機制，可以跟團隊本身使用的認證服務整合，直接透過現有的狀態來認證與授權，管理上非常方便

有了上述功能後，來看一下從[官方](https://rancher.com/docs/rancher/v2.5/en/overview/)所節錄的架構圖，來看看導入 Rancher 後對於整個團隊有什麼變化?

![](https://rancher.com/docs/img/rancher/platform.png)

上圖分成三個部分，左邊代表 DevOps Team，中間是 Rancher 管理平台，右邊則是公司的 IT Team.
Rancher平台(中間)
1. Rancher 本身管理多套 Kubernetes 叢集，譬如圖中的 GKE/EKS，甚至可以跟 VMware 整合，將 RKE 安裝到產生的 VM 上
2. 如果已經跟公有雲平台串接完畢(API)，則可以透過 Rancher 的介面自動創立相關 VM 並且直接再上面創建 RKE 叢集，因此可以很方便根據需求創立 Dev/Staging/QA/Prod 等不同用途的 Kubernetes 叢集

IT Team(右邊)
1. IT Team 對於公司內的環境會有比較不同的需求，譬如帳號認證授權，安全政策等
2. IT 直接將 Rancher 與團隊內的身份機制整合，可以讓每個不同的 Kubernetes 都擁有不同的存取權限，譬如 QA Team 的人只擁有 QA 叢集的完全存取權限，而 Dev Team 的人可以存取 Dev 叢集，DevOps Team 的人則可以對所有叢集都有權限。
3. 可以直接於 Rancher 本身設定相關的安全政策，這些安全政策會直接套用到所有託管的 Kubernetes 叢集內。
4. Rancher 其實也有實作 Terraform 的介面，所以 IT Team 是可以直接透過 Terraform 使用 Infrastructure as Code 的概念來維護 Rancher，這樣就可以很簡單與快速的維護與創建各種叢集。

DevOps Team(左邊)
1. DevOps Team 使用 IT Team 設定好的身份帳號來存取相關 Kubernetes 叢集
2. Rancher 也提供 KUBECONFIG 供使用者透過 kubectl/helm 等工具使用，也可以將此資訊整合到 CI/CD 流程來達成自動部署。
3. Rancher 也提供應用程式部署的相關機制讓使用者可以方便地管理 Kubernetes 上的應用
4. Rancher 整合的 Monitoring/Logging/Alert 功能讓使用者用起來很簡單。
5. Rancher Fleet 使用 GitOps 的方式簡化了部署流程，使用者只需要更新 Git Repo 就可以順利更新自己的應用程式，甚至本身對於 Kubernetes 底層不太熟悉都能夠順利部署進去

當然上述架構只是一個範例，實際上更有可能是 DevOps Team 而非 IT Team 需要維護 Rancher 本身，這部分完全是取決於團隊的分工與組成。

# 版本選擇
目前主流的 Rancher 版本是 v2.5 系列，如果還沒有使用過 Rancher 的讀者建議都直接使用 v2.5 系列版本，主要是 v2.5 相對於前版有很多重大修改，譬如
1. Monitoring 功能的改進，v2.5 以前是用 Rancher 自行整合的 Prometheus/Grafana，所以使用者要客製化上會相對麻煩。 v2.5 整個架構都改成基於 Prometheus Operator 的做法，因此如果本來就熟悉 Prometheus Operator 的使用者可以更容易的使用 Rancher Monitoring 來加上自己想要的功能。
2. Rancher 的 UI 也有大幅度的改動，過往瀏覽觀察 Cluster 的介面稱為 Cluster Manager，而新版的 Cluster Explorer 將會是未來維護的主要功能
3. 整合 Rancher Fleet 來提供基於 GitOps 的部署方式，之後的章節會詳細介紹如何使用 Rancher Fleet 來管理多叢集的應用程式
4. 提升與 AWS EKS 的整合，可以將已經創立的 EKS 直接整合到 Rancher 讓管理員用一個 Rancher 去管理多個 Kubernetes

目前 v2.6 版本還在積極開發中，目前已知 2.6 也在努力提升與 AKS/GKE 的整合。
同時 Rancher v2.5 之後 Rancher 本身的安裝方式也都轉移到 Helm3，因此如果需要從舊版 Rancher 轉移到新版 Rancher 時，有可能會遇到 Helm 轉移的問題
所以新的使用者都強烈建議直上 v2.5，而不要再嘗試舊版了。

下篇文章將詳細介紹 Rancher 的架構，看完該架構會更加理解到底 Rancher 扮演何種角色。