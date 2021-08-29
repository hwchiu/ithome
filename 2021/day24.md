Day 24 - Rancher Fleet 玩轉第一個 GitOps
======================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言
前篇文章探討了 Fleet 的基法用法與操作介面，而本文將要正式踏入到 Rancher Fleet GitOps 的世界中
為了使用 GitOps 來部署，必須要先準備一個 Git 的專案來放置要部署的資源，

本篇文章使用的範例都會放到我準備的一個公開 Git Repo [Fleet Demo](https://github.com/hwchiu/fleet_demo)

# Workspace
前述提到大部分 Rancher Fleet 的資源都是基於 Kubernetes CRD 去描述的，因此除了透過網頁操作外也是可以準備一個相關的 YAML 檔案，只要將該 YAML 給部署到 Kubernetes 內， Fleet Controller 就會根據該資源進行對應的操作與更新。

一開始先從簡單的部分開始練習，嘗試透過 GitOps 幫忙創建與管理 Workspace，預設的情況下叢集會有 fleet-default 與 fleet-local 這兩個 workspace，所以目標是想要創造兩個不同的 workspace，分別是 prod 以及 testing.

Workspace 的 YAML 非常簡單，一個範例如下

```yaml=
apiVersion: management.cattle.io/v3
kind: FleetWorkspace
metadata:
  name: prod
  namespace: prod
```

創建一個 FleetWorkspace 的物件，並且針對 name/ns 給予相對應的資料即可，因此針對兩個 workspace 準備兩個檔案，並且將這兩個檔案放到 git 專案下的 workspace 資料夾底下。示意圖如下。

```bash
╰─$ tree .
.
└── workspace
    ├── production.yaml
    └── testing.yaml

```

將上述內容給推向遠方 Git 專案中後，下一步就是要讓 Fleet 知道請追蹤這個 Git Repo 並且將相關的內容給部署到 Kubernetes 內。
切換到 Fleet 的介面，選擇到 Fleet-Local 這個 workspace 並且於 GitRepo 的頁面中點選創立，這時候可以看到如下的介面

![](https://i.imgur.com/Se9QTqQ.png)

該介面中我們需要設定幾個資訊
1. GitRepo 物件的名稱
2. Git 專案的 URL
3. Git 專案的 Branch
4. Git 專案是否需要透過權限去純取。
5. 要從 Git 專案中的哪個位置去尋找相關 YAML 檔案。

因為示範專案是公開的，所以(4)可以直接忽略。
第五點要特別設定成 workspace/，因為前述我們將兩個 workspace 的 YAML 放到 workspace 資料夾底下。

創立完畢後就會看到系統上創建了一個名為 workspace 的 Git 物件，該物件的狀態會從 GitUpdating 最後變成 Active。

由於 fleet-local 這個 workspace 中只有一個 cluster，也就是 local，因此剛剛創立的 GitRepo 只會將相關資源給安裝到這個 local cluster 中，所以可以看到圖中顯示的 Clusters Ready 標示為 1。

![](https://i.imgur.com/noIccKk.png)

點選 workspace 這個資源進去可以看到更多關於該 GitRepo 的資訊，譬如相關的資源有哪些。
範例中可以看到底下提供了兩個屬於 FleetWorkspace 的物件，分別為 prod 以及 testing，這兩個物件都安裝到對應的 namespace 中。

![](https://i.imgur.com/W73XX5i.png)

之前也有提過針對每個 GitRepo 所掃描出來的物件都會創造出一個最基本的 Bundle 物件，該物件會描述這個應用程式的所有內容。所以切換到 Bundle 介面去尋找 workspace，可以看到如下的範例。

![](https://i.imgur.com/H2wLe5q.png)

該 bundle 會把所有要安裝的資源都集中起來，同時因為這次的範例非常簡單，沒有要針對任何 Cluster 去客製化與過濾，所以 targets/targetRestrictions 都是空白的。
此時點選 workspace 的介面或是上方的選單，會發現先前描述的 testing 與 prod 這兩個 workspace 已經被自動創立了，這意味者 Fleet 已經自動地從 Git 專案中學習到要部署什麼資源，並且把資源給成功的部署到 Kubernetes 內，最後的結果也如預期一樣。

![](https://i.imgur.com/p4vYQ5o.png)

# 用 Fleet 管 GitRepo
下一個範例就是希望透過 Fleet 管理 GitRepo 物件，畢竟能夠盡可能減少 UI 操作是追求自動化過程中不可避免的一環。

首先到 GitRepo 中將該 Workspace 的物件移除，移除後可以觀察到 Bundle 中關於 prod/testing 的物件都不見，同時 workspace 中只剩下 fleet-local 以及 fleet-default.

![](https://i.imgur.com/4m3JS12.png)


為了讓 Fleet 幫忙管理，我們需要準備一個描述 GitRepo 的 YAML 檔案，將該檔案放到專案中的 repos/local 底下。
```yaml=
kind: GitRepo
apiVersion: fleet.cattle.io/v1alpha1
metadata:
  name: fleet-demo
  namespace: fleet-local
spec:
  repo: https://github.com/hwchiu/fleet_demo.git
  branch: master
  paths:
    - workspace/
  targets:
    - clusterSelector: {}
```

該 Yaml 描述的內容跟前述透過 UI 創建 GitRepo 是一致的，當系統中有愈來愈多應用程式要管理的時候，就修改該物件，讓 Paths 指令更多路徑即可。

準備好該物件後，接下來還是要到 Fleet UI 去創建一個 GitRepo 物件，該 GitRepo 物件是用來幫忙管理所有 GitRepo 物件的，因此必須要先手動創建一次，接下來就可以依賴 GitOps 的流程幫忙管理。

![](https://i.imgur.com/zG1Q5nQ.png)

這邊先創造一個新的 GitRepo 物件，該物件指向 repos/local。

![](https://i.imgur.com/9hAw5dL.png)

所以整個流程就會變成
1. Fleet 去讀取 Git 專案底下 repos/local 內的物件
2. repos/local 內的物件被套用到 Kubernetes 後就會產生另外一個名為 fleet-demo 的 GitRepo 物件
3. fleet-demo 物件會再次的去把專案內的 workspace/ 給抓進來進行後續安裝。

一切準備完畢後，會觀察到 GitRepo 列表呈現的如下圖，會有兩個 GitRepo

![](https://i.imgur.com/y2spnow.png)

這時候如果點進去 fleet-demo 這個 GitRepo，可以看到該 GitRepo 會部署兩個 workspace，同時最上方還有一個額外的 label，該 label 是由 helm 產生的。
前述提過 Fleet 會將所有資源都動態的轉換為 Helm 格式。

![](https://i.imgur.com/H5l63mh.png)

# 轉移 Cluster
創立好兩個不同的 workspace 後，可以嘗試將三個預先創立的 k8s cluster 給搬移過去，舉例來說將
rke-qa 以及 ithome-dev 這兩套叢集搬移到 testing workspace，而 rke-it 則搬移到 prod workspace。

![](https://i.imgur.com/BgO5dvT.png)
![](https://i.imgur.com/JDtrh4W.png)


下一步就是真正實務上的需求，部署應用程式。為了讓 Fleet 安裝應用程式，所以也需要幫忙準備一個 GitRepo 的物件。針對 testing 以及 prod 各準備一個，並且依序放到 repos/testing, repos/prod 底下。

```bash
╰─$ cat prod/app-basic.yaml
kind: GitRepo
apiVersion: fleet.cattle.io/v1alpha1
metadata:
  name: prod-app
  namespace: prod
spec:
  repo: https://github.com/hwchiu/fleet_demo.git
  branch: master
  paths:
    - app/basic
  targets:
    - clusterSelector: {}
╰─$ cat testing/app-basic.yaml
kind: GitRepo
apiVersion: fleet.cattle.io/v1alpha1
metadata:
  name: testing-app
  namespace: testing
spec:
  repo: https://github.com/hwchiu/fleet_demo.git
  branch: master
  paths:
    - app/basic
  targets:
    - clusterSelector: {}
```

目前系統上還沒有 app/basic 資料夾，可以先不用管它。


上述兩個 GitRepo 的差異處有兩個
1. 名稱不同
2. 安裝的 namespace 不同，注意這邊的 namespace 要跟 workspace 的名稱一致。

接者我們要讓最原始的 repos 一起幫忙處理這兩個 GitRepo，將 repos/local 底下的檔案修改為
```
╰─$ cat local/repos.yaml
kind: GitRepo
apiVersion: fleet.cattle.io/v1alpha1
metadata:
  name: fleet-demo
  namespace: fleet-local
spec:
  repo: https://github.com/hwchiu/fleet_demo.git
  branch: master
  paths:
    - workspace/
    - repos/testing
    - repos/prod
  targets:
    - clusterSelector: {}
```

這時候整個專案呈現如下

```bash
╰─$ tree -l
.
├── repos
│   ├── local
│   │   └── repos.yaml
│   ├── prod
│   │   └── app-basic.yaml
│   └── testing
│       └── app-basic.yaml
└── workspace
    ├── production.yaml
    └── testing.yaml
```

當這些修改都推到遠方 Git 專案後就會觀察到 fleet-local 下的兩個 GitRepo 物件都變成 NotReady 的狀態，如下

![](https://i.imgur.com/BjBqZOn.png)

以 Fleet 的角度來解釋就是
1. fleet-demo 這個 GitRepo 本身會希望安裝三個路徑底下的物件，分別是 workspace/ repos/testing, repos/prod, 只要其中有一個沒有順利部署完成，身為老爸的 fleet-demo 也就自然不能說自己完成
2. fleet-demo 這個物件是由 repos 這個 GitRepo 去動態產生的，因此 fleet-demo 本身沒有順利完成的話，repos 物件也沒有辦法說自己順利完成。

接者點進去 fleet-demo 看一下到底是什麼物件沒有順利完成，可以看到剛剛創立的 prod-app 以及 testing-app 這兩個物件也都沒有完成，所以跟 workspace 無關。

![](https://i.imgur.com/HqOHvNx.png)

這時候切換到 testing 的 workspace，可以觀察到系統上的 testing-app GitRepo 是呈現紅色的字眼，叫做 Git Updating。
同時最上方有顯示相關錯誤訊息，告知使用者為什麼該專案目前不能正常運作。
其訊息告知 Fleet 沒有辦法從 專案底下的 app/basic 路徑找到可以用的 Kubernetes 物件，因此沒有辦法順利安裝資源，所以標示為錯誤。

![](https://i.imgur.com/44jcTgJ.png)

為了解決這個問題，我從官方範例中複製了一個簡單的 Deployment 物件，將該物件給放到 apps/basic 底下。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: guestbook
      tier: frontend
  replicas: 3
  template:
    metadata:
      labels:
        app: guestbook
        tier: frontend
    spec:
      containers:
      - name: php-redis
        image: gcr.io/google-samples/gb-frontend:v4
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 80
```


將這個物件推向遠方的 Git 專案後就可以觀察到 testing-app 成功順利的安裝物件到叢集中，由於 testing 的 workspace 底下有兩個不同的 cluster， ithome-dev 以及 rke-qa。
所以這個物件就會自動的安裝到這兩個叢集中。

![](https://i.imgur.com/Ekolpcx.png)

這時候如果去 cluster explorer 的介面可以看到 deployment 中有一個名為 frontend 的 deployment 物件被創建出來。

![](https://i.imgur.com/vYpIApg.png)

本篇文章到這邊為止，我們嘗試透過 Fleet GitOps 的方式來管理 Fleet 本身並且部署了第一個應用程式，下一篇文章將來探討如何針對不同的 Cluster 給予不同的客製化，譬如 ithome-dev 跟 rke-qa 可以使用不同的參數或是檔案來部署。
