Day 28 - Rancher Fleet Helm 應用程式部署
======================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言
前篇文章探討了基於 Kustomize 的客製化行為，另外一個常見的應用程式處理方式就是 Helm， Helm 採用的是基於 template 的方式來動態渲染出一個可用的 YAML。
本篇文章就會探討兩種不同使用 Helm 的方式。

本篇所有 YAML 範例都來自於[官方範例](https://github.com/rancher/fleet-examples)。

# 本地 Helm Chart
Helm Chart 基於 go-template 的方式來客製化 Yaml 內的數值，這意味者 Helm Chart 本身所擁有的 YAML 其實大部分情況下都不是一個合法 YAML，都需要讓 Helm 動態的將相關數值給填入到 Helm YAML 中來產生最後的檔案內容。

下方是一個 Helm YAML 的範例

```yaml=
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  selector:
    matchLabels:
      app: guestbook
      tier: frontend
  replicas: {{ .Values.replicas }}
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

可以看到 replicas 的部分抽出來，變成一個 template 的格式，搭配下方的 values.yaml
```yaml=
replicas: 1
```
Helm 就會動態的將 replicas 的數值給填入到上方的 template 來產生最終要送到 Kubernetes 內的 YAML 物件。

有了基本概念之後，就可以來看看如何透過 Fleet 來管理 Helm 的應用程式。

這次的應用程式會直接使用 Helm 內建的範例應用程式，透過 helm create $name 就可以創建出來
所以移動到 app 資料夾底下，輸入 helm create helm 即可
```bash=
╰─$ helm create helm
Creating helm
╰─$ tree helm
helm
├── Chart.yaml
├── charts
├── templates
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml
```

該 Helm 的範例應用程式會部署一個 nginx 的應用程式，並且為其配上一個 service + ingress 的服務。

這次希望透過 Fleet 為兩個不同的 workspace 去部署不同的環境，意味者 testing workspace 底下的兩個叢集(dev/qa) 採用一組設定，而 prod workspace 底下的 it 叢集採用另外一組設定。

修改的部分採取簡單好理解即可
針對 testing 的環境
1. replica 設定為 2 份，

prod 的環境
1. replica 為 3
2. 開啟 Ingress 物件

為了完成這件事情針對 workspace 下多個 cluster 統一設定，必須要先完成下列之一
1. 將群組給 group 起來
2. 給叢集有對應的 Label

因此先到 UI 部分將 Prod Workspace 底下的 cluster (rke-it) 給予一個 env=prod 的 Label.

![](https://i.imgur.com/oSonaCI.png)

接者到 testing workspace 底下創建一組 Cluster Group，創建 Cluster Group 的時候可以根據條件去抓到符合條件的 Cluster，預設情況下沒有設定的話就是全抓。
系統還會告訴你目前有多少個 Cluster 符合當前的 Selector，以我們的環境來說該 workspace 底下有兩個不同的 cluster。

![](https://i.imgur.com/6E0Wkq8.png)

一切準備就緒後就來準備 Fleet.yaml

```bash=
╰─$ cat fleet.yaml
namespace: helminternal
targetCustomizations:
- name: prod
  helm:
    values:
      replicaCount: 3
      ingress:
        enabled: true
        hosts:
          - host: rancher.hwchiu.com
            paths:
              - /testing
  clusterSelector:
    matchLabels:
      env: prod

- name: test
  helm:
    values:
      replicaCount: 2
  clusterGroup: testing-group
```

因為 Fleet 會自己偵測若路徑中有 Chart.yaml 檔案的話，就會使用 Helm 的方式去處理，所以不需要特別於 Fleet.yaml 中去描述需要使用 Helm。
這次的範例會安裝到 helminternal 這個 namespace 中，接者底下針對兩種不同的客製化。
如果 cluster 本身含有 env:prod 這種標籤的話，就會將其的複本數量設定為 3 個，並且將 ingress 給設定為 enable，為了讓 Ingress 物件可以順利創立，需要針對 hosts 底下的物件也給予設定，這邊隨便寫就好，目的只是測試 ingress 物件的部署。

另外一個則是直接使用 testing-group 這個 cluster group，對其底下的所有 cluster 都設定副本數為 2 。

記得也要對 repo/*/app-basic.yaml 兩個檔案去增加 app/helm 的路徑，這樣 GitRepo 才知道也要去掃描 app/helm 的路徑。

一切都部署完畢後，使用 kubectl 去觀察部署的資源，可以觀察到 rke-it 這個屬於 prod workspace 的叢集被部署了三個副本的 deployment 外加一個 ingress 資源。

![](https://i.imgur.com/OSmniAp.png)

至於 testing workspace 下的兩個叢集的部署資源都一致，都只有兩個副本的 deployment，沒有任何 ingress 物件。

![](https://i.imgur.com/OpBSCK8.png)
![](https://i.imgur.com/1tXFuiQ.png)

# 遠方 Helm Chart
實務上並不是所有部署到團隊中的 Helm Chart 都是由團隊自行維護的，更多情況下可能是使用外部別人包裝好的 Helm Chart，譬如 Prometheus-operator 等。

這種情況下專案的路徑內就是透過 fleet.yaml 來描述要使用哪個遠方的 Helm Chart 以及要如何客製化。

這邊直接使用[官方 Helm-External的範例](https://github.com/rancher/fleet-examples/blob/master/multi-cluster/helm-external/fleet.yaml) 來操作。

首先先於 app 資料夾底下創建一個 helm-external 的資料夾，因為這次不需要準備 Helm Chart 的內容，所以直接準備一個 fleet.yaml 的檔案即可。

fleet.yaml 內容如下
```bash=
╰─$ cat fleet.yaml
namespace: helmexternal
helm:
  chart: https://github.com/rancher/fleet-examples/releases/download/example/guestbook-0.0.0.tgz
targetCustomizations:
- name: prod
  helm:
    valuesFiles:
      - prod_values.yaml
  clusterSelector:
    matchLabels:
      env: prod

- name: test
  helm:
    valuesFiles:
      - testing_values.yaml
  clusterGroup: testing-group
```

如果要使用遠方的 Helm Chart，總共有兩種不同的寫法，一種是參考上述直接於 chart 中描述完整的下載路徑。
針對一般的 Helm Chart Server 來說會更常使用下列這種形式
```yaml
helm:
    repo: https://charts.rancher.io
    chart: rancher-monitoring
    version: 9.4.202
```

這種形式更加容易理解要去哪個 Helm Chart 抓取哪個版本的 Helm Chart 應用程式。

接者這次的 fleet.yaml 要採用不同的方式去進行客製化，當 Helm Values 的客製化非常多的時候，有可能會使得 fleet.yaml 變得冗長與複雜，這時候可以透過 valuesFiles 的方式，將不同環境用到的 values 內容給獨立撰寫成檔案，然後於 fleet.yaml 中將該檔案給讀取即可。

```bash=
╰─$ cat prod_values.yaml
serviceType: NodePort
replicas: 3
╰─$ cat testing_values.yaml
serviceType: ClusterIP
replicas: 2
```

上述兩個設定檔案就是針對不同副本去處理，同時 prod 環境下會將 service 給轉換為 NodePort 類型。
一切完畢後記得修改 repo/*/app-basic.yaml 內的路徑。
注意的是這邊的 replica/serviceType 只會影響 Helm 裏面的 frontend deployment/service，純粹是對方 helm chart 的設計。

部署完畢後透過 kubectl 觀察部署的狀況

可以觀察到 prod workspace 底下的 rke-it 叢集內的確將 frontend 的 replica 設定成 3個，同時 frontend 的 service 也變成 NodePort

![](https://i.imgur.com/9KtHBrB.png)

而剩下兩個叢集也符合預期的是一個兩副本的 deployment 與 ClusterIP

![](https://i.imgur.com/gBIgY4P.png)
![](https://i.imgur.com/BoYaSKt.png)

下篇文章將來探討 fleet 最有趣的玩法，Helm + Kustomize 兩者結合一起運行。