Day 19 - Rancher App(v2.5) 介紹
==============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言

前篇文章介紹了 Rancher(v2.0 ~ v2.4) 中主打的應用程式管理系統， Catalog，所有的 Catalog 都必須要於 Cluster Manager 的介面中去管理。

而 Rancher v2.5 開始主打 Cluster Explorer 的介面，該介面中又推行了另外一套應用程式管理系統，稱為 App & Marketplace。

事實上前述的章節就已經有透過這個新的系統來安裝 Monitoring 的相關資源，因此現在 Rancher 都已經使用這個新的機制來提供各種整合服務，因此後續的新功能與維護也都會基於這個新的機制。

使用上我認為兩者還是有些差異，因此對於一個 Rancher 的使用者來說最好兩者都有碰過，稍微理解一下其之間的差異，這樣使用上會更有能力去判斷到底要使用哪一種。

# Rancher App
新版的應用程式架構基本上跟前述的沒有不同，不過名詞上整個大改，相關名詞變得與 Helm 生態系更佳貼近，譬如舊版使用 Catalog 來描述去哪邊抓取 Helm 相關的應用程式，新版本則是直接貼切的稱為 Helm Repo。

Cluster Explorer 的狀態下，左上方點選到 Apps & Marketplace 就可以進入到新版的系統架構，

該架構中左方有三個類別，其中第二個 Charts Repositories 就是新版的 Catalog，畫面如下。

