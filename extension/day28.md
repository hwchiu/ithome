[Day28] Service Catalog
=======================

> 本文同步刊登於 [hwchiu.com - Device Plugin(RDMA)](https://www.hwchiu.com/k8s-device-plugin-rdma.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- Device Plugin


有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

探討完 Operator Pattern 後，我們來探討最後一個關於 kubernetes 擴充功能有關的元件， Service Catalog
這個元件其實我很少聽到有人在談，至少就我自己的瞭解其他滿多人都沒有聽過這個元件，也不知道這個元件可以做什麼，能夠提供什麼樣的好處.

於是今天我們稍微來探討一下這個擴充元件的基本概念，包含運作流程，部署架構以及使用情境.


# 介紹
開始之前，先來思考一下一個使用情境，假設你作為一個 kubernetes 叢集管理人員，今天公司有使用公有雲服務  AWS 作為背後的營運商.

這種情況下有一天，前線的應用程式開發人員跟你說，我們接下來需要一個 database 以及一個 redis 的支援，你可能會怎麼做？

1. 直接到 AWS 的服務上面透過 ElasticCache + RDS 去創造出需要的 **Redis** 以及 **Datbase**，並且準備好相關的存取資訊
2. 將存取資訊，譬如帳號密碼，連接 URL 等資訊轉交給應用程式開發人員進行使用

接下來，譬如需要給 **QA** 測試的環境，或是正式上線的環境，這些環境基於考量希望使用全新的資源，這時候你又要再次重複上述的流程，去創建資源，準備資訊

當然有些事情可以透過其他的解決工具，譬如 **Terraform** 來幫忙創建資源，達成 **Infrastructure as a Code (IaaC)** 的概念，用程式化的方式來完成這些資源的創造，也是一種有效率又好維護的方法。

那上述的這些行為有沒有另外一種解決方案? 因為我所有的服務都是跟 **kubernetes** 綁定，有沒有辦法連這些資源都是透過 **kubernetes** 一起管理?
譬如我創造一個 **yaml** 檔案，裡面描述說我想要有一個 **redis**，接者該 **redis** 就會被創造出來，並且把相關的資訊都放到 **kubernetes secret** 之中去保存。 同樣的 **database** 也是透過 **yaml** 來描述。 這樣就可以基於 **kubernetes** 底下用不同的 **namespace** 來管理不同環境用到的資源

這個方法就是今天要介紹的 **Service Catalog**，透過 **Service Catalog** 相關的應用程式與遠方的 **Service Provider** 連接，並且傳達幫忙創造 **Redis/Database** 的請求到遠方的 **Service Provide**並回傳相關資訊。


# 架構
這邊直接使用下圖來瞭解一下整個架構，並且用上述的範例來解釋這些架構中的角色分別扮演什麼元件

圖中總共有六個名詞(角色)，分別是
1. API Server
2. Service Catalog
3. Serivce Broker
4. Open Service Broker API
5. Application
6. Managed Service
![](https://i.imgur.com/jhEXwKN.png)
上圖節錄自[kubernetes service catalog](https://kubernetes.io/docs/concepts/extend-kubernetes/service-catalog/)

首先 **Serivce Broker** 可以想成是 **AWS** 的角色，而 **Managed Serivce** 就是上述範例中要求的 **Redis** 或是 **Database**。

所以可以看到 **Service Broker** 跟 **Managed Service** 是屬於同一個方框。

接下來可以看到 **API Server**， 這邊指的就是 **kubernetes API server**，旁邊的 **Service Catalog** 代表的是一個運行於 **Kubernetes** 內的 Controller，主要是 **Service Catalog** 這個專案的應用程式。

接下來中間有一個 **OPen Service Broker API** 則是一個標準 API，**Service Catalog** 利用此標準與各式各樣的 **Service Broker** 溝通，這意味者任何的服務供應商只要有實作一個基於 **Open Service Broken API**，就可以跟 **Kubernetes Serivce Catalog** 直接整合使用，不需要額外的程式碼修正或是更新。

最後的 **Application** 就是上述開發者的應用程式。

接下來把上述圖片中的一些連線關係講得更清楚一些，代表什麼意思。

1. API Server <--> Serive Catalog
Service Catalog Controller 本身實作了新的 **kubernetes API** 以及支援其他資源，譬如 **ServiceInstance, ServiceBinding** 等。所以本身也會跟 **kubernetes API** 互動來處理各式各樣資源的創造。
2. Service Catalog <---> Service Broker A
Service Catalog Controller 會透過 Open Service Broker API 與 Broker 溝通，主要有三個功能需要透過該API來處理
    - 詢問對方有提供什麼服務可用
    - 請對方幫忙創建服務(譬如創建 Redis，這個動作稱為 Provision)
    - 請對方提供該服務的連線資訊，譬如帳號密碼， URL 等(這個動作稱為 Binding)
3. Service Catalog <---> Application
當 Service Catalog 透過 API 創建好相關的資源，並且透過 **Bind** 取得資訊，就可以把這些資訊傳遞應用程式，透過 **kubernetes secret** 的方式讓應用程式使用
4. Appliction <---> Managed Service
當應用程式透過 **kubernetes secret** 取得服務的資訊後，就可以正式的連接到遠方 Service Broker 所創建的資源，這個連線指的就是應用程式與服務的連線。

有興趣的歡迎觀賞這個影片 [Intro: Service Catalog SIG - Jonathan Berkhahn, IBM & Carolyn Van Slyck, Microsoft Azure](https://www.youtube.com/watch?v=bm59dpmMhAk)，裡面介紹了這個功能的起源，以及怎麼使用。

# 範例
接下來打算使用一個範例來分享到底使用起來會是什麼樣的情境，本範例基於[Service Catalog Walkthrough](https://svc-cat.io/docs/walkthrough/#step-1---installing-the-ups-broker-server)

## 安裝 Service Catalog
可以透過 **helm** 的方式來安裝 **Service Catalog** 的服務
```bash=
$ helm repo add svc-cat https://svc-catalog-charts.storage.googleapis.com
$ helm install svc-cat/catalog --name catalog --namespace catalog

vagrant@k8s-dev:~$ kubectl api-resources | grep servicecatalog.k8s
clusterservicebrokers                          servicecatalog.k8s.io          false        ClusterServiceBroker
clusterserviceclasses                          servicecatalog.k8s.io          false        ClusterServiceClass
clusterserviceplans                            servicecatalog.k8s.io          false        ClusterServicePlan
servicebindings                                servicecatalog.k8s.io          true         ServiceBinding
servicebrokers                                 servicecatalog.k8s.io          true         ServiceBroker
serviceclasses                                 servicecatalog.k8s.io          true         ServiceClass
serviceinstances                               servicecatalog.k8s.io          true         ServiceInstance
serviceplans                                   servicecatalog.k8s.io          true         ServicePlan
```

可以觀察到安裝完畢之後，系統上多出了不少相關的定義，包含了 **serviceborkers**, **serviceclasses**, **serviceinstances** 等各類資訊

## 安裝minibroker
接下來機會安裝一個基於測試開發用的 **Serive Broker**, minibroker

這部分也可以透過 **helm** 的方式進行安裝
```bash=
helm repo add minibroker https://minibroker.blob.core.windows.net/charts
helm install --name minibroker --namespace minibroker minibroker/minibroker
```

接者我們就可以觀察上述的這些資源，來瞭解目前多了哪些資源可以用
```bash
vagrant@k8s-dev:~$ kubectl get --all-namespaces clusterservicebrokers
NAME         URL                                                         STATUS   AGE
minibroker   http://minibroker-minibroker.minibroker.svc.cluster.local   Ready    65m
```

首先透過 **clusterservicebrokers** 可以看到有一個新增的 **service broker**，包含對應的 **URL**，這部分是用 **Kubernetes service** 與 **DNS** 來處理連接行為的。

接下來看一下這個 **minibroker** 提供什麼服務可以創造
```
vagrant@k8s-dev:~$ kubectl get --all-namespaces clusterserviceclasses
NAME         EXTERNAL-NAME   BROKER       AGE
mariadb      mariadb         minibroker   66m
mongodb      mongodb         minibroker   66m
mysql        mysql           minibroker   66m
postgresql   postgresql      minibroker   66m
redis        redis           minibroker   66m
```
透過觀察 **clusterserviceclasses** 可以看到提供了五種類型，四種資料庫搭配一個 Redis 來創建，非常的有趣是吧

這邊的 **class** 代表是類別，接下來可以透過 **plan** 的方式看到更細緻的資訊
```bash=
vagrant@k8s-dev:~$ kubectl get --all-namespaces clusterserviceplans  | grep redis
redis-3-2-9                3-2-9              minibroker   redis        72m
redis-4-0-10               4-0-10             minibroker   redis        72m
redis-4-0-10-debian-9      4-0-10-debian-9    minibroker   redis        72m
redis-4-0-11               4-0-11             minibroker   redis        72m
redis-4-0-12               4-0-12             minibroker   redis        72m
redis-4-0-13               4-0-13             minibroker   redis        72m
redis-4-0-14               4-0-14             minibroker   redis        72m
redis-4-0-2                4-0-2              minibroker   redis        72m
redis-4-0-6                4-0-6              minibroker   redis        72m
redis-4-0-7                4-0-7              minibroker   redis        72m
redis-4-0-8                4-0-8              minibroker   redis        72m
redis-4-0-9                4-0-9              minibroker   redis        72m
redis-5-0-4                5-0-4              minibroker   redis        72m
redis-5-0-5                5-0-5              minibroker   redis        72m
```

各種版本的 **Redis** 都有提供，接下來我們就用範例試試看來創建這些資源

## Provision


```yaml=
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceInstance
metadata:
  name: mini-instance
  namespace: test-ns
spec:
  clusterServiceClassExternalName: mariadb
  clusterServicePlanExternalName: 10-1-26
  parameters:
    param-1: value-1
    param-2: value-2
```

上述的 **yaml** 描述了需要的資源 **mariadb** 以及對應的版本 **10-1-26**，同時若該服務有額外參數可以傳遞，也可以透過 **parameters** 一併傳送到最後的 **service broker** 去處理。

```bash=
vagrant@k8s-dev:~$ kubectl get --all-namespaces serviceinstances
NAMESPACE   NAME            CLASS                         PLAN      STATUS   AGE
test-ns     mini-instance   ClusterServiceClass/mariadb   10-1-26   Ready    39m
```

這時候只有單純的資源創造，還沒有對應的連線資訊，所以接下來透過 **binding** 的方式來處理

```yaml=
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceBinding
metadata:
  name: mini-binding
  namespace: test-ns
spec:
  instanceRef:
    name: mini-instance
```

非常簡單的格式，最重要的時一但這個資源創建完畢後，系統也會順便產生一個 **secret** 來放置相關的資訊
```bash=
vagrant@k8s-dev:~$ kubectl -n test-ns describe secret mini-binding
Name:         mini-binding
Namespace:    test-ns
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
username:               4 bytes
Protocol:               5 bytes
host:                   49 bytes
mariadb-password:       10 bytes
mariadb-root-password:  10 bytes
password:               10 bytes
port:                   4 bytes
uri:                    78 bytes
```

可以看到這時候系統上產生了對應的資訊，接下來我們嘗試看看這些數值
```bash=
vagrant@k8s-dev:~$ kubectl -n test-ns get secret mini-binding -o json  | jq '.data | map_values(@base64d)'
{
  "Protocol": "mysql",
  "host": "eager-greyhound-mariadb.test-ns.svc.cluster.local",
  "mariadb-password": "cWmMvYGu9W",
  "mariadb-root-password": "E8KJnmqrrt",
  "password": "E8KJnmqrrt",
  "port": "3306",
  "uri": "mysql://root:E8KJnmqrrt@eager-greyhound-mariadb.test-ns.svc.cluster.local:3306",
  "username": "root"
}
```

這邊可以看到各種連線的資訊，同時也可以觀察 pod 的資訊
```bash=
vagrant@k8s-dev:~$ kubectl -n test-ns get all
NAME                                           READY   STATUS    RESTARTS   AGE
pod/eager-greyhound-mariadb-647888fb8b-gdcf8   1/1     Running   0          72m

NAME                              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/eager-greyhound-mariadb   ClusterIP   10.103.69.162   <none>        3306/TCP   72m

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/eager-greyhound-mariadb   1/1     1            1           72m

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/eager-greyhound-mariadb-647888fb8b   1         1         1       72m
```

可以看到創建了 deployment 以及 service 來幫忙完成這些資源的連動。

# Summary

本篇介紹的 **Service Catalog** 可以讓管理者直接在 **Kubernetes** 內直接去得到需要的服務資源，譬如 **Redis** 或是資料庫之類的，當然資源的多寡還是依據每家 **Service Broker** 去設計與處理，通過這個方式也是可以拿到 **IaaC** 的架構來建置服務。

# 參考
- https://kubernetes.io/docs/concepts/extend-kubernetes/service-catalog/
- https://www.youtube.com/watch?v=bm59dpmMhAk
- https://svc-cat.io
- https://svc-cat.io/docs/install/
- https://svc-cat.io/docs/walkthrough/#step-4---creating-a-new-serviceinstance
