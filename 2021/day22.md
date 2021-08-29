Day 22 - Rancher Fleet 架構介紹
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言
前篇文章探討了 ArgoCD 與 KubeStack 這兩套截然不同的 GitOps 解決方案，可以觀察到 GitOps 就是一個文化與精神，實際的操作與部署方式取決於不同解決方案。

Rancher 本身作為一個 Kubernetes 管理平台，不但可以管理已經存在的 Kubernetes 叢集更可以動態的於不同架構上創建 RKE 叢集。
基於這些功能的基礎上，Rancher 要實作 GitOps 似乎會簡單一些，畢竟連 Kubernetes 都可以創建了，要部署一些 Controller 到叢集內也不是什麼困難的事情，因此本篇文章就來仔細探討 Rancher Fleet 這套 Rancher 推出的 GitOps 解決方案。

# Rancher Fleet

Rancher Fleet 是 Rancher 於 v2.5 後正式推出的應用程式安裝功能，該安裝方式不同於 Catalog 以及 v2.5 的 App 專注於單一應用安裝，而是更強調如何透過 GitOps 來進行大規模部署。

Fleet 的設計初衷就是希望提供一個大規模的 GitOps 解決方案，大規模可以是大量的 Kubernetes 叢集或是大量的應用程式部署。為了滿足這個目標， Fleet 架構設計上就是追求輕量與簡單，畢竟 Rancher 擁有另外一套針對物聯網環境的輕量級 Kubernetes 叢集，K3s。 因此 Fleet 也希望能夠針對 K3s 這種輕量級環境來使用。

Fleet 支援三種不同的格式，分別是原生YAML, Helm 以及 Kustomize，其中最特別的是這些格式還可以互些組合，這意味者使用者可以透過 Helm + Kustomize 來客製化你的應用程式，之後會有文章針對這些使用情境來介紹這類型的用途及好處。

Fleet 的內部邏輯會將所有的應用程式動態的轉為使用 Helm 去安裝與部署，因此使用者除了透過 Rancher Fleet 之外也可以透過 Helm 的方式去觀察與管理這些應用程式，簡單來說 Fleet 希望可以讓透過使用者簡單的安裝大規模的應用程式，同時又提供一個良好的介面讓使用者可以管理這些應用程式。


下圖來自於[官方網站](http://fleet.rancher.io/concepts/)，該圖呈現了 Fleet 的基本架構與使用概念。圖中有非常多的專有名詞，瞭解這些名詞會對我們使用 Fleet 有非常大的幫助，因此接下來針對這張圖進行詳細介紹。

![](https://i.imgur.com/GrUNLTs.png)

Fleet 與大部分的 Operator 實作方式一樣，都是透過 Kubernetes CRD 來自定義相關資源，並且搭配一個主要的 Controller 來處理這些資源的變化，最終提供 GitOPs 的功能，因此圖上看到的大部分名詞實際上都可以到 Kubernetes 內找到一個對應的 CRD 資源。

Fleet Manager/Fleet Controller:

由於 Fleet 是一個可以管理多個 Kubernetes 叢集的解決方案，其採取的是 Manager/Agent 的架構，所以架構中會有一個 Kubernetes 叢集其扮演者 Fleet Manager 的概念，而被管理的 Kubernetes 叢集則是所謂的 Fleet Agent
上圖中的 Fleet Controller Cluster 就是一個擁有 Fleet Manager 的 Kubernetes 叢集，底下三個 Cluster Group 代表的是其裡面的所有 Kubernetes 叢集都是 Fleet Agent

Fleet Manager 的概念中，實際上會部署一個名為 Fleet Controller 的 Kubernetes Pod，該服務要負責處理 Fleet Agent 註冊的資訊，同時也要協調多個 Fleet Agent 當前的部署狀態最後呈現到 UI 中供管理者使用。

Fleet Agent:

每一個想要被管理的 Kubernetes 叢集都被視為 Fleet Agent，實際上需要安裝一個名為 Fleet Agent 的 Kubernetes Pod 到叢集中，該 Agent 會負責跟 Fleet Manager 溝通並且註冊，確保該叢集之後可以順利地被 Fleet Manager 給管理。

Single/Multi Cluster Style:

Fleet 的官方網站提及兩種不同的部署模式，分別是 Single Cluster Style 以及 Multi Cluster Style
Single Cluster Style 主要是測試使用，該架構下會於一個 Kubernetes 叢集中同時安裝 Fleet Agent 與 Fleet Controller，這樣就可以於一個 Kubernetes 叢集中去體驗看看 Rancher Fleet 帶來的基本部署功能。
不過實務上因為會有更多的叢集要管，因此都會採用 Multi Cluster Style，該架構如同上圖所示，會有一個集中的 Kubernetes 叢集作為 Fleet Manager，而所有要被管理的 Kubernetes 叢集都會作為 Fleet Agent.

GitRepo:

Fleet 中會有一個名為 GitRepo 的物件專門用來代表各種 Git 的存取資訊，Fleet Manager 會負責去監控欲部署的 Git 專案，接者將這些專案的內容與差異性給部署到被視為 Fleet Agent 的 Kubernetes 叢集。

Bundle

Bundle 可以說是整個 Fleet 中最重要也是最基本的資源，其代表的是一個又一個要被部署的應用程式。
當 Fleet Manager 去掃描 GitRepo 時，就會針對該 GitRepo 中的各種檔案(YAML, Helm, Kustomize) 等
產生多個 Bundle 物件。
Bundle 是由一堆 Kubernetes 物件組成的，基本上也就是前篇所探討的應用程式。舉例來說，今天 Git 專案中透過 Helm 的方式描述了三種應用程式，Fleet Manager 掃描該 GitRepo 後就會產生出對應的三個 Bundle 物件。接者 Fleet Manager 就會將該 Bundle 給轉送到要部署該應用程式的 Fleet Agent 叢集，最後 Fleet Agent 就會將這些 Bundle 動態的轉成 Helm Chart 並且部署到 Kubernetes 叢集。

從上方的架構圖來看，可以看到中間的 Fleet Cluster 本身會連接 Git 專案，並且針對這些專案產生出一個又一個 Bundle 資源(Bundle Definition)，接者這些 Bundle 就會被傳送到需要部署的 Kubernetes 叢集，該叢集上的 Fleet Agent 就會負責處理這些 Bundle，譬如補上針對自身叢集的客製化設定，最後部署到叢集內。
所以可以看到上圖左下方的 Kubernetes 叢集內使用的是 (Bundle with Cluster Specific Configuration) 的字眼，代表這些真正部署到該叢集內的 Bundle 都是由最基本的 Bundle 檔案配上每個叢集的客製化內容。

為了讓 Fleet 能夠盡可能地去管理不同架構的 Kubernetes 叢集， Fleet 跟 Rancher 本身的設計非常類似，都是採取 Agent Pull 的方式。該模式代表的是 Fleet Controller 不會主動的去跟 Fleet Agent 進行連線，而是由 Fleet Agent 主動的去建立連線。
這種架構的好處就是被管理的 Kubernetes 叢集可以將整個網路給隱藏到 NAT 後面，只要確保底層環境有 SNAT 的功能網路可以對外即可。