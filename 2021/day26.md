Day 26 - Rancher Fleet Kubernetes 應用程式部署
============================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言

前篇文章探討了 Fleet.yaml 的基本概念，而本篇文章就會針對各種不同的情境來示範如何使用 fleet.yaml 來達到客製化的需求。

本篇所有 YAML 範例都來自於[官方範例](https://github.com/rancher/fleet-examples)。

# Overlay
第一個要示範的情境是使用純 Kubernetes YAML 為基礎的客製化，因為純 Kubernetes YAML 沒有辦法達到類似 Helm/Kustomize 的內容客製化，所以能夠提供的變化有限，頂多只能做到不同檔案的資源部署。

假設今天總共有四種資源，該四種資源為
1. Deployment A
2. Service A
3. Deployment B
4. Service B

希望達到的客製化為
Dev 叢集安裝
1. Deployment A
2. Service A

IT 叢集安裝
1. Deployment A
2. Service A
3. Deployment B

QA 叢集安裝
1. Deployment A
2. Service A
3. Deployment B
4. Service B

前述有提過，對於純 YAML 來說，Fleet 提供一個名為 overlay 的資料夾來客製化，因此先於專案中的 app 底下創建一個 basic_overlay 的資料夾。

由於 deployment A 這個資源三個叢集都需要，所以可以放到最外層，讓所有叢集共享，只需要針對(2)/(3)/(4) 進行客製化即可。

客製化的作法很簡單，於 overlays 底下創建不同的資料夾，然後於資料夾中放置想要客製化的檔案即可。
這時候的架構應該會長得很類似下圖

```bash=
╰─$ tree .
.
├── fleet.yaml
├── frontend-deployment.yaml
└── overlays
    ├── dev
    │   └── frontend-service.yaml
    ├── it
    │   ├── frontend-service.yaml
    │   └── redis-master-deployment.yaml
    └── qa
        ├── frontend-service.yaml
        ├── redis-master-deployment.yaml
        └── redis-master-service.yaml
```

這邊先忽略 fleet.yaml 的內容，仔細看剩下的內容。
frontend-deployment 就是 deployment A 的服務，而 overlays 底下的資料夾對應了三個不同的叢集，每個叢集內都放置更多的資源。
譬如 dev 底下多了 frontend-service，就是所謂的 Service A
it 相較於 dev 又新增了 redis-master-deployment.yaml, 也就是 Deployment B
qa 相較於 it 又新增了 redis-master-service.yaml, 也就是 service B

這些檔案都準備完畢後，接下來要做的就是準備一個 fleet.yaml 的檔案，讓 Fleet 要針對不同叢集讀取不同環境。

前述提到 Fleet.yaml 中會透過 label 的方式來選擇目標叢集，沒有特別設定的情況下，每個叢集會有一些預設的 label 可以使用。切換到該叢集並且以 YAML 方式瀏覽就可以觀察到這些預設 label.

![](https://i.imgur.com/Hvny9T6.png)

上圖中呈現了三種 label，其中第一種是比較適合人類閱讀的，該 label 呈現了叢集的名稱，key 為 management.cattle.io/cluster-display-name
所以接下來 fleet.yaml 中就可以透過這個 label 來比對不同的 cluster。

```
namespace: basicoverlay
targetCustomizations:
- name: dev
  clusterSelector:
    matchLabels:
      management.cattle.io/cluster-display-name: ithome-dev
  yaml:
    overlays:
    - dev

- name: it
  clusterSelector:
    matchLabels:
      management.cattle.io/cluster-display-name: rke-it
  yaml:
    overlays:
    - it

- name: qa
  clusterSelector:
    matchLabels:
      management.cattle.io/cluster-display-name: rke-qa
  yaml:
    overlays:
    - qa
```

上述是一個 Fleet.yaml 的範例，該 Fleet.yaml 希望將所有資源都安裝到 basicoverlay 這個 namespace 中。

接者於 targetCustomizations 的物件中，針對三個不同環境撰寫不同的 clusterSelector。
範例中使用 cluster-name 來比對，符合 ithome-dev 使用 overlays 這個語法來讀取特定的環境，將 overlays/dev 中的資料夾一併納入部署。
剩下兩個環境如法炮製，一切都準備完畢之後，最後修改 repo/prod/app-basic.yaml 以及 repo/testing/app/app-basic.yaml 讓其知道要掃描 app/basic_overlay 這個路徑。

```bash=
╰─$ cat repos/prod/app-basic.yaml
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
    - app/basic_overlay
  targets:
    - clusterSelector: {}
╰─$ cat repos/prod/app-basic.yaml
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
    - app/basic_overlay
  targets:
    - clusterSelector: {}
```


一切準備完畢後就將修改給推到遠方的 Git 專案，然後靜靜等者 Fleet 開始處理。
當 Testing workspace 底下的 GitRepo 呈現 Active 後就代表環境已經部署完畢了。

![](https://i.imgur.com/WocOIMX.png)

這時候點選進去可以看到更為詳細的內容，因為 Fleet 還是一個非常嶄新的專案，我認為其還有很多值得改近的地方，譬如當前的 UI 就會將 Fleet.yaml 中描述的所有資源都一起放進來，而不是針對叢集客製化的資源去顯示，這一點會容易混淆人。希望下一個版本 (v0.3.6) 有機會修復。

![](https://i.imgur.com/vurWDrf.png)

一切完畢後透過 kubectl 去觀察三個叢集下 basicoverlay 內的資源變化

dev 的叢集可以看到只有 deployment A 配上 service A 的資源

![](https://i.imgur.com/EiLQZUy.png)

it 叢集除了 dev 叢集的資源外，還多了 deployment B 也就是 redis-master 的 Pod.

![](https://i.imgur.com/9Pe0a9W.png)

qa 叢集則最完整，擁有 Deployment(A,B) 以及 Service (A,B)

![](https://i.imgur.com/BX6Pu8u.png)

下篇文章將針對 Kustomize 的範例介紹