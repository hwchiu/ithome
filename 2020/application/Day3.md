Day 3 - Helm 介紹
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



上篇文章探討了關於 Kubernetes 內應用程式的包裝方式，提到了一些相關的議題，包含了如何散佈安裝檔案，同時支援不同版本的選擇，以及客製化的選項。

因此本篇我們將來介紹 Helm3 這個工具，同時也會介紹 Helm 是如何實現上述所提過的各種議題



## Helm

根據官方敘述, Helm 是一個管理 Kubernetes 應用程式的套件，透過 Helm Charts 這套系統，可以幫助開發者打包，安裝，升級相關的 Kubernetes 應用程式。

此外， Helm Charts 本身也被設計得很容易去創造，版本控制，分享以及發佈，所以透過 Helm Charts 就可以避免到處 Copy-and-Paste 各式各樣的 Yaml。

Helm 本身也是一個開源專案，而且也是 [CNCF](https://cncf.io/) 內的畢業專案，目前是由  [Helm 社群](https://github.com/helm/community) 進行維護

> Helm helps you manage Kubernetes applications — Helm Charts help you define, install, and upgrade even the most complex Kubernetes application.
>
> Charts are easy to create, version, share, and publish — so start using Helm and stop the copy-and-paste.
>
> Helm is a graduated project in the [CNCF](https://cncf.io/) and is maintained by the [Helm community](https://github.com/helm/community).





Helm 的架構概念非常簡單，就是將整包 Kubernetes 的所有資源物件再疊加一層抽象層，這個抽象層是給 Helm 工具使用的，Helm 的工具會有自己的方式去解讀這個抽象層，最後產生出最後的 Kubernetes 資源物件然後安裝到 Kubernetes 裡面

## Purpose

Helm 將所有 Kubernetes 的應用程式都統稱為 `Charts`.

Helm 的工具會將這些 Charts 打包成 **tgz** 的檔案，接下來可以可以透過 Helm Charts Server 的方式將這個 **tgz** 的檔案給散佈出去，讓其

他使用者可以方便地取得這些已經打包好的應用程式(Charts)。

此外， Helm 的工具也可以直接針對這些 Charts 所描述的應用程式去安裝到/解除於 Kubernetes 叢集中

對於安裝到 Kubernetes 中的應用程式， Helm 稱其為 `Release` 

而 Chart 到 Release 中間有一個客製化的概念，稱為 Config，透過這個 config 可以產生出適應不同環境的 Kubernetes Yaml



這三者如下圖所示，每個 Charts 搭配不同環境的設定檔案最後會產生出一個唯一的 Release 物件，而該物件就代表者該應用程式於 Kubernetes 內的實體

![](https://i.imgur.com/60lEp4A.jpg)





## 客製化

為了滿足客製化的需求，希望開發者可以簡單的設計 Charts，使用者又可以簡單的客製化使用，這部分 Helm 採用的是 Go Template 的方式來進行 Yaml 的客製化，舉例來說

下面一個常見的 Service Yaml 檔案，內容全部都寫死

```
apiVersion: v1
kind: Service
metadata:
  name: example
  labels:
		app: example
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: example
    app.kubernetes.io/instance: example
```

這種情況下使用者就沒有辦法客製化需求，譬如需要的 Port(80)，或是不同類型 (ClusterIP/NodePort)

Helm 針對這種情況引入了 Go Template，使得 Yaml 檔案的樣子可能會變成如下圖

```yaml=
apiVersion: v1
kind: Service
metadata:
  name: {{ include "example.fullname" . }}
  labels:
{{ include "example.labels" . | indent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: {{ include "example.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
```

可以看到上述的採用大量的 `{{}}` 的格式來進行變數的替換，使用者再使用該 Charts 的時候會對上述的變數進行設定，而這些變數最後在渲染這些 Template 檔案的時候就會給替換掉最後產生出真正的 Yaml 檔案。

舉例來說，第一個使用者安裝的時候輸入 `service.type: ClusterIP`  就會產生出一個使用 `ClusterIP` 的 Service，而若輸入的是 `service.type:NodePort`  則會產生使用 `NodePort` 的 Service.



為了方便使用者去使用，開發者設計的時候可以準備一套預設值放到一個名為 `values.yaml` 的檔案裡面，使用者可以直接修改該檔案或是使用別的檔案來替換所有的變數



這種 Go Template 的方式的確可以讓 Yaml 變得很彈性，可以讓使用者針對不同情境傳入不同的數值，但是我認為他也帶來的更多的複雜性，因為這些 Template 的用法十分多元，從基本的變數替換，到 FOR 迴圈， IF 判斷條件等都可以使用。
對於 Helm 用法不理解的人初次看到這些滿滿被 `{{}}` 入侵的 Yaml加上一堆不確定是幹嘛用的關鍵字，其實會難以入手，沒有花更多時間去理解的情況下，可能就只會使用而沒有辦法成為一個開發者去設計一個好的 Helm Chart



## 散播與發佈

當開發者準備好一個 Helm Charts 的檔案時候，就可以透過打包的方式將其上傳到官方或是自行維護的 Helm Chart 伺服器

一個使用範例如下(參考自官網)

```bash
$ helm repo add stable https://kubernetes-charts.storage.googleapis.com/
$ helm search repo stable
NAME                                    CHART VERSION   APP VERSION                     DESCRIPTION
stable/acs-engine-autoscaler            2.2.2           2.1.1                           DEPRECATED Scales worker nodes within agent pools
stable/aerospike                        0.2.8           v4.5.0.5                        A Helm chart for Aerospike in Kubernetes
stable/airflow                          4.1.0           1.10.4                          Airflow is a platform to programmatically autho...
stable/ambassador                       4.1.0           0.81.0                          A Helm chart for Datawire Ambassador
...

```

上述指令代表的意思是我想要將 `https://kubernetes-charts.storage.googleapis.com/` 這個 Helm Charts 的伺服器加入到本地 `Helm` 指令的來源之一，並且嘗試搜尋上面任何有 `stable` 字眼的 Helm Chart



下列指令則可以嘗試安裝 `stable/mysql` 這個 Helm Chart 到 Kubernetes 中，產生的 Release 名稱為 `smiling-penguin`

這邊要注意的是 Helm 本身會需要存取 Kubernetes 叢集，所以也是使用 KUBECONFIG 等方式來設定存取權限

```bash
$ helm install stable/mysql --generate-name
Released smiling-penguin
```



最後可以透過 `Helm ls` 的指令來觀看目前安裝於叢集內的 Helm Release.

```bash
$ helm ls
NAME             VERSION   UPDATED                   STATUS    CHART
smiling-penguin  1         Wed Sep 28 12:59:46 2016  DEPLOYED  mysql-0.1.0
```



## Helm v2 v.s Helm v3

Helm 目前流通的版本有 Helm v2 以及 Helm v3，使用起來差別不會非常誇張，但是如果是新上手的朋友強烈建議直接上 Helm v3，而不要使用 Helm v2，否則後來還要處理更新搬移的問題。

官方網站就有專門一個頁面在介紹如何從 Helm2 搬移至 Helm3, [Migrating Helm v2 to v3](https://helm.sh/docs/topics/v2_v3_migration/), 有興趣的人可以點進去看更多詳細的介紹。

下面來列一下 [v3 以及 v2 最大的差異](https://v3.helm.sh/docs/faq/#changes-since-helm-2)

1. Tiller 的移除，過往使用 Helm v2 的時候，還要在系統內先行安裝一個叫做 Tiller 的伺服器，同時也要對其設定一些權限，安裝起來麻煩，同時也有潛在的安全性問題。 Helm v3 基本上整個架構變得更乾淨，只需要一個 Helm 指令即可
2. Helm Chart 裡面相關的 apiVersion 需要跳號，從 v1 跳到 v2，才會宣告該 Helm Chart 是屬於 Helm v3.
3. 更新應用程式的策略， v3 使用的是三方比對來進行測試，將會使用 `過往狀態`, `當前運作狀態` 以及 `期望狀態` 來比對，最後產生更新後的內容
4. OCI 的支援，這個是我覺得最有趣的功能，未來 Helm Chart 打包後的格式可以遵循 OCI (Open Contaianer Initiative) 的格式，這意味者我們未來將有機會使用 Container Registry 來存放 Helm Chart, 只需要一個伺服器就可以同時滿足 Container Image 以及 Helm Chart，如果有興趣的人可以嘗試使用 Harbor 這套 Contaienr Registry 的解決方案來體驗看看這個功能

> 想要知道更多關於 OCI 的介紹，可以參考這篇[文章](https://www.hwchiu.com/container-design-i.html)

5. Helm 一些子指令的新增與移除



基本上修改的細部內容非常多，有興趣的建議參考上述官方連結去看看修改細節，可以更加瞭解 Helm3.



