Day 12 - Rancher 專案管理指南 - Project 概念介紹
============================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言
前幾篇文章探討了如何透過 Rancher 操作與管理 Kubernetes 叢集，不論是直接抓取 Kubeconfig 或是使用網頁上的 web terminal 來操作，此外也探討了 Rancher 整合的應用程式，特別是最重要的 Monitoring 該如何使用。

有了上述的概念後，使用者已經可以順利的操作 Kubernetes 來部署各種服務。
不過 Rancher 想做的事情可沒有這麼簡單， Rancher 希望能夠強化 Kubernetes 讓其更佳適合給多位使用者共同使用了。
對於這種多租戶的概念， Kubernetes 提供了 namespace 的機制來達到資源隔離，不過 namespace 普遍上被認為是個輕量級的隔離技術，畢竟 namespace 主要是邏輯層面的隔離，底層的運算與網路資源基本上還是共用的。

就算是 RKE 也沒有辦法完全顛覆 namespace 讓其變成真正的隔離技術，畢竟 CPU/Memory/Network 等相關資源因為 Container 的關係本來就很難切割，要達到如 VM 般真正隔離還不是這麼容易。
不過 Rancher 還是有別的方向可以去發展與強化，就是如何讓 Kubernetes 變得更適合一個團隊使用，如果該團隊內有數個不同的專案，這些專案要如何共同的使用一套 Kubernetes 叢集同時又可以有一個清楚且清晰的管理方式。

# Project
Rancher 提出了一個名為 project 的概念，Project 是基於 Kubernetes Namespace 的實作的抽象管理概念，每個 Project 可以包含多個 namespace，同時 project 也會與 Rancher 內部的使用者權限機制整合。

從架構層面來看
1. Rancher 管理了多套 Kubernetes 叢集
2. Kubernetes 叢集管理多個 Project
3. Project 擁有多個 namespace.

如同前面探討的, Kubernetes 原生提供的 namespace 機制是個輕量級虛擬化概念，所有 kubernetes 內的機制也都是以 namespace 為基礎去設計的，這意味者如果你今天要透過 RBAC 設定權限等操作你都需要針對 namespace 去仔細設計。但是 Rancher 認為一個產品專案可能不會只使用一個 namespace，而是會使用多個 namespace 來區隔不同的應用程式。
這種情況下你就必須要要針對每個 namespace 一個一個的去重複設定，從結果來說一樣可以達到效果，但是操作起來就是不停重複相同的動作。

透過 Rancher Project 的整合，叢集管理者可以達到
1. 整合使用者群組權限，一口氣讓特定群組/使用者的人針對多個 namespace 去設定 RBAC
2. 針對 Project 為單位去進行資源控管，一口氣設定多個 namespace 內 CPU/Memory 的使用量
3. 套用 Pod Security Policy 到多個 namespace 中

因此實際上管理 Kubernetes 叢集就變成有兩種方式
1. 完全忽略 Rancher 提供的 Project 功能，直接就如同其他 Kubernetes 版本一樣去操作
2. 使用 Rancher 所設計的 Project 來管理

Rancher 會開發 Project 勢必有其好處，但是要不要使用就是另外一回事情，因為這個技術與概念是只有 Rancher 才有的，如果今天團隊同時擁有多套不同的 Kubernetes 叢集，有些用 Rancher 管理，有些沒有。
這種情況下也許不要使用 Rancher 工具而是採用盡可能原生統一的工具來管理會更好，因為可以避免團隊中使用的工具有太多的客製化行為，造成開發與維護都不容易。相反的使用所有 Kubernetes 發行版本都有的工具與管理方式反而有機會降低工具的複雜性。
所以到底要不要使用這類型的工具反而是見仁見智，請依據每個團隊需求去思考。

接下來就來看一下到底如何使用 Rancher Project 概念。

# 操作
Project 因為是用來簡化同時操作多個 namespace 的一種概念，因此管理上會跟 namespace 放在一起。
Rancher 畫面上方的 Projects/Namespaces 就是用來管理這類型概念的，點選進去會看到類似下圖的版面。

