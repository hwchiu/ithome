Day 20 - 初探 GitOps 的概念
=========================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言

前述文章探討了應用程式部署的基本思路，從 Rancher 管理的叢集出發有至少三種不同的部署方式，分別為
1. 直接取得 Kubeconfig 獲得對 Kubernetes 叢集操作的權限
2. 使用 Rancher 內的應用程式機制(Catalog or App & Marketplace) 來安，並可透過 Terraform 來達到 Infrastructure as Code 的狀態。
3. 使用 GitOps 的方式來管理 Kubernetes  應用程式

本篇文章開始將探討何謂 GitOps 以及 GitOps 能夠帶來的好處，並且最後將基於 Rancher FLeet 去進行一系列 GitOps 解決方案的
示範。

# GitOps

就如同 DevOps 是由 DEV + OPS 兩種概念結合而成， GitOps 的原意來自於 Git 以及 OPS，目的是希望以 Git 上的資料為基底去驅動 Ops 相關的操作。

該詞源自於 2017 年由 Weave Works 所提出，GitOps 本身並沒有一個非常標準的定義與實作方式，就如同 DevOps 的文化一樣， 不同人使用 GitOps 的方式都不同，但是基本上都會遵循一個大致上的文化。

GitOps 的精神就是以 Git 作為唯一的資料來源，所有的應用程式部署都只能依賴這份 Git 上內容去變化。
基於這種精神，下列行為都希望盡量減少甚至避免。
1. 直接透過 KUBECONNFIG 對叢集直接使用 Helm/Kubectl 去進行操作
2. 透過其他機制(Rancher Catalog/App) 去對叢集進行應用程式的管理

當 Git 作為一個唯一的資料來源時，整個部署可以帶來下列的好處
1. Git 本身的管理控制提供了應用程式的稽核機制，透過 Git 機制可以知道誰於什麼時間點什麼時間點帶來了什麼樣的改變。
2. 需要退版的時候，可以使用 Git Revert 的方式來退版 Git 內容，因此應用程式也會退版
3. 可以透過 Git 的方式(Branch, tag) 等本身機制來管理不同環境的應用程式
4. 由於 Git 本身都會使用 Pull Request/Git Review 等機制來管理程式碼管理，因此該機制可以套用到應用程式管理上。

這邊要注意的是， GitOps 本身的並沒有特別限制只能使用於 Kubernetes 環境之中，只是當初 Weave work 講出這名詞時是基於 Kubernetes 的環境來探討，因此後續比較多的解決方案也都是跟 Kubernetes 有關，但是這並不代表 GitOps 只能使用於 Kubernetes 內，任何的使用環境只要有基於 Git/Ops 的理念，基本上都可以想辦法實作 GitOps.

但是 GitOps 到底要如何實作? 要如何將 Git 的更動給同步到應用程式的部署則沒有任何規範與標準，目前主要有兩種主流，以下都是一種示範介紹，實務上實作時可以有更多不同的變化。
1. 專屬 CI/CD 流水線
2. 獨立 Controller

接下來以 Kubernetes 為背景來探討一下可能的解法。

# 專屬 CI/CD 流水線

這種架構下會創立一個專屬的 CI/CD Pipeline, 該 Pipeline 的觸發條件就是 Git 專案發生變化之時。
所以 Pipeline 中會去抓取觸發當下的 Git 內容，接者從該內容中判別當前有哪些檔案被修改，從這些被修改的檔案去判別是哪些應用程式有修改，接者針對被影響的應用程式去進行更新。

以 Kubernetes 來說，通常就是指 CI/CD Pipeline 中要先獲得 KUBECONFIG 的權限，如果使用的是 Rancher，則可以使用 Rancher API Token。
當系統要更新應用程式時，就可以透過這些權限將 Kubernetes 內的應用程式進行更新。

這種架構基本上跟傳統大家熟悉的 CD 流程自動化看起來沒有什麼不同，不過 GitOps 會更加強調以 Git 為本，所以會希望只有該 CI/CD Pipeline 能夠有機會去更新應用程式，這也意味任何使用者直接透過 KUBECONFIG 對 Kubernetes 操作這件事情是不被允許的。

所以 GitOps 不單單是一個工具與解決方案，也是一個文化。

# 獨立 Controller
第二個解決方式是目前 Kubernetes 生態中的常見作法，該作法必須要於 Kubernetes 內部署一個 Controller，該 Controller 本身基於一種狀態檢查的無限迴圈去運行，一個簡單的運作邏輯如下。
1. 檢查目標 Git 專案內的檔案狀態
2. 檢查當前 Kubernetes 叢集內的應用程式狀態
3. 如果(2)的狀態與(1)不同，就更新叢集內的狀態讓其與(1)相同

一句話來說的話，該 Controller 就是用來確保 Git 專案所描述的狀態與目標環境的現行狀態一致。

為了完成上述流程，該 Controller 需要有一些相關權限
1. 能夠讀取 Git 專案的權限
2. 能夠讀取 Kubernetes 內部狀態的權限
3. 能夠更新 Kubernetes 應用程式的權限

由於該 Controller 會部署到 Kubernetes 內部，所以(2+3)的權限問題不會太困難，可以透過 RBAC 下的 Service Account 來處理。
(1)的部分如果是公開 Git 專案則沒有太多問題，私人的話就要有存取的 Credential 資訊。

以下是一個基於 Controller 架構的部署示範
1) 先行部署 Controller 到 Kubernetes 叢集內
2) 設定目標 Git 專案與目標 k8s 叢集/namespace 等資訊。
3) 開發者針對 Git 專案進行修改。
4) Controller 偵測到 Git 專案有變動
5) 獲取目前 Git 狀態
6) 獲取目前 叢集內的應用程式狀態
7) 如果(5),(6)不一樣，則將(5)的內容更新到叢集中
8) 反覆執行 (4~7) 步驟。

到這邊為止探討了關於 GitOps 的基本概念，接下來就會數個知名的開源專案去進行探討
