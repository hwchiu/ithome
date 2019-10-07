[Day29] Container Security
==========================

> 本文同步刊登於 [hwchiu.com - Security](https://www.hwchiu.com/k8s-security.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- Device Plugin


有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言
探討了各式各樣如何擴充 **kubernetes** 功能之後，接下來想來探討一下關於 Container 安全的部分，這個部分其實也牽扯到了 **Contaeinr** 是如何實作的。

而對於安全這個議題， **Kubernetes** 官網也提出了 **The 4C’s of Cloud Native Security**， 4C 的安全性問題，可參考下圖

![](https://i.imgur.com/5POoibQ.png)
上圖節錄自[Overview of Cloud Native Security](https://kubernetes.io/docs/concepts/security/overview/)

**4C** 分別代表
1. Code
2. Container
3. Cluster
4. Cloud/Co-located servers

這四個分別屬於不同的層級，且彼此一層包一層，對於**安全**的議題來說，這中間能夠涉入的點實在太多。
譬如是程式碼本身是否就有漏洞，本身不夠安全？ 

還是說是運行 Container 的方式或是設定不夠安全，譬如之前提過的 **RunC** 安全性漏洞。

往上到 Cluster 這層級，有沒有可能 cluster 本身有安全性漏洞可以讓被該 cluster 被任意操作？

最底下就是最直接架構的部分，不論是 Cloud Provider 的提供或是自行架設一群伺服器來提供底層服務，這些伺服器本身有沒有安全性的問題

每個部分都有自己的領域與專業去處理安全性的問題，但是這四個層級的應用我認為就如同鎖鏈一樣，很容易會因為最脆弱的部分而導致一起崩壞，只要有一個部分有安全性漏洞被攻擊，就不能保證沒有機會整個 4C 一起被影響被攻擊。

接下來會針對 **Container** 本身一些關於安全性以及權限相關的設定來探討與研究一下

## Container Security

排除特定基於虛擬機器的 **CRI** 解決方案的話，**Contaioner** 是 **kubernetes** 運作的最基本單元，**container** 本身的安全性牽扯範圍不少，譬如運行環境的權限設定，避免過度提權導致該 **container** 有過大的權力。或是 **container** 內部安裝的軟體是否本身就有安全性漏洞，而這些軟體是產生 **image** 本身的時候就已經安裝好還是運行後動態安裝的？ 
這意味者 **container image** 本身也是有相關的安全性問題需要檢查，譬如檢查整個系統內是否有任何軟體有安全性漏洞

基於上述 **container image** 產生的安全性隱憂，目前也有相關的專案再處理這一塊，譬如[CoreOS's Clair](https://github.com/coreos/clair/) 專案

> Clair is an open source project for the static analysis of vulnerabilities in application containers (currently including appc and docker).
> 

除了 **Image** 內軟體的安全性之外，**image** 本身的數位簽章也是一個需要考慮的部分
舉例來說，對於 **kubernetes** 這個 **container** 管理平台，是否針對任何 **Pod Yaml**內描述的 **Container** 都需要幫忙創建? 如果該 **Container** 可能本身是來路不明，無法保證其使用安全性，這種情況下是否可以拒絕創建

基於這個情況下我們可以採用簽名的方式來幫每個 **Container Image** 簽署名稱，同時讓 **kubernetes** 本身信任簽署的單位。 其概念有點類似 SSL 憑證及 CA 的運作。

以 **Docker** 為範例，其本身有個功能名為 [Docker Container Trust](https://docs.docker.com/engine/security/trust/content_trust/)，有興趣的可以自行研究。
如果是基於 **kubernetes** 使用情況的話，可以參考由 **IBM** 推出的專案[portieris](https://github.com/IBM/portieris)，

> Portieris is a Kubernetes admission controller for enforcing Content Trust. You can create image security policies for each Kubernetes namespace, or at the cluster level, and enforce different levels of trust for different images.


最後則是關於 **Contaienr** 本身的權限控管，不論是運行的使用者身份，群組，甚至是相關 **namespace** 的共用，或是基於 **systel call** 層級來限制的功能。
這部分我們來仔細探討

## Container Permission
這邊基於 **Kubernetes**內創建 **Container** 相關的參數來一一探討，這些參數每個的效用都有範圍，也許單獨只看一個會覺得影響不大，但是如果不同的權限功能互相疊加後，就可能產生一個極大權力的 **Container**，大到要整個破壞 **Kubernetes** 節點本身都不是問題。

接下來的討論是基於 [Pod Security Policy](https://kubernetes.io/docs/concepts/policy/pod-security-policy/) 的內容來討論

### Host namespaces
之前談過 **Linux** 的環境下是基於 **Linux Kernel Namesapce** 來創建一個與原生系統
隔離的虛擬化環境。

於 **CNI** 的章節中也有介紹過這些 **namespace** 本身除了可以創建新的來隔離之外，也可以與舊有的進行共用，譬如 **Infrastructure Pod(Pause)**。
目前 **kubernetes** 有開放下列幾種 **namespace** 來共用。

- HostPID
**Process ID** 與節點共用，這意味就可以於 **Contaienr** 內部直接觀看到節點上運行的所有 **Process**
- HostIPC
**Container** 與節點共用 **Inter-Process Communications Namespace**，如果對 **IPC** 概念有興趣的可以參考這篇 [Introduction to Linux namespaces - Part 2: IPC
](https://blog.yadutaf.fr/2013/12/28/introduction-to-linux-namespaces-part-2-ipc/)

- HostNetwork
開啟這個功能將使得 **Container** 本身的網路與節點是完全共用的，這意味可以從 **Container** 內部看到節點上面的網路資訊，譬如網卡數量， **IP** 地址，相關路由規則甚至是 **Iptables** 防火牆。
事實上 **kubernetes** 很多內建的服務都會開啟這些功能，最簡單的概念就是 **CNI** 都還沒有安裝的情況下，那些被預設安裝好的 **Pod** 到底是怎麼互通的? 其實就是透過這個方式直接使用節點上的網路功能來互通。

### Volumes and file systems
此功能是 **Kubernetes** 自行實作的，單純用來限制該 **Pod/Container** 可以使用哪些儲存空間類型與模式，譬如 **ConfigMap**, **HostPath**, **PVC** 等。

其實這類型的安全設定都秉持者一個概念，針對用到的部分去給予權限，也許會覺得管理起來很麻煩，但是就是一種限縮的概念

### Users and groups
期望系統用什麼樣的身份去運行該容器，目前於 **Linux** 中是透過 **UID/GID** 等數值搭配系統上的 **/etc/passwd, /etc/group** 來配對出該運行的角色是什麼身份。

我認為目前大部分的 **Docker Image** 還是都基於 **root** 的身份去創建的，這個帶來的一些隱性問題就是如果今天該 **Container** 透過 **Volumes** 的方式把一些系統上面的檔案都掛載到 **container** 內，那因為檔案系統的權限也是基於 **UID/GID** 去比對的，所以其實容器的 **root** 是有機會去修改掛載進來的檔案。

如果今天該 **container** 是個惡意的應用程式，就代表有機會可以存取到節點外的系統資訊，甚至對於其進行寫入造成影響。
所以比較好的方式是不要使用 **root** 來運行你的應用程式，創立特定的使用者與群組來處理。


此外如果對於 **NFS** 熟悉的人，也會知道 **NFS** 的存取權限也是基於 **UID/GID** 的處理，所以如果是一個以 **root** 身份去使用 **NFS** 的話，產生出來的所有檔案都會是 **root/root**，對於整個檔案分級的架構可能就會造成不預期的行為。


### Capabilities
針對 **Linux** 本身更深層的處理，有個名為 **Capabilities** 的權限控管工具可以使用，詳細的內容可以參考 [man capabilities](http://man7.org/linux/man-pages/man7/capabilities.7.html)

根據說明，其淵源以及功能為
>For the purpose of performing permission checks, traditional UNIX
implementations distinguish two categories of processes: privileged
processes (whose effective user ID is 0, referred to as superuser or
root), and unprivileged processes (whose effective UID is nonzero).
Privileged processes bypass all kernel permission checks, while
unprivileged processes are subject to full permission checking based
on the process's credentials (usually: effective UID, effective GID,
and supplementary group list).
Starting with kernel 2.2, Linux divides the privileges traditionally
associated with superuser into distinct units, known as capabilities,
which can be independently enabled and disabled.  Capabilities are a
per-thread attribute.

透過 **Capabilites** 將本來全部賦予給 **privileged** 權限的功能給拆出來，可以避免一個擁有無上功能的使用者，藉此來達到 **有使用才給予** 的原則。

不知道有多少人知道，其實如果沒有賦予權限的話，是不能使用 **ping** 這個功能的，是因為 **ping** 的底層是透過 **raw socket** 的方式去實現，而 **raw socket** 本身就是屬於直接收送封包的方式，本身就會有權限使用上的考量，因此必須要搭配 **CAP_NET_RAW** 這樣的權限才有辦法使用 **ping**。

但是這個功能因為太常用，所以其實這個能力已經變成預設值(以 Docker為範例，可參考[Runtime privilege and Linux capabilities](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities))

此外還有一個能力叫做 **CAP_NET_ADMIN**，一但開啟這個功能，就可以對所有的 **network stack** 進行操作，包括改 **IP** 地址，改路由規則，修改任何運行網卡設定，非常的強大。

這時候仔細想想，如果有一個 **Container** 本身被賦予 **CAP_NET_ADMIN** 的權限，同時也透過 **hostnetwork** 的方式與節點共享網路。

這意味者該 **Container** 擁有完全修改節點網路內容的能力，只要該應用程式想要作怪，整個節點直接斷線並且讓網路功能喪失都不是什麼問題，非常輕鬆。

所以使用者要非常謹慎小心，哪些能力需要額外賦予應用程式請斟酌考量，並且確實的了解其用途。


### AppArmor
可以參考[Kubernetes Apparmo](https://kubernetes.io/docs/tutorials/clusters/apparmor/) 的介紹
> AppArmor is a Linux kernel security module that supplements the standard Linux user and group based permissions to confine programs to a limited set of resources. AppArmor can be configured for any application to reduce its potential attack surface and provide greater in-depth defense. It is configured through profiles tuned to whitelist the access needed by a specific program or container, such as Linux capabilities, network access, file permissions, etc. Each profile can be run in either enforcing mode, which blocks access to disallowed resources, or complain mode, which only reports violations.
> 

基本上是個非常厭煩的功能，以 **profile** 為基本單位去限制相關應用程式能夠存取的所有東西，譬如 **capabilities**, **network**, **file permkissions**。

譬如以下範例
```c++
#include <tunables/global>
/bin/ping flags=(complain) {
  #include <abstractions/base>
  #include <abstractions/consoles>
  #include <abstractions/nameservice>

  capability net_raw,
  capability setuid,
  network inet raw,
  
  /bin/ping mixr,
  /etc/modules.conf r,
}
```

上述這個範例是針對 **/bin/ping** 這個應用程式去設定的，就如同上述提到的，需要有 **CAP_NET_RAW** 的能力，一旦只要 **ping** 本身被修改過使用到超過標注的，就會被 **apparmor** 給阻止而不能使用。

其使用上非常麻煩，但是可以限制非常多不必要的功能。

### Privileged
只要打開此功能，上述探討的一些特性都會一起被打開來創造一個非常有力的應用程式，包含可以讀取所有的裝置，有滿滿的 **capabilities**，請斟酌小心使用，不要對來路不明的應用程式使用這個權限。


# Summary
除了上述之外討論到的功能之外，還有其他非常多的細節，更不用說 **4C** 中其他領域都有各自的範圍與概念需要學習與探討。
資訊安全就是一個沒出事情前大家不會在意，甚至不覺得有幫助，但是一旦出了問題，可能就是一個動搖整個公司的問題。就我的角度這類型的概念就是會愈多愈好，你未來執行任何操作，撰寫任何程式時都能夠把安全的概念給套用，其實無形中就是增加整個系統與產品的安全。


# 參考
- https://kubernetes.io/docs/concepts/security/overview/
- https://github.com/coreos/clair/
- https://blog.yadutaf.fr/2013/12/28/introduction-to-linux-namespaces-part-2-ipc/
- https://kubernetes.io/docs/tutorials/clusters/apparmor/
- https://help.ubuntu.com/lts/serverguide/apparmor.html
