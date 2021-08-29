Day 21 - GitOps 解決方案比較
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

#  前言

前篇文章探討了基本的 GitOps 概念，GitOps 本身沒有嚴謹明確的實作與定義，所以任何宣稱符合 GitOps 工作流程的解決方案其實作方式與使用方有可能並不相同。

本文將探討數個常見的 GitOps 解決方案，針對其基本概念進行研究，一旦對這些解決方案都有了基本認知後，就可以更快的理解 Rancher Fleet 這套由 Rancher v2.5 後主推的 GitOps 解決方案是什麼，該怎麼使用。

# KubeStack
GitOps 並不是專屬於 Kubernetes 的產物，任何架構與專案都有機會採用 GitOps 的概念來實作。
KubeStack 是目前極為少數非 Kubernetes 應用程式的 GitOps 解決方案，官網宣稱是一個專注於 Infrastructure 的 GitOps 框架。該架構基於 Terraform 去發展，因此 KubeStack 的使用者實際上還是撰寫 Terraform ，使用 Terraform 的語言。 KubeStack 針對 Terraform 發展了兩套不同的 Terraform Module，分別是 Cluster Module 以及 Cluster Service Module。

Cluster Module 讓使用者可以方便的去管理 Kubernetes 叢集，該叢集可以很輕鬆的去指定想要建立於哪種雲端架構上，透過 KubeStack 使用者也可以很容易的針對不同地區不管雲端架構來搭建多套的 Kubernetes 叢集。
其實整體概念滿類似 Rancher 的，只不過這邊是依賴 Terraform 來管理與多個雲端架構的整合，同時 Kubernetes 叢集也會採用原生版本或是 Kubernetes 管理服務的版本。

Cluster Service Module 目的是用來創造 Kubernetes 相關資源，所以使用上會先透過 Cluster Module 創建 Kubernetes 叢集，接者透過 Cluster Service Module 部署相關服務。
Cluster Service Module 的目的並不是部署各種團隊的商業邏輯服務，相反的，其目的是則是部署前置作業，任何真正部署前需要用到的服務都會透過這個 Module 來處理。預設情況下 KubeStack 有提供 Catalog 清單來提供預設提供的服務，包含了
1. ArgoCD/Flux
2. Cert-Manager
3. Sealed Secrets
4. Nginx Ingress
5. Tekton
6. PostgreSQL Operator
7. Prometheus Operator

而前述兩個則是針對 kubernetes 應用程式的 GitOps 解決方案。

KubeStack 的使用方式是採用前述探討的第一種實作，團隊需要準備一個專屬的 CI/CD Pipeline，其內透過呼叫 Terraform 的方式來完成整個更新的流程，對於 KubeStack 有興趣的可以參閱其官網。


# ArgoCD/Flux
探討到開源且針對 Kubernetes 應用程式部署的解決方案時，目前最知名的莫過於 ArgoCD 以及 Flux。

ArgoCD 本身的生態系非常豐富，該品牌底下有各式各樣不同的專案，專注於不同功能，而這些功能又有機會彼此互相整合，譬如
1. ArgoCD
2. Argo Workflow
3. Argo RollOut

ArgoCD 是專注於 GitOps 的解決方案， Argo Workflow 是套 Multi-Stage 的 pipeline 解決方案，而 Argo Rollout 則是希望能夠針對 Kubernetes 提供不同策略的部署方式，譬如藍綠部署，金絲雀部署等，這些都是 Kubernetes 原生不方便實作的策略。

ArgoCD 採用的是第二種實作方式，需要於 Kubernetes 內安裝 ArgoCD 解決方案，該解決方案大致上會於叢集內安裝
1. Argo API Server
2. Argo Controller
3. Dex Server
4. Repository Service

以下架構圖來自於[官方網站](https://argo-cd.readthedocs.io/en/stable/)
![](https://i.imgur.com/VdVPq84.png)

Argo Controller/Repository Service 是整個 GitOps 的核心功能，能夠偵測 Git 專案的變動並且基於這些變動去比較當前 Kubernetes 內的即時狀態是否符合 Git 內的期望狀態，並且嘗試更新以符合需求。
Argo API Server 則是提供一層 API 介面，讓外界使用者可以使用不同方式來操作 ArgoCD 解決方案，譬如 CLI, WebUI 等。

ArgoCD 安裝完畢後就會提供一個方式去存取其管理網頁，大部分的使用者都會透過該管理網頁來操作整個 ArgoCD，該介面的操作符合不同需求的使用者，譬如 PM 想要理解當前專案部署狀態或是開發者想要透過網頁來進行一些部署操作都可以透過該網頁完成。
為了讓 ArgoCD 可以更容易的支援不同帳戶的登入與權限管理，其底層會預先安裝 Dex 這套 OpenID Connector 的解決方案，使用者可以滿容易地將 LDAP/OAuth/Github 等帳號群組與 ArgoCD 整合，接者透過群組的方式來進行權限控管。

應用程式的客製化也支援不少，譬如原生的 YAML，Helm, Kustomize 等，這意味者大部分的 kubernetes 應用程式都可以透過 ArgoCD 來部署。

ArgoCD 大部分的使用者一開始都會使用其 UI 進行操作與設定，但是這種方式基本上與 Rancher 有一樣的問題
1. UI 提供的功能遠少於 API 本身，UI 不能 100% 發揮 ArgoCD 的功能
2. 設定不易保存，不容易快速複製一份一樣的 ArgoCD 解決方案，特別是當有災難還原需求時。

舉例來說，ArgoCD 可以管理多套 Kubernetes 叢集，這意味你可以於叢集(A)中安裝 ArgoCD，透過其管理叢集B,C,D。
管理的功能都可以透過網頁的方式來操作，但是要如何讓 ArgoCD 有能力去存取叢集 B,C,D，相關設定則沒辨法透過網頁操作，必須要透過 CLI 或是修改最初部署 ArgoCD時的 YAML 檔案。

ArgoCD 實際上於 Kubernetes 內新增了不少 CRD(Custom Resource Definition)，使用者於網頁上的所有設定都會被轉換為一個又一個的 Kubernetes 物件，而且 ArgoCD 本身的部署也是一個又一個 YAML 檔案，因此實務上解決設定不易保存的方式就是 「讓 ArgoCD 透過 GitOps 的方式來管理 ArgoCD」

該工作流程如下(範例)
1. 將所有對 ArgoCD 的設定與操作以 YAML 的形式保存於一個 Git 專案中
2. 使用官方 Helm 的方式去安裝最乾淨的 ArgoCD
3. 於 ArgoCD 的網頁上新增一個應用程式，該應用程式目標是來自(1)的 Git 專案
4. ArgoCD 會將(1)內的 Git 內容都部署到 Kubernetes 中
5. ArgoCD 網頁上就會慢慢看到所有之前設定的內容

如果對於 ArgoCD 有興趣的讀者可以參考我開設的線上課程[kubernetes 實作手冊： GitOps 版控整合篇
](https://hiskio.com/courses/490/about?promo_code=R3Y9O2E)，該課程中會實際走過一次 ArgoCD 內的各種操作與注意事項，並且最後也會探討 ArgoCD 與 Argo Rollout 如何整合讓部署團隊可以用金絲雀等方式來部署應用程式。

下篇文章就會回到 Rancher 專案身上，來探討 Rancher Fleet 是什麼，其基本元件有哪些，接者會詳細的介紹 Rancher Fleet 的用法。