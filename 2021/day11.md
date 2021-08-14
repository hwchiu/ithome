Day 11 - Rancher 叢集管理指南 - 監控介紹
=====================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言

前篇文章探討了 Rancher 叢集的基本使用方式，包含透過取得 KUBECONFIG 以及使用 Rancher 提供的網頁來觀察與操作 Rancher 叢集。
除了基本叢集的狀態顯示外， Rancher 也有整合一些常用的應用程式到 Rancher 管理的叢集中，而其中有一個功能基本上是所有 Kubernetes 叢集都需要的功能，也就是 Monitoring。
Monitoring 可以使用的專案非常多，有免費開源也有付費服務，免費開源最知名的組合技大概就屬 Prometheus + Grafana 兩套功能。
Rancher 所提供的 Monitoring 功能就是基於 Prometheus + Grafana 來使用的，本篇文章就來介紹一下這個功能到底該怎麼使用。

# Rancher
Rancher 從 v2.5 開始正式推行 Monitoring v2 的架構，並且淘汰過往的 Monitoring v1 的版本。
從使用者的角度來看，從 Cluster Manager 頁面中透過 Monitoring 安裝的都會是 Monitoring v1 的架構，而透過 Cluster Explorer 中 App & Marketplace 安裝的 Monitoring 則會是 Monitoring v2 的架構。

探討 Monitoring v1與v2 的差異前，先來瞭解一下 Rancher 希望提供什麼樣的 Monitoring 功能給使用者。
從使用者角度出發來看，大部分人都會希望可以有下列的功能
1. 安裝 Prometheus 到叢集中，能夠有機會去聽取所有資訊
2. 安裝 Grafana 到叢集中，同時該 Grafana 能夠跟 Prometheus 直接整合，能夠透過 Grafana 去打造出一個適合團隊用的監控面板
3. 能夠使用 Alert 的相關功能，不論是由 Prometheus 或是 Grafana 提供的。
4. 對於使用者所部署的應用程式也能夠整合到 Prometheus 中，一旦能夠整合到 Prometheus，就有辦法透過 Grafana 去處理。
5. 對於 Prometheus 與 Grafana，能夠提供一個有效簡單的方式去存取這兩個服務的網頁


上述五點的前兩點比較偏向安裝 Prometheus/Grafana 的問題，第三與第四點相對麻煩，畢竟使用者如果已經習慣 Prometheus/Grafana 本來的設定與玩法，這時候要是 Rancher 本身的介面弄得太複雜，可能會讓使用者要重新學習如何修改，這點對使用者體驗來說是一個很大的考量。
最後一點也是最麻煩的一點，因為 Rancher 所管理的 Kubernetes 叢集不一定都有對外 IP 可以被直接存取，同時每個環境也不一定有合法的 SSL 憑證可以讓使用者以 HTTPS 的方式去存取這些網頁。

但是對於使用者來說，如果安裝完畢後還要去擔心煩惱這些 IP, Domain Name, SSL 等相關問題，這樣的使用者體驗就不會太好，為了解決這個問題， Rancher 特別針對這一塊進行了所謂的 Proxy 存取。
由於 Rancher 有辦法跟管理的 Kubernetes 叢集溝通，而通常 Rancher 本身安裝時都有準備好 HTTPS 與相關的 domain。所以使用方式就會變成，使用者存取 Rancher 本身， Rancher 作為一個 Proxy 幫忙轉發所有跟 Prometheus/Grafana 網頁有關的存取，讓使用者可以更為輕鬆地去存取封閉式網路的 Monitoring 相關頁面。
這部分之後的實驗就可以更加清楚理解到底是什麼意思。


# V1/V2

上述提到的五個概念中，v1 的版本會於 Rancher 中安裝相關的 Controller，如果使用者想要自己的應用程式可以被 Prometheus 去抓資料的話，就要於自己的部署 YAML 中去撰寫是先定義好的 Annotation，Controller 判別到有這個 Annotation 後就會將自動產生一個關於 Prometheus 的物件來提供此功能。

v1 的這種設計對於不熟悉 Prometheus 的使用者來說很便利，可以輕鬆地處理，但是其提供的變數過少，沒有辦法太有效的客製化，因此如果是熟悉 Prometheus 的使用者則會覺得綁手綁腳，沒有辦法發揮全部功能。
再來其實 Monitoring v1 底層也是基於 Prometheus Operator 這套框架去實作的，Rancher 基於這個框架再去實作一個 Controller 幫助使用者轉換各種規則，這層規則對於已經習慣使用 Prometheus Operator 的使用者來說也是綁手綁腳，因為本來就很習慣直接操作 Prometheus Operator 的物件去操作。

因此 Monitoring v2 的最大進展就是， Rancher 將讓 Prometheus Operator 盡可能地浮出來，減少 Rancher 的抽象層。使用者有任何的客製化需求都直接使用 Prometheus Operator 的方式去管理，譬如可以直接創造如 ServiceMonitor, PrometheusRule 等物件來管理叢集中的 Prometheus。

