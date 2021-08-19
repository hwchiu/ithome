Day 17 - Rancher Catalog/App 介紹
=============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# Rancher Application

Rancher v2.5 是一個非常重要的里程碑，有很多功能於這個版本進入了 v2 下一個里程碑，本章節要探討的應用程式部署實際上也有這個轉變。

Rancher Catalog 是 Rancher v2.0 ~ v2.4 版本最主要的部署方式，而 v2.5 則改成 Cluster Explorer 內的 App&Marketplace 的方式。
也可以將這個差異說成由 Cluster Manager 轉換成 Cluster Explorer。

那為什麼這個已經要被廢除的功能還需要來介紹？
主要是我自己針對 v2.5 的使用經驗來看，我認為部署應用程式用 Cluster Manager 看起來還是比較簡潔有力，相反的 Cluster Explorer 內的機制沒有好到會讓人覺得替換過去有加分效果。

所以接下來就針對這兩個機制分享一下使用方式。

# Rancher Catalog

Rancher Catalog 的核心概念分成兩個

1. 如何取得 Kubernetes 應用程式，這部分的資訊狀態就稱為 Catalog
2. 將 Catalog 中描述的應用程式給實體化安裝到 Kubernetes 中

Catalog 的核心精神就是要去哪邊取得 Kubernetes 應用程式，Catalog 支援兩種格式
1. Git 專案，底層概念就是能夠透過 git clone 執行的專案都可以
2. Helm Server，說到底 Helm Server 就是一個 HTTP Server，這部分可以自行實作或是使用 chartmuseum 等專案來實作。

由於 Helm 本身還有版本差別， Helm v2 或是 Helm v3，因此使用上需要標注到底使用哪版本。

Catalog 也支援 Private Server，不過這邊只支援使用帳號密碼的方式去存取。使用權限方面 Catalog 也分成全 Rancher 系統或是每個 Kubernetes 叢集獨立設定。

首先如下圖，切換到 Global 這個範圍，接者可以於 Tools 中找到 Catalog 這個選項。

