[Day27] Operator Pattern
========================

> 本文同步刊登於 [hwchiu.com - Operator Pattern](https://www.hwchiu.com/k8s-operator-pattern.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- Device Plugin


有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

探討完 **Device Plugin** 後，我們算是討論了四個 **Kubernetes** 用來銜接第三方解決方案
的方法，其中三個標準與一個專屬於 **kubernetes** 的介面，接下來的文章會探討一些比較小但是也算是擴充 **kubernetes** 功能方法的一些概念。

本文要介紹的則是 **Operator Pattern** ，我個人是覺得從 2018 開始， **operator** 這個詞開始各種被討論，然後愈來愈多的軟體開始支援所謂的 **operator** 形式的安裝方式，不久之後又開始出現了 **operator framework**。所以本文就要來好好的討論一下到底什麼是 **Operator**

# 介紹

對我來說，我認為 **Operator** 就只是一個 **Pattern**，一個有著類似概念的應用程式設計方式。
這點我跟 [Operator pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) 官方文件的想法是一致的，我完全不覺得 **Operator** 有什麼特別之處，早在這個詞廣為流傳之前，會透過 **kubernetes client library** 撰寫相關應用程式直接溝通處理的人，大致上做的事情跟後來的 **operator** 幾乎一樣。

我們來看看官方怎麼說
> Operators are software extensions to Kubernetes that make use of custom resources to manage applications and their components. Operators follow Kubernetes principles, notably the control loop.

這邊的說明講到了兩個概念，分別是 **custom resources** 以及 **control loop**，對於採用這兩個概念完成的解決方案，就可以稱為 **Operator Pattern**。

等等會再仔細介紹這兩個概念分別是什麼，以及怎麼組合一起運作。

## 動機

**Operator** 的名稱的由來，根據官網的[動機介紹](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)，我的解讀是希望能夠模擬系統管理員，或是所謂的操作員在管理大量服務時的各種操作，特別是這些操作本身會有特定的邏輯牽扯，同時這些操作本身也有依賴性。
根據上述的說法，有時候就會有一些腳本或是相關的工具來幫忙自動化的完成這些工作，但是這些腳本或是工具都是基於外部對 **kubernetes** 的操作來處理。

今天 **Operator** 希望達到的方式是可以透過內部直接於 **kuberentes** 來溝通
，並且透過程式化的方式將這些相關邏輯用程式撰寫來完成。

## 組成

接下來就來探討所謂的 **custom resources** 以及 **control loop** 這兩個概念。

### CRD
**custom resourecs** 顧名思義就是客製化資源，目前於 **kubernetes** 中已經定義了大量的內建資源，譬如 **Deployment**, **Pod**, **NetworkPolicy**, **StorageClass** 這些都是內建的資源。
而 **Custom Resources** 則是所謂的 **Custom Resources Definition(CRD)** 框架下的產物，任何使用者都可以透過 **CRD** 的格式向 **kubernetes** 動態的創造一個全新資源，甚至可以使用 **kubectl get** 的方式來取得這些資源的資訊。

[官方文件 - Extend the Kubernetes API with CustomResourceDefinitions](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/#create-a-customresourcedefinition) 介紹了一個範例

```yaml=
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  # name must match the spec fields below, and be in the form: <plural>.<group>
  name: crontabs.stable.example.com
spec:
  # group name to use for REST API: /apis/<group>/<version>
  group: stable.example.com
  # list of versions supported by this CustomResourceDefinition
  versions:
    - name: v1
      # Each version can be enabled/disabled by Served flag.
      served: true
      # One and only one version must be marked as the storage version.
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                cronSpec:
                  type: string
                image:
                  type: string
                replicas:
                  type: integer
  # either Namespaced or Cluster
  scope: Namespaced
  names:
    # plural name to be used in the URL: /apis/<group>/<version>/<plural>
    plural: crontabs
    # singular name to be used as an alias on the CLI and for display
    singular: crontab
    # kind is normally the CamelCased singular type. Your resource manifests use this.
    kind: CronTab
    # shortNames allow shorter string to match your resource on the CLI
    shortNames:
    - ct  
```
一旦將上述的檔案加入到 **kubernetes** 中，接下來就可以使用裡面描述的 **names** 底下的各種名稱來取得。
譬如
```bash
$ kubectl get ct
$ kubectl get crontab
```
同時也可以直接創造一個對應的資源
```
apiVersion: "stable.example.com/v1"
kind: CronTab
metadata:
  name: my-new-cron-object
spec:
  cronSpec: "* * * * */5"
  image: my-awesome-cron-image
```

透過 **CRD** 的方式，我們可以對我們的應用程式，服務跟需求創建一個符合的資源，並且搭配需要的設定檔。

### Control Loop
這個概念其實源自於 [Kubernetes Control Plane](https://kubernetes.io/docs/concepts/#kubernetes-control-plane)，
對於 **kubernetes** 來說，**master** 以及各節點的 **kubelet**都扮演者 **control plane** 的角色，幫忙維護各式各樣的資源需求，其中的運作邏輯則是會運行一個無窮的迴圈，不停地監控所有叢集上的資源變化，譬如 **Pod** 的 Create,Delete,Terminated，接者根據使用者的需求來決定下一個步驟該怎麼做。

而這些運作過程中，都可以直接去監聽各種 kubernetes 資源的變化，除了這些內建的資源之外，連我們透過 **CRD** 動態創立的資源也可以使用一樣的方式



有了上述兩個概念之後，我們可以簡單歸納一下 **Operator Pattern** 通常會做的事情。
1. 根據需求創建需要的 **CRD**，可以更加方便的去管理目標應用的設定
2. 撰寫一個應用程式，該應用程式會不停地去聽取 **Kubernetes** 相關資源的變化，譬如上述 **CRD** 被創建後，就會根據該資源再去創造所有需要的資源，譬如 **Pod**, **Service**，將所有之前需要人為涉入的邏輯都用程式化的方式來重複執行。


## Build Operator
接下來可以來看一下，如果想要撰寫一個 **operator**，可以怎麼完成
畢竟上述提到的都只是相關的該念，實際上要撰寫的話可以怎麼完成

根據[官方文件](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)的推薦，目前有四種以上的方法可以完成

1. using KUDO (Kubernetes Universal Declarative Operator)
2. using kubebuilder
3. using Metacontroller along with WebHooks that you implement yourself
4. using the Operator Framework

就我自己的經驗來說，最基本的方式就是直接使用 [client-go](https://github.com/kubernetes/client-go) 這個官方的 **golang library** 直接撰寫一個可以跟 **kubernetes** 溝通的應用程式，並且自己滿足相關的資源監聽，相關的 Control Loop。

而上述提到的四個方式就是將這個步驟再次包裝，期望提供更簡單的方式讓使用者可以開發出一個基於 **Operator Pattern** 的應用程式。
但是事情沒有絕對完美，框架的問題就在於是否夠靈活彈性與客製化，是否能夠符合所有的應用情境，不能的話是不是還是要退回到最原始自己與 **kubernete** 溝通?

所以我認為挑選 **Operator Framework** 前要先釐清自己的使用情境跟需求，接下來去挑選各個工具的時候才能夠判斷是否該工具適合自己的情境。


# Summary

最後用一張架構圖來解釋 **Operator Pattern** 的運作概念
![](https://i.imgur.com/yMiauuR.png)
該圖節錄自[Comparing Kubernetes Operator Pattern with alternatives](https://medium.com/@cloudark/why-to-write-kubernetes-operators-9b1e32a24814)

該圖片分成左右兩部分，其功能是等價值的。
左邊部分則是最原始的操作過程，右邊則是採用 **Operator Pattern** 後的過程。
先來看看左邊的架構流程，其將部署分成兩個部分
1. 準備好所有相關的檔案與設定，接者使用 Helm 或是任何工具安裝相關的資源，譬如 Deployment, StatefulSet 等
2. 接下來安裝完畢後，就要進入到後續的維護操作，這時候可能會有額外的自動化程式來處理 Deployment/SttatefulSet 相關的變化，並且根據這些變化進行不同的設定

而右邊的部分非常簡單，就是先行安裝該應用程式相關的 **Controller**，如果這時候沒有額外的特別設定，則上述安裝的 **Controller** 本身會開始跟 **kubernetes** 溝通並且開始創造如 Deployment, StatefulSet 相關的資源，並且自行監控所有的變化來處理。

等於說將所有之前人為觀察操作的步驟都程式化於該 **Controller** 之中。帶來的好處不言而喻，但是其實我認為也帶了不少壞處
1. 除錯困難，一旦所有的運作邏輯都被綁到程式內，對於叢集的管理人員來說更像是一個神秘的黑盒子，遇到問題其實幾乎不能處理，也不能客製化。一但有任何更動就是需要重新建置編譯並且產生 **Image** 最後部署。 這一連串的流程導致除錯麻煩以及變得非常依賴該專案上游的維護以及專案本身的穩定性


# 參考
- https://kubernetes.io/docs/concepts/extend-kubernetes/operator/
- https://coreos.com/blog/introducing-operators.html
- https://cloud.google.com/blog/products/containers-kubernetes/best-practices-for-building-kubernetes-operators-and-stateful-apps
