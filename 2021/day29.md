Day 29 - Rancher Fleet Helm + Kustomize 應用程式部署
=================================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言
前篇文章探討了基於 Helm 的客製化行為，透過兩種不同方式來部署 Helm 的應用程式，透過 Helm Values 的設定可以讓管理人員更容易的去設定與處理不同的設定。

實務上如果採用的是遠方 Helm Chart Server 的部署方式，還是有機會遇到綁手綁腳的問題，譬如想要針對某些欄位客製化，但是該 Helm Chart 卻沒有定義等
這時候就可以補上 Kustomize 來進行二次處理，應用程式先透過 Helm 進行第一層處理，接者透過 Kustomize 進行二次處理，幫忙 Patch 一些不能透過 values.yaml 控制的欄位。

本篇所有 YAML 範例都來自於[官方範例](https://github.com/rancher/fleet-examples)。

# Helm + Kustomize

使用遠方 Helm Chart 來部署應用程式的人可能都會有下列的經驗
1. Helm Values 沒有提供自己想要的欄位
2. 如果該 Helm Chart 裡面需要 secret 的物件，需要自己額外部署，沒有辦法跟該 Helm Chart 融為一體。

不同問題會有不同解決方法，譬如
1. 嘗試針對該 Helm Charts 提交 PR 去增加更多的 values 欄位可以使用。這種情況的解法比較漂亮，但是要花比較長的時間來處理程式碼的合併與審核。
2. 複製遠方的 Helm Chart 到本地環境中，手動修改欄位符合自己需求，沒有將修改推回遠方的 upstream.
3. 團隊內創造一個全新的 Helm Chart，該 Helm Chart 透過 requirement 的概念來使用本來要用的 Helm Chart，接者於自己的環境中補上其他資源。

如果 Helm Values 沒有提供自己想要的欄位，那(1)/(2) 這兩種解法都可以處理，畢竟都有能力針對本來的 Helm YAML 進行改寫。
但是如果今天的需求是想要加入一些全新的 YAML 檔案，譬如上述的 Secret 物件，那(1)/(2)/(3) 三種方法都可以採用。

第一個方法需要花時間將修改合併到 upstream 的專案，而第二個方法其實維護起來很麻煩，因為每次遠方有任何版本更新時都要重新檢查。第三個方法又不能針對 values 的方式去客製化。

Fleet 中提供了一個有效的方式來解決這個困境，就是 Helm + Kustomize 的組合技
透過 Helm 進行第一次的渲染，接者透過 Kustomize 的方式可以達到
1. 動態增加不同的 Kubernetes 物件
2. 透過 Kustomize 的 Patch 方式可以動態修改欄位

因此上述的情境問題就可以完美解決。

註: Kustomize 今年的新版本也嘗試提供 Helm 的支援，讓你可以透過 Kustomize 的方式去部署 Helm 的應用程式，詳細可以參考 [kustomization of a helm chart
](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/chart.md)

本次的範例繼續使用前篇文章的 Helm Chart，使用 Rancher 提供的 guestbook 作為遠方的 Helm Chart 檔案，接者透過 Kustomize 的方式來動態修改欄位與增加資源。

這次的環境部署要求如下。
預設情況下先透過 Helm Values 將 frontend 的副本數調高為 3

dev 叢集:
1. 將 serviceType 改成 LoadBalancer

it 叢集:
1. 將 redis-slave 的副本數改成 0 (預設是2)

qa 叢集:
1. 新增一個基於 nginx 的 deployment

有了這些概念後，就來準備相關的檔案，這次於 app 底下創建名為 helm_kustomize 的資料夾，並且於裡面先準備一個 fleet.yaml 的檔案。

```yaml=
╰─$ cat fleet.yaml
namespace: helmkustomize
helm:
  chart: https://github.com/rancher/fleet-examples/releases/download/example/guestbook-0.0.0.tgz
  values:
    replicas: 3
targetCustomizations:
- name: dev
  clusterSelector:
    matchLabels:
      management.cattle.io/cluster-display-name: ithome-dev
  kustomize:
    dir: overlays/dev

- name: it
  clusterSelector:
    matchLabels:
      management.cattle.io/cluster-display-name: rke-it
  kustomize:
    dir: overlays/it

- name: qa
  clusterSelector:
    matchLabels:
      management.cattle.io/cluster-display-name: rke-qa
  kustomize:
    dir: overlays/qa
```

上述的 fleet.yaml 中首先透過 helm chart 去抓取遠方的 helm chart server，接者透過 values 的方式將 frontend 的副本數設定為三個。

接下來是叢集客製化的部分，每個叢集這次採用叢集名稱作為比對的方式，接者使用 kustomize 的方式去 overlays 底下的資料夾來客製化。

```bash
╰─$ tree .
.
├── dev
│   ├── frontend-service.yaml
│   └── kustomization.yaml
├── it
│   ├── kustomization.yaml
│   └── redis-slave-deployment.yaml
└── qa
    ├── deployment.taml
    └── kustomization.yaml

```

```bash=
╰─$ cat dev/frontend-service.yaml
kind: Service
apiVersion: v1
metadata:
  name: frontend
spec:
  type: LoadBalancer
╰─$ cat dev/kustomization.yaml
patches:
- frontend-service.yaml


╰─$ cat it/kustomization.yaml
patches:
- redis-slave-deployment.yaml
╰─$ cat it/redis-slave-deployment.yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: redis-slave
spec:
  replicas: 0


╰─$ cat qa/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx-server
        image: nginx

╰─$ cat qa/kustomization.yaml
resources::
- deployment.yaml
```

準備好這些檔案並且修改 repo/*/app-basic.yaml 後，就可以將修改給推到遠方的 Git 專案，接者等待 Fleet 來幫忙處理部署。

使用 kubectl 工具觀察

Dev 的環境可以觀察到
1. Frontend 的 replica 是三個副本
2. Service 的類型改成 LoadBalancer

![](https://i.imgur.com/UwKJ01E.png)

IT 的環境可以觀察到
1. Frontend 的 replica 是三個副本
2. redis-slave 的 replica 變成 0

![](https://i.imgur.com/vVjqDoY.png)


QA 的環境可以觀察到
1. Frontend 的 replica 是三個副本
2. 新的一個 Deployment 叫做 test，有三個副本。

![](https://i.imgur.com/ymvu1mT.png)

可以發現環境中的部署條件都有如先前所述，算是成功的透過 Helm + Kustomize 的方式來調整應用程式。


Fleet 本身發展的時間不算久，因此 UI 上有時候會有一些額外的 Bug，這些除了看官方文件外剩下都要看 Github 上的 issue 來找問題。

此外 Fleet 於 08/28/2021 正式推出 v0.3.6 版本，不過因為如果想要單純使用 Rancher 來使用的話，那這樣就必須要等待新版本的 Rancher 一起推出才可以直接享用新版本的整合。