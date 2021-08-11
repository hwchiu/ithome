Day 8 - Rancher 叢集管理指南 - 架設 K8s(上)
========================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言

前述文章探討的都是基於一個系統管理員的角度下，可以如何使用 Rancher 這個管理平台來符合整個團隊的需求，譬如 RKE Template 以及最重要的使用者登入與權限控管。
當 Rancher 系統有了妥善的規劃與設定後，下一步就是踏入到 Rancher 最重要的功能，也就是 Kubernetes 管理。

前篇文章探討 RKE Template 的時候有介紹過 Rancher 有四種新增 Kubernetes 叢集的方式，第一種是將已經存在的 EKS/GKE 等叢集直接匯入到 Rancher 中，而剩下三種是根據不同架構來產生一個全新的 RKE 叢集並且匯入到 Rancher 中。

這三種架構以目前的環境架構如下圖所示

![](https://i.imgur.com/HRqIhff.png)

Rancher 有三種方式可以架設 RKE，從右到左分別是
1. 透過 API 請求 Azure 幫忙創建 AKS，並且把 Rancher 相關的 agent 安裝到該 AKS 中
2. 透過 API 請求 Azure 創造 VM 叢集，接者於這些 VM 上安裝 RKE 叢集
3. 直接於已經存在的節點上搭建一套 RKE 叢集

接下來就示範這三種用法有何不同，以及當 RKE 叢集創建出來後該如何使用

# 環境實驗
三種環境中，我認為相對複雜的是第二種，如何請求 Azure 創建 VM 並且安裝 RKE 叢集。
所以先從這個較為複雜的情況開始探討，掌握這個概念後後續兩個(1)(3)都較為簡單，使用上也就不會有太多問題。

第二種的安裝模式將其仔細攤開來看，其實有幾個重點需要完成
1. 選擇一個想要使用的 Service Provider
2. 準備好該 Service Provider 溝通用的設定，譬如帳號密碼, Token 等
3. 規劃需要準備多少台 VM，每個 VM 要用何種規模(CPU/Memory)，該機器要扮演 Kubernetes 什麼角色
4. 規劃 RKE 的設定

# Service Provider

第一點是選擇一個想要使用的 Service Provider，由於之前的環境都是基於 Azure 去使用，因此我接下來的範例都會基於 Azure 去架設。

下圖是一個 Rancher 預設支援的 Service Provider，包含了 AWS, Azure, DigitalOcean, Linode 以及 vSphere.

![](https://i.imgur.com/Bs8tJhg.png)

實際上 Rancher 內部有一個名為 Node Driver 的資源專門用來管理目前支援哪些 Service Provider，該資源是屬於系統層級，也就是整個 Rancher 環境共享的。

Driver (Tools->Driver) 頁面中顯示了兩種不同的 Driver，分別是 Cluster Driver 以及 Node Drivers.

預設的 Node Driver 狀態如下，可以看到 Driver 分成兩種狀態，分別是 Active 以及 Inactive，而上圖中顯示的 AWS/Azure/Digital/Linode/vSphere 都屬於 Active。

![](https://i.imgur.com/5J8Aesy.png)

嘗試將上述所有 Inactive 的 Drive 都 active 後，這時候重新回去 Cluster 創建頁面看，就可以發現目前支援的 Service Provider 變得超級多。

![](https://i.imgur.com/fdMnD1W.png)

所以如果團隊使用的 Service Provider 沒有被 Rancher 預設支援的話，別忘記到 Driver 處去看看有沒有，也許只是屬於 Inactive 的狀態而已。

# Access Credentials

選擇 Service Provider(Azure) 後的下一個步驟就是要想辦法讓 Rancher 跟 Azure 有辦法溝通，基本上 Service Provider 都會提供相關的資訊供使用者使用。

這邊試想一下，這種帳號密碼資訊的東西如果每次創建時都要一直重複輸入其實也是相對煩人的，所以如果有一個類似 RKE Template 概念的物件，就能夠讓使用者更為方便的去使用。
譬如使用者只需要事先設定一次，接下來每次要使用到的時候都去參考事先設定好的帳號密碼資訊即可。

Rancher 實際上也有提供這類型的機制，稱為 Cloud Credentials，其設定頁面位於個人使用者底下，

![](https://i.imgur.com/PBYjoBy.png)

接者點選創建一個 Cloud Credential 並且將 Cloud Credential Type 設定為 Azure 後就會出現 Azure 應該要輸入的相關資訊，對於熟悉 Azure 的讀者來說這三個設定應該不會太陌生，基本上 Rancher 官方都有針對這些類別提供簡單的教學文件。

![](https://i.imgur.com/rbvPr5w.png)

一切準備就緒後就可以創建一個基於 Azure 的 Cloud Credential 了。未來其他操作如果需要 Azure 相關的帳號密碼時，就不需要一直重複輸入，而是可以直接使用這組事先創建好的連接資訊。

# VMs

當 Rancher 準備好如何跟 Service Provider(Azure) 溝通後，下一個要做的就是使用者要去思考，希望這個創建的 RKE 叢集有多少個節點以及相關設定。這些節點都會是由 Rancher 要求 Azure 動態創立的，每個節點都需要下列資訊


1. 節點的 VM 規模，多少 CPU，多少 Memory
2. 該 VM 要用什麼樣的 Image，什麼樣的版本，登入角色要用什麼名稱，有沒有 Cloud-Init 要運行
3. 每個 Service Provider 專屬設定
4. 該節點於 Kubernetes 內扮演的角色，角色又可以分成三種
    a. etcd: 扮演 etcd 的角色，要注意的是 etcd 的數量必須是奇數
    b. control plane: Kubernetes Control Plane 相關的元件，包含 API Server, Controller, Scheduler 等
    c. worker: 單純的角色，可以接受 Control Plane 的命令將 Pod 部署到該節點上。

從上述的資訊可以觀察到，要創建一個 RKE 資訊光節點這邊要輸入的資訊就不少，所以如果每次創建 RKE 叢集都要一直重複輸入上列這些資訊，其實帶來的麻煩不下 Credential 與 K8s 本身。

這個問題 Rancher 也有想到，其提供了一個名為 Node Template 的物件讓使用者可以去設定 VM 的資訊，同時為了讓整個操作更加彈性與靈活，上述四個步驟其實分成兩大類
1. VM 本身的設定 (1~3)
2. 該 VM 怎麼被 RKE 使用 (4)

Node Template 要解決的是第一大類的問題，讓 VM 本身的設定可以重複利用，不需要每次輸入。
使用者要創立ㄧ個新的 RKE 叢集時，可以直接使用創造好的 NodeTemplate 設定 VM 資訊，接者根據當前需求決定該節點應該要以何種身份於 RKE 叢集中使用。

Node Template 與 Cloud Credential 一樣，都可以於使用者底下的頁面去設定。
進入到頁面後可以看到目前支援的 Service Provider，因為先前有將所有 Node Driver 都打開，所以這邊的選擇就非常的多。

![](https://i.imgur.com/baj9z62.png)

當選擇為 Azure 後，底下的 Account Access 就會出現之前創立的 Cloud Credential。
如果想要創建新的也可以於這個頁面直接創立該 Cloud Credential。

![](https://i.imgur.com/5ZwJ8AO.png)
![](https://i.imgur.com/bCcUP3o.png)

接者下列就是滿滿的 VM 設定，這邊的設定內容都跟該 Service Provider 有關 可以看到
1. image 預設是 canonical:UbuntuServer:18.04-LTS:latest，
2. Size 是 Standard_D2_v2
3. SSH 的使用者名稱是誰
4. 硬碟空間預設是 30GB

上述還有非常多的設定，除非對這些選項都非常熟悉，不然大部分情況下都可以採取預設選項
一切就緒後給予該 Node Template 一個名稱並且儲存。

實務上通常會針對不同大小的機器創建不同的 Node Template 並且給予名稱時有一個區別，這樣之後使用者要使用時就會比較清楚當前的 Node Template 會創造出什麼樣的機器。

這邊示範一下創建兩個 Node Template 並且給予不同的名稱
![](https://i.imgur.com/0501cug.png)

# RKE
一切資訊都準備完畢後，接者就可以回到 Cluster 的頁面去創造一個基於 Azure 的 RKE 叢集。

![](https://i.imgur.com/fmIomDV.png)
上圖紅匡處則是本文章重點處理的部分，也就是所謂的 Node Template。
對於 RKE 叢集來說，會先透過 Node Template 來定義一個 Node Pool，每個 Node Pool 需要定義下列資訊
1. 該 Node Pool 名稱
2. Pool 內有多少節點
3. 該 Node Pool 要基於哪個 Node Template 來創造
4. 本身要扮演什麼身份

同時 UI 也會提醒你每個身份應該要有多少個節點，譬如 etcd 要維持奇數， Control Plane/Worker 至少都要有一個節點。

決定好叢集身份後，下一件事情就是權限，到底誰有權限去使用這個 RKE 叢集，預設情況下有兩種身份，分別是
1. Cluster Owner: 該使用者擁有對該叢集的所有操控權，包含裡面的各種資源
2. Cluster Member: 可以讀取觀看各種相關資源，寫的部分是針對底下的專案去操作，沒有辦法對 Cluster 本身進行太多操作，這部分之後會探討叢集內的專案概念時會更加理解。

一切準備就緒就給他點選創立，接者就是慢慢等他處理，整個過程會相對漫長，因為需要從 VM 開始創立，接者才去創建 RKE 叢集。
當畫面顯示如下時，就代表者相關叢集已經創建完畢了。

![](https://i.imgur.com/BMGNDuU.png)

這邊可以看到，跟之前用來存放 Rancher 的 RKE 不同，這個新創的 RKE 叢集其 Provider 標示為 Azure。

同時我的 Azure VM 中也真的產生出三個新的VM，這些 VM 的名稱與規格都與之前設定的完全一樣。

![](https://i.imgur.com/uQhTgbs.png)

下一章節會繼續介紹另外兩種不同的安裝方式，並且會基於這三種不同方式安裝三個不同類型的叢集，之後探討到 Rancher Fleet 這個 GitOps 的概念時，就會使用 GitOps 來部署應用程式到這三個不同的叢集。
