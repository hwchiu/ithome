Day 10 - Rancher 叢集管理指南 - RKE 管理與操作
==========================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)


# 前言

前述文章透過不同的安裝方式讓 Rancher 管理三套不同的 Kubernetes 叢集，其中有兩套叢集是基於 RKE 的版本，而另外一個則是 Azure AKS。

這三個叢集除了安裝的方式不同外，實際上因為底層的限制與安裝方式的不同，網頁操作上會有一些功能有些許不同，而本章節就會開始來探討要如何使用 Rancher 的介面來管理這些 Kubernetes 叢集。


# 叢集存取
對於大部分的 Kubernetes 工程師來說， kubectl 是個必須要會的使用工具，而 dashboard 更多時候是作為一個輔助的工具，提供更友善的視覺化方式來有效的提供資訊。
Rancher 本身提供非常友善的 Dashboard，可以讓非工程人員也可以快速地瀏覽與理解當前 Kubernetes 叢集的狀態，舉例來說隨便點進一個之前創立的 Kubernetes 叢集，會看到如下的畫面。

![](https://i.imgur.com/x7HLRik.png)

畫面中有幾個點可以注意
1. Rancher 內部有兩種瀏覽介面，分別是 Cluster Manager 以及 Cluster Explorer，預設情況下都是使用 Cluster Manager 來瀏覽
2. Rancher v2.5 之後將慢慢的轉往 Cluster Explorer 去使用，所以可以觀察到畫面上都有提示，告知使用者可以嘗試使用看看 Cluster Explorer 來管理與瀏覽 Kubernetes 叢集
3. 畫面中間大大的顯示了三個關於 Kubernetes 資源的資訊，CPU, Memory 以及 Pod 的數量。Kubernetes 預設情況下每個節點最多只能部署110個 Pod，所以畫面中顯示的是 18/330，代表說目前已經有 18 個Pod 部署了。而 CPU/Memory 代表的則是有多少系統資源已經被預先保留，這部分是透過 Pod 裏面的 Resource.Request 來處理的
4. 最下面還有四個健康狀態，代表整個叢集中的 Etcd, Control Plane(Controller,Scheduler) 以及節點之間的健康狀態
5. 最下面 Events 展開則是可以看到 Kubernetes 內的相關 Event

上述的 Portal 簡單地呈現了當前 Kubernetes 叢集是否健康，特別是當叢集有任何問題時，下方的四個狀態都會變成紅色醒目的提醒使用者叢集有問題。

有了基本介面後，接下來把注意力移動到右上方兩個選項，分別是 Launch kubectl 以及 Kubeconfig File。
點選 Kubeconfig File，則會看到類似下列的畫面，該畫面中呈現的就是完整的 Kubeconfig file 內容。

![](https://i.imgur.com/roI1gNn.png)

這意味你可以把該檔案抓到你的電腦，直接於本地端使用 Kubectl 指令去存取目標叢集，示範中使用的是給 DEV 人員操作的叢集，所以該 Kubectl 本身對應的使用者其實也就是我當前用來登入 Rancher 系統的使用者。
如果熟悉 Kubeconfig 格式的讀者會觀察到, Rancher 本身會針對 Clusters 這個欄位填入多個組合，這些組合分兩大類，分別是
1. 叢集中的 API Server 位置
2. Rancher Server 本身

假如今天你有辦法直接存取到目標節點，譬如節點本身有 Public IP 且也有開啟 6443 Port，那就可以使用這個方式直接存取該 Kubernetes 叢集。
但是如果該節點今天是一個封閉的環境，沒有任何 Public IP 可以直接存取，那可以採取第二種方式，把任何 API 請求都打向 Rancher 服務，如圖中的 "https://rancher.hwchiu.com/k8s/clusters/c-z8j6q" 這個位置，然後 Rancher 就會幫忙把請求給轉發到目標叢集內，可以想像成是一個 Proxy By Pass 的概念。

補充一下: 因為目標 Kubernetes 叢集內都會安裝 Rancher 相關的服務，這些服務都會主動的跟 Rancher 進行連線，所以 Rancher 才有辦法把這些 API 請求給轉發到這些不能被外界主動存取的 Kubernetes 叢集。

以下是個範例，將上述檔案存成一個名為 ithome 的檔案，接者執行 kubectl 的時候可以透過 --kubeconfig 的參數來指定當前 kubectl 要使用哪個檔案

![](https://i.imgur.com/3uVsCev.png)

上述指令就呈現了當前 DEV 叢集中的相關 Pod 資訊，其中可以看到
1. Flannel CNI 符合之前 RKE Template 的選擇
2. RKE 叢集有滿多相關的服務
3. cattle-system 有所謂的 cattle-node-agent，這些角色就是會負責跟 Rancher 溝通。

基本上只有擁有了 KUBECONFIG 的檔案，管理者就有辦法透過 kubectl,helm 等指令直接管理該叢集。
如果系統上剛好沒有安裝這些指令，但是又想要使用 kubectl 來操作怎麼辦？
Rancher 也想到了這一塊，所以叢集畫面右上方的 Launch Kubectl 按鈕給他點下去，
該功能會開啟一個 web-based 的終端機，裡面提供了 kubectl 的指令，同時 kubeconfig 也都設定完畢了。
所以可以直接於該環境中使用 kubectl 去操作叢集，範例如下

![](https://i.imgur.com/3yBGeOb.png)

基本上掌握這兩個功能的用法，就等於掌握了直接操作當前 Kubernetes 叢集的能力，習慣使用 kubectl 的使用者也可以開始透過 kubectl 來管理與部署該 Rancher 上的各種應用，當然 Rancher 本身也有自己的架構能夠讓使用者去部署應用程式，好壞沒有絕對，都要進行評估與比較。

Kubectl 與 Kubecfongi File 旁邊有一個按鈕，該按鈕點下去後可以看到一些關於 Kubernetes 叢集的選項，而不同的搭建的叢集顯示的功能都不同，譬如

如果節點是透過 AKS 搭建的，可以看到選項非常少，只有編輯與刪除是常見會使用的功能，編輯頁面中可以針對叢集名稱，叢集的使用權限，甚至針對 K8S 叢集的選項進行調整。不過由於該叢集是由 AKS 維護的，所以修改的內容也都是跟 AKS 有關。

![](https://i.imgur.com/t6UkV0y.png)


第二個看到的是透過 Docker 指令於現存節點上安裝的 RKE 叢集，這種狀況下可以選擇的操作非常多，譬如
1. Rotate Certificates，該功能主要是針對 Kubernetes 內各元件溝通用的憑證，譬如 API Server, Controller..等
2. Snapshot 主要會針對 etcd 進行備份與還原，該備份並沒有辦法針對使用者部署的應用程式去處理備份跟還原，之後可以細談一下這塊
3. Registration Cmd，由於該叢集是透過讓節點運行 Docker 指令將其加入到 RKE 叢集中，因此如果今天有新的節點要使用時，就可以直接點選該指令取得相關的 docker 指令，介面中也可以重新選擇身份與相關的標籤/Taint等。
4. Run CIS Scan，這個功能會慢慢被淘汰，v2.5 後 Cluster Explorer 內關於 App 的管理方式有更好的處理方式，建議使用那邊的 CIS 處理。

![](https://i.imgur.com/je64hZY.png)


最後一個則是透過 API 請求 Azure 創造 VM 的 RKE 叢集，基本上差異就只是沒有 Docker 指令可以處理。

![](https://i.imgur.com/PTl5sZx.png)

從上述三個叢集的觀察到可以發現， Rancher 很多功能都跟 RKE 叢集有關，所以如果今天是讓 Rancher 管理並非是由 Rancher 創造的叢集，功能上都會有所限制，並不能完全發揮 Rancher 的功能。

看完叢集相關的狀態後，切換到節點頁面，節點頁面也會因為不同安裝方式會有不同的呈現方式

下圖是基於 AKS 所創造的叢集，該叢集顯示了三個節點，這些節點因為 AKS 的關係被打上了非常多的標籤。

![](https://i.imgur.com/rDpyXCV.png)

如果該叢集是透過 API 要求 Azure 動態新增 VM 所創造的叢集，則該頁面是完全不同的類型

![](https://i.imgur.com/syJS7EQ.png)

上述畫面中有幾個點可以注意
1. 每個 Node Pool 都是獨立顯示，可以看到該 Node Pool 下目前有多少節點，每個節點的 IP 等資訊
2. 每個 Node Pool 右方都有 +- 兩個按鈕，可以讓你動態的調整節點數量
3. 由於這些節點都是動態創立的，因此如果今天有需求想要透過 SSH 去存取這些節點的話，實際上可以到每個節點旁邊的選項去下載該節點的 SSH Keys，這個功能是只有這種創造方式的叢集才擁有的。其他創造方式的叢集節點沒有辦法讓你下載相關的 SSH Key。

上述畫面除了 Cluster, Nodes 外還有其他選項，Member 頁面可以重新設定到底該叢集的擁有者與會員有誰，譬如最初 DEV 叢集只有 DEV 群組的使用者可以操作，目前嘗試將 QA 群組的使用者加入進去，並且設定權限為 Cluster Member，設定完後的畫面如下。

![](https://i.imgur.com/Avv0ZIy.png)

這種情況下，如果使用 QA 使用者登入，就可以看到這個 DEV 叢集，接者使用該 QA 使用者嘗試去存取該 DEV 叢集並且獲取該 Kubeconfig 就可以順利的使用了。

![](https://i.imgur.com/C4n3IuD.png)

如果熟悉 Kubernetes RBAC 的讀者，可以嘗試挖掘一下到底 Rancher 是如何把設定的這些權限給對應到 Kubernetes 內的權限。下圖是一個範例。

下圖是 QA 使用者存取 DEV 叢集用的 Kubeconfig，可以看到 User 部分使用的 Token 進行驗證，該 Token 中有一個資訊代表的是該 User 的 ID，u-dc5fezjbyi

![](https://i.imgur.com/cMNnaBS.png)

擁有該資訊後，可以到該 Kubernetes 叢集內去找尋 cattle-system 底下 ClusterUserAttribute 這個物件，看看是否有符合這個名稱的物件，找到後可以看到該物件描述了這使用者本身有一個 Group 的屬性。
該 Group 很明顯跟 Azure 有關，其值為 azuread_group://ec55ce9e-dbd4-427c-905c-d8063b19f150.
這個 Group 就會被用到 ClusterRoleBinding 中的 Subject

![](https://i.imgur.com/EewxM5S.png)

因此透過 kubectl 搭配 jq 的一些語法去找，看看有沒有哪些 ClusterRoleBinding 裏面是對應到這個 Group 群組，可以發現系統中有四個物件符合這個情況，而這四個物件對應到的 Role 分別是 read-only-promoted, cluster-member, p-****-namespaces-readonly，後面那個包含 "p-****" 字串的物件會跟之後探討的 Project 概念有關。

![](https://i.imgur.com/VxY0UQn.png)

接者有興趣的可以再繼續看這些不同的 Roles 實際上被賦予什麼樣的權限與操作。

除了 Member 可以操作外， Cluster 還有一個 Tools 的清單可以玩

![](https://i.imgur.com/IBFlyMV.png)

裡面有很多第三方整合工具可以安裝，但是如果是 v2.5 的使用者，非常建議直接忽略這個頁面，因為這邊都是舊版安裝與設
定行為，v2.5 後這些整合工具除了 Catalog 外基本上都已經搬移到 Cluster Explorer 頁面去安裝與操作。
因此接下來就嘗試進入到 Cluster Explorer 來看看這個 Rancher 想要推廣的新操作介面。

![](https://i.imgur.com/hod7WVe.png)

Cluster Explore 的介面跟 Cluster Manager 是截然不同的，這邊列出幾個重點
1. 右上方可以選擇當前是觀看哪個叢集，可以快速切換，同時提供一個按鈕返回 Cluster Manager.
2. 中間簡單呈現當前 Kubernetes 叢集的資訊，版本，提供者與節點資訊
3. 跟之前一樣呈現系統的資源使用量，不過 CPU/Memory 本身同時提供當前使用量已經當前被預約使用量，這兩個數字可以更好的去幫助管理員去設計當前相關資源的 request/limit 要多少
4. 左上方是重要的功能選單，不少功能都可以點選該處來處理
5. 左下方呈現 Kubernetes 中的各項資源，每個資源都可以點進去觀看，譬如 ClusterRoleBinding 就會更友善的呈現每個物件對應到的到底是 User ， Group 還是 Service Account。

點選左上方 Cluster Explorer 後切換到 Apps & Marketplace，可以看到類似下方的畫面

![](https://i.imgur.com/W3kP0HI.png)

該畫面中呈現了可以讓使用者輕鬆安裝的各類應用程式，這些應用程式分成兩大類，由 Rancher 自行維護整合的或是由合作夥伴提供的。
如果安裝的是由 Rancher 整合的 Application，那安裝完畢左上方都會出現一個針對該 App 專屬的介面，譬如我們可以嘗試安裝 CIS Benchmark。

![](https://i.imgur.com/JteqMZs.png)

安裝過程中，畫面下方會彈出一個類似終端機的視窗告知使用者安裝過程，待一切安裝完畢後可以透過畫面中間的 "X" 來關閉這個視窗。

![](https://i.imgur.com/GAUhv1v.png)

接者重新點選左上方的清單就會看到這時候有 CIS Benchmark 這個應用程式可以使用，該應用程式可以用來幫助管理去掃描 Kubernetes 叢集內是否有一些安全性的疑慮，該專案背後是依靠 kube-bench 來完成的，基本上 Rancher 有提供不同的 Profile 可以使用，所以對於安全性有需求的管理員可以安裝這個應用程式並且定期掃描。

![](https://i.imgur.com/rCnAAWt.png)

一個掃描的示範如上，該圖片中顯示了使用的是 rke-profile-permissions-1.6 這個 profile，然後跑出來的結果有 62 個通過， 24 個警告， 36 測試不需要跑。
如果拿 RKE 的 profile 去跑 AKS 的叢集就會得到失敗，因為 RKE 的 profile 是針對 RKE 的環境去設計的，因此可能會有一些功能跟 AKS 的設計不同，會失敗也是可以預料的。

Rancher 本身提供的 Application 非常多，下篇文章就來仔細看看其中最好用的 Monitoring 套件到底能夠提供什麼功能，使用者安裝可以如何使用這個套件來完成 Promethues + Grafana 的基本功能。
