Day 16 - 應用程式部署 - 應用程式部署
===============================


本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 概念探討
Rancher 作為一個 Kubernetes 管理平台，提供不同的方式將 Kubernetes 叢集給匯入到 Rancher 管理平台中，不論是已經創立的 Kubernetes 或是先透過 Rancher 創造 RKE 接者匯入到 Rancher 中。

但是 Kubernetes 終究只是一個容器管理平台，前述介紹的各種機制或是 Rancher 整合的功能都是輔助 Kubernetes 的維護，對於團隊最重要的還是產品本身，產品可能是由數個應用程式所組合而成，而每個應用程式可能對應到 Kubernetes 內又是多種不同的物件，譬如 Deployment, Service, StorageClass 等。
接下來會使用應用程式這個詞來代表多個 Kubernetes 內的資源集合。

過往探討到部署應用程式到 Kubernetes 叢集內基本上會分成兩個方向來探討
1. 如何定義與管理應用程式供團隊使用
2. 部署應用程式給到 Kubernetes 叢集的流程

# 定義與管理應用程式

Kubernetes 的物件基本上可以透過兩種格式來表達，分別是 JSON 與 YAML，不過目前主流還是以 YAML 為主。
這意味這一個最簡單管理應用程式的方式就是使用一堆 YAML 檔案，檔案內則是各種 Kubernetes 的物件。

這些應用程式本身還需要考慮到下列使用情境
1. 該應用程式會不會需要跨團隊使用
2. 該應用程式是否需要針對不同環境有不同的參數
3. 該應用程式本身有沒有其他相依性，譬如部署 A 應用程式會需要先部署 B 應用程式
4. ...等

上述的這些使用情境是真實存在的，而為了解決這些問題，大部分情況下都不會使用純 YAML 檔案來管理應用程式，譬如想要讓一個 Service 針對不同環境有不同設定就不太好處理，除了準備多個幾乎一樣的檔案外幾乎沒有辦法。
目前主流的管理方式有 Helm, Kustomize，其餘的還有 ksonnet 等。
不同解決方案都採用不同的形式來管理與部署應用程式，舉例來說
使用 Helm 的使用者可以採用下列不同方式來安裝應用程式
1. helm install
2. helm template | kubectl apply -

而使用 kustomize 的使用者則可以使用
1. kustomize ...
2. kubectl -k ...

因為 kubectl 目前已經內建 kustomize 的功能，所以直接使用 kustomize 指定或是 kubectl 都可以。
當團隊選擇好如何管理與部署這些應用程式後，下一個問題就是如何部署這些 Helm/Kustomize 物件到 Kubernetes 叢集。

# 部署流程
基本上所有的部署都以自動化為目標去探討，當然這並不代表手動部署就沒有其價值，畢竟在自動化部署有足夠的信心前，團隊也必定會經歷過各式各樣的手動部署，甚至很多自動化的撰寫與開發也是都仰賴手動部署的經驗。

從 Rancher 的角度來看，自動化部署有三種不同的方式
1. Kubeconfig
2. Rancher Catalog
3. Rancher Fleet

下面稍微探討一下這三者的概念與差異。

# Kubeconfig
一個操作 Kubernetes 最簡單的概念就是直接使用 kubectl/helm 等指令進行控制，而 Rancher 也有針對每個帳戶提供可存取 Kubernetes 叢集所要使用的 KUBECONFIG。

假設團隊已經完成 CI/CD 的相關流程，就可以於該流程中透過該 KUBECONFIG 來得到存取該 Kubernetes 的權限，接者使用 Helm/Kubectl 等功能來部署應用程式到叢集中。

基本上使用這種方式沒有什麼大問題，畢竟 RKE 也是一個 Kubernetes 叢集，所以如果團隊已經有現存的解決方案是透過這種類型部署的話，繼續使用這種方式沒有任何問題。

# Rancher Catalog

Rancher 本身有一個名為 catalog 的機制用來管理要部署到 Rancher 內的應用程式，這些應用程式必須要基於 Helm 來管理。

其底層背後也是將 Helm 與 Helm values 轉換為 YAML 檔案然後送到 Kubernetes 中。
這種作法跟第一種最大的差異就是，所有的安裝與管理中間都多了一層 Rancher Catalog 的管理。

CI/CD 流程要存取時就不是針對 Kubernetes 叢集去使用，也不需要取得 KUBECONFIG。
相反的需要取得 Rancher API Token，讓你 CI/CD 內的腳本有能力去呼叫 Rancher，要求 Rancher 去幫忙創建，管理，刪除不同的 Catalog。

這種方式只限定於 Rancher 管理的叢集，所以如果團隊中不是每個叢集都用 Rancher 管理，那這種方式就不推薦使用，否則只會讓系統混亂。

# Rancher Fleet
Rancher Fleet 是 Rancher v2.5 正式推出的功能，其替代了過往的 Rancher pipeline(前述文章沒有探討，因為基本上要被淘汰了)的部署方式。

Fleet 是一個基於 GitOps 策略的大規模 Kubernetes 應用部署解決方案，基於 Rancher 的架構使得 Fleet 可以很輕鬆的存取所有 Rancher 控管的 Kubernetes 叢集，同時 GitOps 的方式讓開發者可以簡單的一口氣將應用程式更新到多個 Kubernetes 叢集。

接下來的文章就會從 Rancher Catalog 出發，接者探討 GitOps 與 Rancher Fleet 的使用方式。
