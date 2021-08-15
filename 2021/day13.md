Day 13 - Rancher 專案管理指南 - 資源控管
====================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言

前篇文章探討為什麼需要 Project 這樣的概念，透過 Project 能夠帶來什麼樣的好處，然而前篇文章只有帶到簡單的操作以及如何使用透過 Rancher 的 UI 來檢視 Project 內的各種 Kubernetes 物件。

本篇文章將介紹我認為 Project 最好也最方便的功能， Resource Quotas 與 Container Default Resource Limit 到底是什麼以及如何使用。

# 資源控管介紹

熟悉 Kubernetes 的讀者應該都知道資源控管是一個非常困難的問題，其根本原因是 Container 本身的實作方式導致資源控管不太容器。
很多人使用資源控管最常遇到的問題有
1. 不知道該怎麼設定 Resources Limit， CPU/Memory 到底要用哪種? 三種內建的 QoS 型態有哪些? 有哪些影響?
2. 設定好了 Limit/Request 後結果運作不如預期，或是某些情況下應用程式效能大幅度降低等

第一點是最容易遇到的，畢竟要如何有效地去分配容器使用的 CPU/Memory 是個很困難的問題，特別是第一次踏入到容器化的團隊對於這個問題會有更大的疑惑，不確定該怎麼用。
第二個問題則是部分的 Linux Kernel 版本實作 Container 的資源控管與限制上會有一些 bug，可能會導致你的應用程式被不預期的 throttle，導致效能變得很低。

本篇文章不太探討這兩個問題，反而是探討最基本的概念，畢竟上述兩個概念跟 Rancher 沒太大關係，反而是比較進階使用與除錯的內容。

Kubernetes 中針對 CPU/Memory 等系統資源有兩種限制，稱為 Request 與 Limit。
Request 代表的是要求多少，而 Limit 代表的是最多可以使用多少。
這些資源是以 Container 為基本單位，而 Pod 本身是由多個 Container 組成的，所以 CPU/Memory 的計算上就相對繁瑣。

Kubernetes 本身有一個特別的物件稱為 ResourceQuota，透過該物件可以針對特定 namespace 去限定該 namespace 內所有 Container 的資源上限。譬如可以設定 default namespace 最多只能用 10顆 vCPU，超過的話就沒有辦法繼續部署。

Rancher 的 Project 本身就是一個管理多 namespace 的抽象概念，接下來看一下 Project 中有哪些關於 Resource 的管理。

# 操作
為了方便操作，先將 default namespace 給加入到之前創立的 Project 中，加進去後當前 project 中有三個 namespace，如下圖。

![](https://i.imgur.com/ZeRon6T.png)

接者編輯該 Project 去設定 Resource 相關的資訊，如下圖

![](https://i.imgur.com/dGxmeOh.png)

Project 中有兩種概念要設定，第一種是 Resource Quota，第二個是 Container Default Resource Limit.
Resource Quota 是更高階層的概念，是用來控管整個 Project 能夠使用的 CPU/Memory 用量。
由於 Project 是由多個 namespaces 所組成的，所以設定上還要去設定每個 namespace 的用量，如上述範例就是設定
整個 Project 可以使用 100個 vCPU，而每個 namespace 最多可以使用 10 vCPU。
但是因為 namespace 本身就是使用 kubernetes ResourceQuota 來實作，而這個功能本身會有一個限制就是。
一但該 namespace 本身設定了 ResourceQuota，則所有部署到該 namespace 的容器都必須要明確的寫出 CPU/Memory 用量。

這個概念也滿容易理解的，畢竟你要去計算 namespace 的使用上限，那 namespace 內的每個 container 都需要有 CPU/Memory 等相關設定，否則不能計算。
如果你的容器沒有去設定的話，你的服務會沒有辦法部署，會卡到 Scheduler 那個層級，連 Pending 都不會有。
但是如果要求每個容器部署的時候都要設定 CPU/Memory 其實會有點煩人，為了讓這個操作更簡單，Project 底下還有 Container Default Resource Limit 的設定。
該設定只要打開，所有部署到該 namespace 內的 Container 都會自動的補上這些設定。
如上圖的概念就是，每個 Container 部署時就會被補上 CPU(Request): 3顆, CPU(Limit): 6顆

這邊有一個東西要特別注意，Project 設定的 Container Default Resource Limit 本身有一個使用限制，如果 namespace 是再設定 Resource Quota 前就已經加入到 Project 的話，設定的數字並不會自動地套用到所有的 namespace 上。
反過來說，設定好這些資訊後，所有新創立的 namespace 都會自動沿用這些設定，但是設定前的 namespace 需要手動設定。

所以這時候必須要回到 namespace 上去重新設定，如下圖

![](https://i.imgur.com/UqlqrmS.png)

namespace 的編輯頁面就可以重新設定該 namespace 上的資訊，特別是 Container Default Resource Limit。
當這邊重新設定完畢後，就可以到系統中去看相關的物件

首先 Project 設定好 Resource Quota 後，Kubernetes 就會針對每個 namespace 都產生一個對應的 Quota 來設定，如下

![](https://i.imgur.com/SoOUiga.png)

因為設定每個 namespace 的 CPU 上限是 10顆，而該 project 總共有三個 namespace，所以系統中這三個 namespace 都產生了對應的 quota，而這些 quota 的設定都是 10顆 CPU。

其中 default namespace 的標示是 5025m/10 代表目前已經用了 5.025顆 CPU，而系統上限是 10顆。

![](https://i.imgur.com/nq6X7fH.png)

這時候將 default namespace 內的 pod 都清空，接者重新再看一次該 quota 物件就會發現 used 的數值從 5025m 到 0。

![](https://i.imgur.com/fiihnjl.png)

由於上述 default namespace 中設定 CPU 預設補上 0.1顆 CPU (Request/Limit)，所以 Kubernetes 會創造相關的物件 Limits

![](https://i.imgur.com/xUGhx8X.png)
![](https://i.imgur.com/Jg7JvKb.png)

從上述物件可以觀察到該 LimitRange 設定了 100m 的 CPU。

最後嘗試部署一個簡單的 deployment 來測試此功能看看，使用一個完全沒有標示任何 Resource 的 deployment，內容如下。

![](https://i.imgur.com/Ln1SnNw.png)
![](https://i.imgur.com/OOsDiOY.png)

該物件部署到叢集後，透過 kubectl describe 去查看一下這些 Pod 的狀態，可以看到其 Resource 被自動的補上 Limits/Requests: 100m。

![](https://i.imgur.com/5drPVJM.png)

Resource 的管理一直以來都不容易， Rancher 透過 Project 的管理方式讓團隊可以更容易的去管理多 namespace 之間的資源用量，同時也可以透過這個機制要求所有要部署的 container 都要去設定資源用量來確保不會有容器使用過多的資源。