![](https://i.imgur.com/Sa3pydP.png)

或是如下圖，切換到 ithome-dev 這個叢集中，也可以看到 Tools 中有 Catalog 的範圍。

![](https://i.imgur.com/OkbmzuM.png)

這邊我們使用 Kubernetes Dashboard 這個專案作為一個示範，該專案的 Helm Chart 可以經由 https://kubernetes.github.io/dashboard 這個 Helm Server 去存取。

這類型的伺服器預設都沒有 index.html，所以存取會得到 404 是正常的，想要存取相關內容可以使用下列方式去存取 https://kubernetes.github.io/dashboard/index.yaml，這也是 helm 指令去抓取相關資源的辦法，可以知道該 Server 上會有多少 Helm Charts 以及對應的版本有哪些。

點選右上方的 Add Catalog 就可以看到如下的設定視窗

![](https://i.imgur.com/4P3BB9d.png)

該畫面中我們填入上述資訊，如果是 Git 專案的位置還可以輸入 branch，但是因為我們是 Helm Server，所以 Branch 的資訊就沒有設定的意義。
最後順便設定該 Helm Server 是基於 Helm v3 來使用的。

![](https://i.imgur.com/1Bcgq2s.png)

創建完畢後就意味 Rancher 已經可以透過這個 Catalog 去得到遠方當前有哪些 應用程式以及擁有哪些版本，但是這並不代表 Rancher 已經知道。
一種做法就是等 Rancher 預設的同步機制慢慢等或是直接點選 Refresh 讓 Rancher 直接同步該 Catalog 的資訊。

一種常見的情境就是你的 CI/CD 流程更新了 Helm Chart，推進一個版本，結果 Rancher 還不知道，這時候就可以 refresh 強制更新。

創建 Catalog 完畢後，下一件事情就是要從 Catalog 中找到一個可以用的應用程式，並且選擇該應用程式的版本，如果是 Helm 描述的應用程式還可以透過 values.yaml 的概念去客製化應用程式。

應用程式的安裝是屬於最底層架構的，因此是跟 Project 綁定，從左上方切換到之前創立的 myApplication project，並且切換到到畫面上方的 app 頁面中。

![](https://i.imgur.com/kti8npL.png)

該頁面的右上方有兩個按鈕，其中 Manage Catalog 會切回到該專案專屬的 Catalog 頁面，因此 Catalog 本身實際上有三種權限，(Global, Cluster, Project).
右邊的 Launch 意味者要創立一個應用程式。
點進去後會看到如下方的圖

![](https://i.imgur.com/WjgFzob.png)

圖中最上方顯示的就是前述創立的 Catalog，該 Helm Server 中只有一個應用程式名為 kubernetes-dashboard

下面則是一些系統預設的 catalog，譬如 helm3-library，該 helm server 中則有非常多不同的應用程式。
其中這些預設提供的 helm chart 還會被標上 partner 的字樣。

點選 kubernetes-dashboard 後就會進入到設定該應用程式的畫面。

![](https://i.imgur.com/cDCOpE9.png)

畫面上會先根據 Helm Chart 本身的描述設定去介紹該 Helm Charts 的使用方式

![](https://i.imgur.com/qSfk7na.png)


接下來就要針對該應用程式去設定，該設定包含了
1. 該應用程式安裝的名稱
2. 該 Helm Chart 要用什麼版本，範例中選擇了 4.5.0
3. 該服務要安裝到哪個 Kubernetes namespace 中
4. 最下面稱為 Answer 的概念其實就是 Helm Chart values，這邊可以透過 key/value 的方式一個一個輸入，或是使用 Edit as YAML 直接輸入都可以

預設情況下我們不進行任何調整，然後直接安裝即可。

![](https://i.imgur.com/kIoCMfe.png)

安裝完畢後就可以於外面的 App 頁面看到應用程式的樣子，其包含了
1. 應用程式的名稱
2. 當前使用版本，如果有新版則會提示可以更新
3. 狀態是否正常
4. 有多少運行的 Pod
5. 是否有透過 service 需要被外部存取的服務

點選該名稱可以切換到更詳細的列表去看看到底該應用程式包含的 Kubernetes 資源狀態，譬如 Deployment, Service, Configmap 等

![](https://i.imgur.com/jdfBeZb.png)

如果該資源有透過 Service 提供存取的話， Rancher 會自動的幫該物件創建一個 Endpoint，就如同 Grafana/Monitoring 那樣，可以使用 API Server 的轉發來往內部存取。
譬如途中可以看到有產生一個 Endpoint，該位置就是基於 Rancher 的位置後面補上 cluster/namespace/service 等相關資訊來進行處理。

![](https://i.imgur.com/UCZbXaP.png)

這類型的資訊也會於最外層的 App 介面中直接呈現，所以如果直接點選的話就可以很順利地打該 Kubernetes Dashboard 這個應用程式。

![](https://i.imgur.com/tlpRoeb.png)
![](https://i.imgur.com/z7yQGtn.png)

最後也可以透過 Kubectl 等工具觀察一下目標 namespace 是否有相關的資源，可以看到有 deployment/service 等資源

![](https://i.imgur.com/j36WdZv.png)

透過 Rancher Catalog 的機制就可以使用 Rancher 的介面來管理與存取這些服務，使用上會稍微簡單一些。既然都可以透過 UI 點選那就有很大的機會可以透過 Terraform 來實現上述的操作。

接下來示範如何透過 Terraform 來完成上述的所有操作，整個操作會分成幾個步驟
1. 先透過 data 資料取得已經創立的 Project ID
2. 創立 Catalog
3. 創立 Namespace
4. 創立 App

```
data "rancher2_project" "system" {
    cluster_id = "c-z8j6q"
    name = "myApplication"
}
resource "rancher2_catalog" "dashboard-global" {
  name = "dashboard-terraform"
  url = "https://kubernetes.github.io/dashboard/"
  version = "helm_v3"
}
resource "rancher2_namespace" "dashboard" {
  name = "dashboard-terraform"
  project_id = data.rancher2_project.system.id
}
resource "rancher2_app" "dashboard" {
  catalog_name = "dashboard-terraform"
  name = "dashboard-terraform"
  project_id = data.rancher2_project.system.id
  template_name = "kubernetes-dashboard"
  template_version = "4.5.0"
  target_namespace = rancher2_namespace.dashboard.id
  depends_on       = [rancher2_namespace.dashboard, ncher2_catalog.dashboard-global]
}
```

上述做的事情基本上跟 UI 是完全一樣，創造一個 Catalog，輸入對應的 URL 並且指名為 Helm v3 的版本。
然後接者創立 Namespace，因為使用 namespace，所以要先利用前述的 data 取得目標 project 的 ID，這樣就可以把這個 namespace 掛到特定的 project 底下。

最後透過 catalog 名稱, Template 的名稱與版本來創造 App。
準備完畢後透過 Terraform Apply 就可以於網頁看到 App 被創造完畢了。

![](https://i.imgur.com/7br0h0p.png)

透過 Terraform 的整合，其實可以更有效率的用 CI/CD 系統來管理 Rancher 上的應用程式，如果應用程式本身需要透過 Helm 來進行客製化，這部分也都可以透過 Terraform 內的參數來達成，所以可以更容易的來管理 K8s 內的應用程式，有任何需求想要離開時，就修改 Terraform 上的設定，然後部署即可。