![](https://i.imgur.com/UICDWE8.png)

因為 Project 包含多個 namespace，所以版面中都是以 Project 為主，列出該 Project 底下有哪些 namespace，
Rancher 內的任何 Kubernetes 叢集預設都會有兩個 Projects，System 與 Default
System 內會放置任何跟 Rancher 以及 Kubernetes 有關的 namespace，譬如 cattle-system, fleet-system, kube-system, kube-public 等

Default 是預設的 Project，預設對應到 default 這個 namespace。
任何不是透過 Rancher 創立的 namespace 都不會加入到任何已知的 project 底下，因此圖片中最上方可以看到一堆 namespace，而這些 namespace 都不屬於任何一個 project。

因此要使用 project 的話就需要把這些 namespace 給搬移到對應的 project 底下。
圖中右上方有一個按鈕可以創立新的 Project，點下去可以看到如下畫面

![](https://i.imgur.com/ydCM1So.png)

創立一個 Project 有四個資訊需要輸入，分別是
1. 使用者權限
2. Project 資源控管
3. Container 資源控管
4. Labels/Annotation.

使用者權限可以控制屬於什麼樣的使用者/群組可以對這個 Project 有什麼樣的操作。
Project 與 Container 的資源控管之後會有一篇來介紹
創立完 Project 之後就可以回到最外層的介面，將已經存在的 namespace 給掛到 project 底下

![](https://i.imgur.com/Yz8IOeR.png)

譬如上述範例就將 cis-operator-system, longhorn-system 這兩個 namespace 給分配到剛剛創立的 project 底下。

![](https://i.imgur.com/XZdJPCI.png)

之後重新進入到該 Project 去編輯，嘗試將 QA 使用群組加入到該 Project 底下，讓其變成 Project Owner，代表擁有完整權限。

![](https://i.imgur.com/7k81z5q.png)

創造完畢後，就可以透過 UI 切換到不同的 project，如上圖所示，可以看到 ithome-dev 叢集底下有三個 Project，其中有兩個是預設的，一個是剛剛前述創立的。

![](https://i.imgur.com/3nrmPQM.png)

切換到該 Project 之後，觀察當前的 URL 可以觀察到兩個有趣的ID，c-xxxx/p-xxxxx 會分別對應到 clusterID 以及 project ID，因此之後只要看到任何 ID 是 c-xxx 開頭的，基本上都是 Rancher 所創立的，跟 Cluster 有關，而 p-xxxx 開頭的則是跟 Project 有關，每個 Project 都勢必屬於某個 Cluster。

有了 ProjectID 之後，仿造之前透過 kubectl 去觀察使用者權限的方式，這次繼續觀察前述加入的 QA 群組會有什麼變化。

![](https://i.imgur.com/SrZBa1F.png)

從上述指令中可以看到 QA 群組對應到一個新的 ClusterRole，叫做 p-p6xrd-namespaces-edit，其中 p-p6xrd 就是對應到前述創立的 project，而 edit 代表則是擁有 owner 般的權限，能夠去編輯任何資源。

接者更詳細的去看一下該 ClusterRole 的內容

![](https://i.imgur.com/PDuNUwr.png)

可以看到該 ClusterRole 針對設定的兩個 namespace 都給予了 "*" 的動詞權限，基本上就是讓該使用者能夠如管理者般去使用這兩個 namespace。


除了上述的權限外，當切換到 Project 的頁面時，就可以看到從 Rancher 中去看到該 Project 底下 namespaces 內的相關 Kubernetes 物件資源，譬如下圖

![](https://i.imgur.com/b406bS0.png)

Workloads 就是最基本的運算單元，譬如 Pod, Deployment, Job, DaemonSet..等
而 Config(ConfigMap), Secrets 可以看到整個叢集內的相關資源，此外 secret 透過網頁的可以直接看到透過 base64 解密後的結果。

註: Pipelines 請忽略他， v2.5 之後 Rancher 會主推使用 GitOps 的方式來部署，因此過往 pipeline 的方式這邊就不介紹了。

以 workloads 為範例，點進去後可以更詳細的去看當前系統中有哪些 workloads。

![](https://i.imgur.com/g5QcsvM.png)

每個 workloads 旁邊都有一個選項可以打開，打開後會看到如上的選擇，這邊就有很多功能可以使用，譬如
1. Add a Sidecar，可以幫忙加入一個 sidecar contaienr 進去
2. Rollback 到之前版本
3. Redeploy 重新部署
4. 取得該 Pod 的 shell (如果該 workloads 底下有多種 pod，則不建議這邊使用這個功能)

基本上這些功能都可以透過 kubectl 來達到，網頁只是把 kubectl 要用的指令給簡化，讓他更輕鬆操作。
上述的範例 test 是使用 deployment 去部署的，點進去該 deployment 可以看到更詳細 pods 的資訊，如下

![](https://i.imgur.com/b0BWhyM.png)

該畫面中就可以看到每個 Pod 的資訊，包含 Pod 的名稱，部署到哪個節點，同時也可以透過 UI 去執行該 Pod 的 shell 或是觀看相關 log。

以上就介紹了關於 Project 的基本概念。 Project 是 Rancher 內的最基本單位，因此要透過 Rancher 的 UI 去管理叢集內的各種部署資源則必須要先準備好相關的 Project，並且設定好每個 Project 對應的 namespace 以及使用者權限。

當然 Rancher Project 不是一個一定要使用的功能，因為也是有團隊單純只是依賴 Rancher 去部署 Kubernetes 叢集，而繼續使用本來的方式來管理與部署 Kubernetes 叢集，畢竟現在有很多種不同的專案可以提供 Kubernetes 內的資源狀況。一切都還是以團隊需求為主。
