Day 24 - Rancher Fleet.yaml 檔案探討
===================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言
前篇文章用很簡易的方式去探討如何使用 Fleet 的 GitOps 概念來管理資源，最後面用一個非常簡易的 Deployment 物件來展示如何讓 Fleet 將該資源部署到三個叢集中。

實務上使用的情境會更加複雜，譬如說
1. 應用程式來源不同，有的是純 YAML 檔案，有的是透過 Helm 包裝，有的是透過 Kustomize 去包裝
2. 希望針對不同叢集有不同客製化，以 Helm 來說可能不同的叢集要給不同的 values.yaml

因此接下來的文章就會針對上述兩個概念來探討，到底於 Fleet 中要如何滿足上述要求。

# GitRepo 掃描方式

Fleet 中要先準備 GitRepo 的物件，該物件中會描述
1. Git URL
2. 檔案的路徑來源

準備好該 GitRepo 物件後， Fleet 就會去掃描該 Git 專案並且掃描底下的路徑，接者從裡面找出可以使用的 Kubernetes 資源檔案。

實際上 Fleet 的運作邏輯更加複雜，因為 Fleet 支援下列幾種變化
1. 原生 YAML 檔案
2. Helm Chart
3. Kustomize

這三種變化大抵上可以分成五種不同的檔案來源，分別是
1. Chart.yaml
2. kustomization.yaml
3. fleet.yaml
4. *.yaml
5. overlays/{name}

Helm Chart 本身又分成兩種部署方式，分別是
1. 使用遠方的 Helm Server
2. 將 Helm Chart 直接放到 Git 專案中，所以專案內會有 charts.yaml, templates 等檔案。

將上述的概念整合請來大抵上就是

1. 當路徑上有 Chart.yaml 檔案時，Fleet 就會認為要使用 Helm Chart 的概念去部署
2. 當路徑上有 kustomization.yaml 檔案時， Fleet 就會認為要使用 Kustomize 的方式來部署應用程式
3. 當路徑上有 fleet.yaml 檔案時， Fleet 會依照該檔案中的作法去部署，實務上都會使用 fleet.yaml 去描述部署的策略
4. 當路徑上沒有 Chart.yaml 與 kustomization.yaml 時，Fleet 就會使用最直覺的 Kubernetes 資源去部署
5. overlays/{name} 這是針對(4)情況使用的客製化部署，是專門針對純 Kubernetes 資源的客製化。

前篇文章只有準備一個 deployment.yaml，所以就會踩到 (4) 這種部署方式。實務上最常使用的就是 fleet.yaml，fleet.yaml 可以直覺去呈現每個應用程式針對不同叢集的客製化設定，同時還可以做到混合的效果，譬如單純使用 Helm Chart, 單獨使用 Kustomize，或是先 Helm Chart 再 Kustomize 的混合部署。

所以可以知道 Fleet.yaml 可以是整個 Fleet 部署的重要精靈與靈魂，所有的應用程式都需要準備一個 fleet.yaml

# Fleet.yaml

Fleet.yaml 是一個用來控制 Fleet 如何去處理當前資料夾下的 YAML 檔案，該用什麼方式處理以及不同的叢集應該要如何客製化。
每一個 fleet.yaml 都會被產生一個對應的 Fleet Bundle 物件，所以通常會將 fleet.yaml 放到每個應用程式的最上層路徑。

Fleet.Yaml 的詳細內容如下，接下來根據每個欄位介紹一下

```YAML=

defaultNamespace: default

namespace: default

kustomize:
  dir: ./kustomize

helm:
  chart: ./chart
  repo: https://charts.rancher.io
  releaseName: my-release
  constraint
  version: 0.1.0
  during
  values:
    any-custom: value
  valuesFiles:
    - values1.yaml
    - values2.yaml
  force: false

paused: false

rolloutStrategy:
    maxUnavailable: 15%
    maxUnavailablePartitions: 20%
    autoPartitionSize: 10%
    partitions:
    - name: canary
      maxUnavailable: 10%
      clusterSelector:
        matchLabels:
          env: prod
      clusterGroup: agroup
      clusterGroupSelector: agroup

targetCustomizations:
- name: prod
  namespace: newvalue
  kustomize: {}
  helm: {}
  yaml:
    overlays:
    - custom2
    - custom3
  specified,
  clusterSelector:
    matchLabels:
      env: prod
  clusterGroupSelector:
    matchLabels:
      region: us-east
  clusterGroup: group1
```

defaultNamespace/namespace
defaultNamespace 代表的是如果 Kubernetes YAML 資源沒有標示 namespace 的話，會自動的被部署到這個 defaultNamespace 所指向的位置。

