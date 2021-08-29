Day 27 - Rancher Fleet 客製化應用程式部署(二)
=========================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言
前篇文章探討了基於純 Kubernetes YAML 的客製化行為，因為純 Kubernetes YAML 沒有辦法針對檔案內的 YAML 客製化，只能使用不同的檔案來部署，如果想要針對檔案內容進行客製化，這時候就要使用 Kustomize 或是 Helm 等技術來處理，本篇文章就來看看如何透過 Kustomize 來客製化應用程式。

本篇所有 YAML 範例都來自於[官方範例](https://github.com/rancher/fleet-examples)。

# Kustomize
這邊簡單說明一下 Kustomize 的概念， Kustomize 是基於 Patch 的概念去客製化 YAML 內容。
Patch 意味者環境中必須要先擁有一個基本檔案，接者還要有一個描述差異的檔案， Patch 就是將這個差異處給蓋到這個基本檔案上。 這樣就可以達到一個客製化。

舉例來說有一個 Deployment 如下，該檔案就是所謂的基本檔案(Base)。
```yaml=
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-slave
spec:
  selector:
    matchLabels:
      app: redis
      role: slave
      tier: backend
  replicas: 2
  template:
    metadata:
      labels:
        app: redis
        role: slave
        tier: backend
    spec:
      containers:
      - name: slave
        image: gcr.io/google_samples/gb-redisslave:v1
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 6379
```

接者要準備一個描述差異處的檔案(patch)
```
kind: Deployment
apiVersion: apps/v1
metadata:
  name: redis-slave
spec:
  replicas: 0
```

該差異處希望將 redis-slave 的 replicas 從 2 修改成 0。
Kustomize 基於這種概念去描述所有檔案，環境要先準備一個名為 kustomization.yaml 的檔案，該檔案會告訴 kustomize 要去哪邊尋找 base 檔案，要去哪邊尋找 patch 檔案，最後將這兩者結合產生出最終檔案，譬如

```yaml=
resources:
- ../../base
patches:
- redis-slave-deployment.yaml
- redis-slave-service.yaml
```

上述範例是告知 Kustomize 請到 ../../base 去找尋所有的基本 YAML 檔案(base)，接者使用當前資料夾底下的兩個檔案作為 patch，該 patch 就會嘗試跟 base 中相對應的內容進行合併最後產生出差異化。

有了基本概念之後，接下來就準備來使用 Kustomize 客製化應用程式，這次繼續使用類似上次的應用程式。
假設環境中依然有四個資源，分別是
1. Deployment A
2. Service A
3. Deployment B
4. Service B

這次三個叢集都會部署這四個資源，不過會透過 Kustomize 來客製化調整內容，這些參數於 base 環境中的預設值如下
1. Deployment A: Replica: 1
2. Service A: Type: ClusterIP
3. Deployment B: Replica: 1
4. Service B: Type: ClusterIP

dev 叢集
1. Deployment A -> Replica: 2
2. Deployment B -> Replica: 2

it 叢集
1. Deployment A -> Replica: 3
2. Deployment B -> Replica: 3
3. Service B -> NodePort

qa 叢集
1. Deployment A -> Replica: 1
2. Deployment B -> Replica: 3
3. Service A -> NodePort

有了基本概念後，就準備來修改 fleet_demo 的專案內容，先於 app 底下創建一個資料夾為 kustomize，並且先準備好基本資料夾。

```bash=
╰─$ tree .
.
├── base
└── overlays
    ├── dev
    ├── it
    └── qa
```

首先來處理 base 資料夾，該資料夾中總共要放五個檔案，分別是四個 Kubernetes 資源以及一個 kustomization.yaml，該 kustomization.yaml 主要是讓 kustomzie 知道有哪些檔案要載入去部署。

```bash=
╰─$ tree .
.
├── frontend-deployment.yaml
├── frontend-service.yaml
├── kustomization.yaml
├── redis-master-deployment.yaml
└── redis-master-service.yaml
```

上述內容如下
```
╰─$ cat frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: guestbook
      tier: frontend
  replicas: 1
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
╰─$ cat frontend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  labels:
    app: guestbook
    tier: frontend
spec:
  type: ClusterIP
  ports:
  - port: 80
  selector:
    app: guestbook
    tier: frontend
╰─$ cat redis-master-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-master
spec:
  selector:
    matchLabels:
      app: redis
      role: master
      tier: backend
  replicas: 1
  template:
    metadata:
      labels:
        app: redis
        role: master
        tier: backend
    spec:
      containers:
      - name: master
        image: redis
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
        ports:
        - containerPort: 6379
╰─$ cat redis-master-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-master
  labels:
    app: redis
    role: master
    tier: backend
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
  selector:
    app: redis
╰─$ cat kustomization.yaml
resources:
- frontend-deployment.yaml
- frontend-service.yaml
- redis-master-deployment.yaml
- redis-master-service.yaml
```

準備好五個檔案後，接下來就是針對不同客製化環境去準備相關的 Patch

```bash=
╰─$ tree overlays                                                                                                                                                                                                                  1 ↵
overlays
├── dev
│   ├── frontend-deployment.yaml
│   ├── kustomization.yaml
│   └── redis-master-deployment.yaml
├── it
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── kustomization.yaml
│   └── redis-master-deployment.yaml
└── qa
    ├── frontend-deployment.yaml
    ├── frontend-service.yaml
    ├── kustomization.yaml
    ├── redis-master-deployment.yaml
    └── redis-service.yaml
```

準備好的架構如下，這邊只列出 it 環境底下的客製化內容，其餘兩個的修改都非常類似。

```bash=
╰─$ cat kustomization.yaml
resources:
- ../../base
patches:
- frontend-deployment.yaml
- redis-master-deployment.yaml
- frontend-service.yaml

╰─$ cat frontend-deployment.yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: frontend
spec:
  replicas: 3

╰─$ cat frontend-service.yaml
kind: Service
apiVersion: v1
metadata:
  name: frontend
spec:
  type: NodePort

╰─$ cat redis-master-deployment.yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: redis-master
spec:
  replicas: 3
```

該環境中準備了三個不同的 Patch 檔案，並且於 kustomization.yaml 中去描述 base 的來源(../../base)，同時針對當前的環境去使用三個不同的 patch 檔案。

一切準備完畢後接下來就是 fleet.yaml 的環境。

```yaml=
╰─$ cat fleet.yaml
namespace: appkustomize
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

fleet.yaml 的內容跟前述差不多，唯一的差別之前是透過 yaml.overlay 的方式去處理純 Kubernetes YAML，而 Kustomize 則是改成使用 kustomize.dir 來描述目標叢集要以哪個資料夾當作 Kustomize 的起始資料夾。


一切都準備完畢後就將修改的內容推到遠方的 Git，接者就繼續等 Fleet 去處理。
題外話： Fleet 有時候處理上還不夠完善，有可能 UI 跟底層部署沒有同步，底層資源都完畢但是 UI 會顯示 Not-Ready，這種情況下可以嘗試將該 Bundle 給刪除，讓 GitRepo 重新產生一個全新的 Bundle 即可。


部署完畢後透過 kubectl 去觀察三個叢集，是否都如同預期般的部署。

Dev 叢集希望兩種 Deployment 的 Replica 都是 2，且 service 維持預設的 type: ClusterIP.

![](https://i.imgur.com/20l5LNN.png)


IT 叢集希望兩種 Deployment 的 Replica 都是3，同時將 frontend 的 service type 改成 NodePort.

![](https://i.imgur.com/ZZb9XSI.png)

QA 叢集將兩種 deployment 的 replica 改成 1,3 同時兩種 service type 都改成 NodePort.

![](https://i.imgur.com/mLB0KeN.png)

下篇文章將針對 Helm 的用法繼續探討