接下來我們就直接使用 DEV 叢集作為示範，如何安裝 Monitoring v2，並且最後使用  https://github.com/bashofmann/rancher-2.5-monitoring 這個專案內的介紹來嘗試部署應用程式以及相關的 Prometheus/Grafana 資訊到叢集中。

# 環境

前述提到，要安裝 Monitoring v2 要切換到 Cluster Explorer 中的 App & Marketplace 去安裝，切換到該頁面找到相關的 App 就點選安裝。
結果示範的叢集顯示下列警告，告知叢集內可被預訂的 CPU 數量低於需求，該 App 需要 4.5 顆 CPU而系統內不夠

![](https://i.imgur.com/TVudBYk.png)

由於 DEV 叢集是透過 Azure 動態創建 VM 而搭建出來的叢集，所以切換到 Cluster Manager 去修改節點數量，將 worker 節點從一個增加到三個，如下

![](https://i.imgur.com/q5AEBtg.png)

這邊等待數分鐘，讓 Rancher 去處理 VM 的創建並且將這兩個節點安裝到 Rancher 中。一切準備後就緒後就可以回到 Cluster Explorer 去安裝 Monitoring v2 整合功能。
安裝完畢後，可以從左上方的清單中找到 Monitoring 的頁面，點擊進去會看到類似下面的畫面。

![](https://i.imgur.com/gOOiK5b.png)

該畫面中呈現了五個不同的功能，熟悉 Prometheus Operator 功能的讀者一定對這些名稱不陌生，隨便點選一個 Grafana 試試看。
點選 Grafana 後會得到一個新的頁面，效果如下。

![](https://i.imgur.com/hhzKGAF.png)

該畫面呈現的是一個 Grafana 的資訊面板，值得注意的是其 URL 的組成。
前面是由 Rancher Server 本身的位置，後面緊接者該 DEV Cluster 於 Rancher 中的 ID，最後就是對應服務的 namespace 與 service。
透過這種方式使用者就可以繼續使用 Rancher Server 的 HTTPS 與名稱來順利的存取不同叢集上的 Prometheus/Grafana 服務。
而這個服務實際上並不是全部都由 Rancher 所完成的，而是 Kubernetes API Server 本身就有提供這樣的功能，詳細的可以參閱官方的教學文件
[Access Services Running on Clusters](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-services/)

預設情況下，該 Grafana 內會已經創造好非常多的 dashboard，譬如下圖所示

![](https://i.imgur.com/Pz39jtJ.png)

除了 Grafana 之外， Prometheus 的相關網頁也都有，譬如點選 Prometheus Targets 就可以看到如下的畫面

![](https://i.imgur.com/mXEhnHp.png)

此外當系統安裝了 Monitoring 的整合功能後， Cluster Explorer 的首頁也會自動地被加上相關監控資訊，如下所示

![](https://i.imgur.com/9eGcYkq.png)

可以直接於首頁觀察到基本資訊的過往狀態，這邊提供的是非常基礎的效能指標，如果想要看到詳細的指標甚至是客製化，都還是要到 Grafana 的頁面去存取。

# 實驗

透過上述的介紹，基本上已經有一個簡單的 Prometheus + Grafana 的 Monitoring 功能到目標叢集中，接下來要示範如何透過 https://github.com/bashofmann/rancher-2.5-monitoring 這個開源專案來幫我們自己的應用程式加上 Prometheus 與 Grafana 的設定，最重要的是這些設定都是由 YAML 去組成的，意味者這些設定都可以透過 Git 保存與控管，可以避免任何線上修改會因為重啟而消失。

該專案的介面頁面有提供非常清楚的使用流程，這邊針對這些流程重新介紹
1. 安裝一個示範的 Redis 應用程式
2. 幫該 Redis 應用程式安裝一個 sidecar 服務，該服務有實作 Prometheus 介面，可以讓 Prometheus 來抓不同的指標
3. 安裝 ServiceMonitor 到叢集中，讓 Prometheus Operator 知道要怎麼去跟(2)安裝的服務去要 Redis 的資料
4. 安裝一個事先準備好的 Grfana json 描述檔案，能夠讓 Grafana 自動地去產生一個針對 Redis 的監控面板

第一點非常簡單，就是基本的 Kubernetes 服務，這邊就不探討這個 Redis 應用程式到底如何組成，其安裝指令也非常簡單
```bash=
$ kubectl -n default apply -f scrape-custom-service/01-demo-shop.yaml
```
安裝完畢後可以透過下列指令打開 port-forward 並且於瀏覽器打開 http://localhost:8000
```
$ kubectl port-forward svc/frontend 8000:80
```

![](https://i.imgur.com/13kyVzT.png)

可以看到畫面基本上就代表這個示範用的應用程式已經順利安裝完成。

接下來幫 Redis 安裝一個 sidecar 的服務來提供 Prometheus 的介面
```
$ kubectl -n default apply -f scrape-custom-service/02-redis-prometheus-exporter.yaml
```

最後則是最重要的兩點，這兩點是最主要跟 Prometheus/Grafana 溝通用的物件。
``` bash
╰─$ kubectl -n default apply -f scrape-custom-service/03-redis-servicemonitor.yaml
╰─$ cat scrape-custom-service/03-redis-servicemonitor.yaml                                                                                                             130 ↵
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: redis-cart
spec:
  endpoints:
    - interval: 30s
      scrapeTimeout: 20s
      path: "/metrics"
      targetPort: metrics
  namespaceSelector:
    matchNames:
      - default
  selector:
    matchLabels:
      app: redis-cart
```

ServiceMonitor 是 Prometheus Operator 中定義的物件，透過這個方式就可以讓 Prometheus 幫忙產生對應的物件與自定義的應用程式溝通，接者就可以到 Prometheus 的網頁中找到這個新增資訊，如下圖。

![](https://i.imgur.com/SED8IA8.png)

有了上述資源後，我們就可以透過 Prometheus 去問到 Redis 的相關資訊，為了讓這些資訊更方便處理，接下來部署 Grafana 的相關物件
```bash
╰─$ kubectl apply -f scrape-custom-service/04-redis-grafana-dashboard.yaml
╰─$ cat scrape-custom-service/04-redis-grafana-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-redis-cart
  namespace: cattle-dashboards
  labels:
    grafana_dashboard: "1"
data:
  redis.json: |
    {
      "__inputs": [
      ],
      "__requires": [
        {
          "type": "grafana",
          "id": "grafana",
          "name": "Grafana",
          "version": "3.1.1"
```

熟悉 Grafana 的讀者都知道，每個 Grafana 的 dashboard 都可以透過 JSON 物件來描述，所以要新增一個 Grafana dashboard 就是準備一個相對應的 json 物件，使用 configMap 來描述，將該物件給部署到 cattle-dashboards 的 namespace 內即可。

```bash
╰─$ kc -n cattle-dashboards get cm
NAME                                                   DATA   AGE
grafana-redis-cart                                     1      51m
kube-root-ca.crt                                       1      144m
rancher-default-dashboards-cluster                     2      144m
rancher-default-dashboards-home                        1      144m
rancher-default-dashboards-k8s                         4      144m
rancher-default-dashboards-nodes                       2      144m
rancher-default-dashboards-pods                        2      144m
rancher-default-dashboards-workloads                   2      144m
rancher-monitoring-apiserver                           1      144m
rancher-monitoring-cluster-total                       1      144m
rancher-monitoring-controller-manager                  1      144m
rancher-monitoring-etcd                                1      144m
rancher-monitoring-ingress-nginx                       2      144m
rancher-monitoring-k8s-coredns                         1      144m
rancher-monitoring-k8s-resources-cluster               1      144m
rancher-monitoring-k8s-resources-namespace             1      144m
rancher-monitoring-k8s-resources-node                  1      144m
rancher-monitoring-k8s-resources-pod                   1      144m
rancher-monitoring-k8s-resources-workload              1      144m
rancher-monitoring-k8s-resources-workloads-namespace   1      144m
rancher-monitoring-kubelet                             1      144m
rancher-monitoring-namespace-by-pod                    1      144m
rancher-monitoring-namespace-by-workload               1      144m
rancher-monitoring-node-cluster-rsrc-use               1      144m
rancher-monitoring-node-rsrc-use                       1      144m
rancher-monitoring-nodes                               1      144m
rancher-monitoring-persistentvolumesusage              1      144m
rancher-monitoring-pod-total                           1      144m
rancher-monitoring-prometheus                          1      144m
rancher-monitoring-proxy                               1      144m
rancher-monitoring-scheduler                           1      144m
rancher-monitoring-statefulset                         1      144m
rancher-monitoring-workload-total                      1      144m
```

事實上也可觀察到該 namespace 內有滿滿的 configmap，而每個 configmap 內的內容都會對應到一個專屬的 Grafana Dashboard，因此如果想要客製化 Grafana 的資訊，常見的做法都是透過 UI 創造，創造完畢後複製 JSON 的格式，並且將該格式用 ConfigMap 給包裝起來。
上述物件創建完畢後，就可以到 Grafana 的介面去重新整理，順利的話可以看到一個名為 "Redis Dashboard for Prometheus Redis Exporter 1.x" 的 dashboard，如果沒有看到的話就等待一點時間即可。

![](https://i.imgur.com/quWLFhd.png)


最後預設情況下， Grafana 都是基於匿名的唯獨模式去存取的，想要擁有編輯權利的話可以嘗試使用預設的帳號密碼 admin/prom-operator 去登入這個系統來編輯，編輯後記得將 JSON 物件給匯出保存，透過這樣的機制就可以方便的管理 Grafana。

本章簡單探討了一下關於 Rancher Monitoring v2 的用法，如果有需求的人甚至可以不需要到 Cluster Explorer 去安裝，而是可以直接使用 Helm 的方式去安裝相關物件，主要的物件內容是由 rancher-monitoring 這個 Helm Charts 去安裝的，有興趣嘗試可以參考這個官方檔案 [rancher/charts](https://github.com/rancher/charts/tree/release-v2.5/charts/rancher-monitoring)