namespace 則是強迫將所有資源給安裝到某個 namespace 中，要特別注意的是如果目標 namespace 中已經有重複的資源的話，安裝可能會失敗，這點跟正常的 kubernetes 資源一樣。

kustomize:
熟悉 kustomize 的朋友一定都知道 kustomize 習慣上都會透過一個又一個資料夾搭配 kustomization.yaml 來客製化資源，對於 Fleet 來說給予一個相對的資料夾位置， Fleet 就會嘗試尋找該資料夾底下的 kustomization.yaml 並且客製化。

helm:
Helm Chart 本身有兩種使用方式，一種是讀取遠方 Helm Server 上面的物件，一種是本地的 Helm 物件，因此 helm 格式內就有 chart/repo 等不同欄位要交互使用。
之後的文章都會有這些的使用範例，所以這邊就不詳細列出使用方式。

如果採用的是 helm server 的話，還可以指名想要安裝的版本，同時可以透過兩種不同的方式來客製化，一種是直接使用 values:.... 的格式來撰寫，這種方式適合少量客製化的需求，當客製化的數量過多時就推薦使用第二種 valuesFiles 的方式來載入客製化內容。

pause:
Pause 的用途是讓 Fleet 單純做版本掃描確認有新版本，但是不會幫忙更新 Kubernetes 內的資源，管理人員需要自己手動從 UI 去點選 force update 來更新。
預設情況下都是 false，就代表 Fleet 不但會確認新舊差異也會幫忙更新資源。

rolloutStrategy:
Fleet 的用途是管理大量叢集的部署，因此其提供的 rolloutStrategy 的選項來客製化叢集間的更新策略，基本上跟 Kubernetes Deployment 的更新策略非常雷同，同時間可以有多少個 Cluster 可以處於更新的狀態，

這個欄位中主要分成兩大類
1. 如何將 Group 分類，稱為 Partition
2. 如何針對所有的 Group/Partition 去設定更新的比率

targetCustomizations:
這個欄位是整個 Fleet.yaml 最重要的部分
前述的 Helm/Kustomization 代表的是如何渲染當前路徑底下的 Kubernetes YAML 檔案。
而 targetCustomizations 則是要如何針對不同的 Kubernetes 叢集進行二次客製化

重要的是下方三個選項，如何選擇一個 Cluster，有三種不同方式
1. clusterSelector
2. clusterGroupSelector
3. clusterGroup

其中(2)/(3)兩個都是針對 Cluster Group 直接處理，所以如果有相同類似的 Cluster 就可以直接群組起來進行處理，不然就要使用第一種方式透過 selector 的方式去處理。
clusterSelector 的方式跟 Kubernetes 內大部分的資源處理一樣，都是透過 Label 的方式去處理。
Label 可以於 UI 方面透過點選的方式去加入這些 label，當然也可以透過 Terraform 去創建 RKE Cluster 的時候一起給予 Label。

從網頁要給予 Label 的話，就點選到 Cluster 頁面，找到目標的 Cluster ，點選 Edit Config/Edit YAML 都可以。

![](https://i.imgur.com/WPaL9gv.png)

接者於畫面中去填寫想要使用的 Label，這些 Label 就可以於 fleet.yaml 去客製化選擇。

![](https://i.imgur.com/mMjpf7X.png)


如果想要嘗試 Cluster Group 的話也可以嘗試將不同的 Cluster 給群組起來，之後的範例都可以嘗試看看。

![](https://i.imgur.com/KsGCgPv.png)

# 簡單範例
以下範例節錄自[官網範例](https://github.com/rancher/fleet-examples/blob/master/multi-cluster/helm-external/fleet.yaml)

```yaml=
namespace: fleet-mc-helm-external-example
helm:
  chart: https://github.com/rancher/fleet-examples/releases/download/example/guestbook-0.0.0.tgz
targetCustomizations:
- name: dev
  helm:
    values:
      replication: false
  clusterSelector:
    matchLabels:
      env: dev

- name: test
  helm:
    values:
      replicas: 3
  clusterSelector:
    matchLabels:
      env: test

- name: prod
  helm:
    values:
      serviceType: LoadBalancer
      replicas: 3
  clusterSelector:
    matchLabels:
      env: prod
```

上述的 fleet.yaml 非常直覺
1. 使用 遠方的 Helm Chart 檔案作為目標來源
2. 使用 env 作為 label 來挑選三個不同的 cluster
3. 每個 cluster 使用時都會設定不同的 value 內容。

下篇文章就會嘗試使用這些概念來實際部署應用程式