![](https://i.imgur.com/vxscc1f.png)

預設系統上有兩個 Chart Repo，其中之前安裝的 Monitoring 就是來自於這邊。
接者點選右上方的 Create 就會看到新版的創立畫面

![](https://i.imgur.com/spu6lFs.png)

新版本的創建畫面更加簡潔與簡單，首先可以透過 target 來選擇到底要使用 Git 還是 HTTP 來存取，針對 Private Helm Repo 這次則提供了兩種驗證方式，譬如 SSH Key 與 HTTP Basic 兩種方式。

創造完畢後就可以於系統上看到新建立的 Helm Repo，系統預設的兩個 Helm Repo 都是基於 Git 去處理，而本篇文章新創立的則是 HTTP。

![](https://i.imgur.com/amfHMyp.png)

有了 Helm Repo 後，下一步就是要創造應用程式，切換到 Charts 的介面就可以看到如下的畫面。

![](https://i.imgur.com/L8uL7wj.png)

畫面中上方顯示了目前擁有的 Helm Repo 有哪些，這邊可以透過勾選的方式來過濾想要顯示的 Helm Repo
只有單純勾選 dashboard 後就可以看到 kubernetes-dashboard 這個 Helm Chart。

![](https://i.imgur.com/VjV82DY.png)

點選該 kubernetes-dashboard 後進入到新版的安裝設定介面，該畫面中相對於舊版的 Catalog 來說畫面更為簡潔有力。
畫面中，最上方包含了 App 的名稱，該使用的 Helm Chart 版本，範例使用了 4.5.0。

接者下方則是安裝的 namespace ，這些選擇都與舊版的介面差不多。
最下方則列出不同的類別，包含
1. Values
2. Helm README
3. Helm Deploy Options

![](https://i.imgur.com/xYVwLN0.png)

Rancher 新版 App 捨棄了舊版 Answer 的叫法，同時也完全使用 YAML 的格式來設定 values，而不是透過 UI 一行一行慢慢設定。

註: 事實上舊版的 UI 的設定方式其實有滿多問題，某些情況還真的不能設定，透過檔案還是相對簡單與方便。

![](https://i.imgur.com/ErbjAsP.png)

下面的 Helm Deploy Options 有不同的部署選項，譬如
1. 要不要執行 Helm Hooks
2. 部署 Helm 時要不要設定 Timeout，多久的時間沒有成功部署就會判定失敗

![](https://i.imgur.com/kcqmbAO.png)

一切設定完畢後就可以開始安裝，安裝畫面跟 Monitoring 的經驗類似，都會彈出一個 Terminal 畫面來顯示安裝過程。
畫面最下方則是顯示了到底系統是使用什麼指令來安裝 Helm Chart，安裝完畢可以用左上的按鈕離開畫面。

![](https://i.imgur.com/Or73FTW.png)

接者移動到 Installed Charts 可以找到前述安裝的 App，外面提供的 Active 資源數量則是代表所有 Kubernetes 的資源，不單單只是舊版所顯示的 Pod 而已。

![](https://i.imgur.com/ramH92u.png)


新版跟舊版的 App 最大的差異我認為就是 Endpoint 的顯示，舊版的 Catalog 會很好心地將 Endpoint 呈現出來讓使用者可以輕鬆存取這些服務，但是新版卻不會。
要注意的是這些存取實際上是透過 Kubernetes API 去轉發的，所以其實這項功能並不需要 Rancher 特別幫你的應用程式處理什麼，因此如果知道相關的規則，還是可以透過自行撰寫 URL 來存取相關服務網頁，如下。

![](https://i.imgur.com/nLtaHki.png)
![](https://i.imgur.com/IOfNyCX.png)


透過 UI 觀察新版應用程式後，接下來就示範如何透過 Terraform 來管理這種新版本的 Application。

Rancher 於 Terraform 中的實作是將 Catalog 與 App 的概念分開，新的概念都會補上 _v2 於相關的資源類型後面，譬如
catalog_v2, app_v2。

這個範例中的作法跟前述一樣
1. 取得 project 的 ID(此處省略)
2. 透過 catalog_v2 創造 Helm Repo
3. 創造要使用的 namespace
4. 接者使用 app_v2 創造 App

Terraform 的程式碼非常簡單，如下
```bash
resource "rancher2_catalog_v2" "dashboard-global-app" {
  name = "dashboard-terraform"
  cluster_id = "c-z8j6q"
  url = "https://kubernetes.github.io/dashboard/"
}
resource "rancher2_namespace" "dashboard-app" {
  name = "dashboard-terraform-app"
  project_id = data.rancher2_project.system.id
}
resource "rancher2_app_v2" "dashboard-app" {
  cluster_id = "c-z8j6q"
  name = "k8s-dashboard-app-terraform"
  namespace = rancher2_namespace.dashboard-app.id
  repo_name = "dashboard-terraform"
  chart_name = "kubernetes-dashboard"
  chart_version = "4.5.0"
  depends_on       = [rancher2_namespace.dashboard-app, rancher2_catalog_v2.dashboard-global-app]
}
```

其實透過觀察 v2 版本的 API 就可以觀察出來 v2 的改動很多，譬如
1. catalog_v2 (Helm Repo) 移除了關於 Scope 的選項，現在所有的 Helm Repo 都是以 Cluster 為單位，不再細分 Global, Cluster, Project.
2. app_v2 (App) 安裝部分差異最多，特別是 Key 的部分跟貼近 Helm Chart 使用的名詞，使用上會更容易理解每個名詞的使用。
譬如使用 chart_name, chart_version 取代過往的 template, template_version，同時使用 repo_name 取代 catalog_name。
不過如果都要使用 repo_name 了，其實直接捨棄 catalog_v2 直接創造一個新的物件 helm_repo 我認為會更佳直覺一些。

另外 App 移除了對於 Project 的使用，反而是跟 Cluster 有關，變成 App 都是以 Cluster 為基本單位。

當 Terraform 順利執行後，就可以於 App 頁面觀察到前述描述的應用程式被順利的部署起來了，如下圖。

![](https://i.imgur.com/zDs4sSD.png)

到這邊可能會感覺到有點混淆，似乎使用 Cluster Explorer 就再也沒有 Project 的概念了，因此我認為 Rancher v2.6 後續還有很多東西要等，短時間內 Cluster Explorer 沒有辦法完全取代 Cluster Manager 的介面操作，但是部分功能 (Monitoring) 又已經完全轉移到 Cluster Explorer，這會造就管理者可能會兩個功能 (Cluster Explorer/Manager) 都會各自使用一部分的功能。

期許 Rancher 能夠將這些概念都同步過去才有辦法真正的移除 Cluster Manager，或是更可以直接的說過往的某些概念於新版後都不再需要。
