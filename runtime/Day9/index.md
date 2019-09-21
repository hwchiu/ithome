[Day9] Container Runtime - Virtual Machine
==========================================

> 本文同步刊登於 [hwchiu.com - Container Runtime - Virtual Machine](https://www.hwchiu.com/container-runtime-vm.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- Container Network Interface
- Container Storage Interface
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論


# 前言

本篇文章作為 `Container Runtime Interface` 系列文的最後一篇，這次的主題也是延續前兩篇，繼續探討各種不同的 `CRI` 解決方案。
藉由瞭解這些不同目的需求的解決方案，可以幫助我們去探索對於 `kubernetes` 的各種應用，畢竟有需求才會有開發，有人遇到了痛點是當前的 `kubernetes` 沒有辦法解決的，所以才會開始著手開發符合自己需求的方式。
如同最一開始闡述過，透過 `Container Runtime Inteface` 的架構，可以讓開發者更自由且彈性的去開發與發布這些功能，而不用跟 `kubernetes` 本身綁定導致開發週期過長。

前兩篇我們探討了兩種 `CRI `使用情境
1. 切換不同的 `CRI` 解決方案，譬如 `containerd` 與 `cri-o`, 但是底層都是基於 `runc` 這個 `OCI Runtime` 來產生 `Container`.
2. 為了安全性而誕生的 `OCI Runtime`, 譬如 `gVisor` 與 `kata container` 等。 透過 `OCI` 的標準架構，開發者與使用者都可以於 `containerd` 或是 `cri-o` 中將 `runc` 切換成這些更加安全的 `container`。

而今天要探討的則是第三種情形，是真正的 `Virtual Machine`，目的非常簡單，就是透過 `kubernetes` 去管理 `Virtual Machine`，統一透過 `Pod/Deployment` 等習慣的方式同事去管理 `Container` 與 `Virtual Machine`.

不同於 `Kata Container` 這種基於 `Virtual Machine` 的 `Container` 解決方案，本文探討的就是實實在在的 `Virtual Machine`，一點 `Container` 的概念都不存在的環境，使用者在建立該資源的時候甚至不是提供 `Container Image`，而是提供 `VM Image` 來創立服務。

# 緣由

如同前篇文中所述， `Container` 與 `Virtual Machine` 彼此的比較從來沒有中斷過，然而隨者微服務概念的普及與發展，愈來愈多的使用情境都在嘗試使用容器來管理，在這種前提下，為什麼會有這種純 `Virtual Machine` 的需求被提出?

如果今天的使用情境都是基於自己公司內部開發，那我覺得通常不會有這個問題，因為不同組別之間可以互相協調，規劃出一個對於開發，維運與測試都接受的模式與架構。

但是有些情況是運行的服務並非自行開發，而是第三方廠商的解決方案，並且將該解決方案給整合到 `Virtual Machine` 之中。
畢竟 `Virtual Machine` 發展的時間更久，有很多已經開發許久的軟體都是基於 `Virtual Machine` 的環境進行設計與使用，同時在販售與合作方面也都是基於 `VM Image` 的方式在發布，因此這會造成服務提供商的服務部分來自 `Container`，部分來自 `Virtual Machine`，那 `kubernetes` 能不能解決這個問題 ?

事實上就我目前接觸到的所有案例裡面，幾乎全部都跟 `Network Function Virtualization(NFV)` 有關。隨者 `NFV` 與 `OpenStaack` 的發展，很多的廠商開始將自己的服務從軟硬體綁在一起到當純只賣軟體，使用 `VM` 方式釋出該 `VM Image` 供他人使用。

對於一般的研究人員或是開發者來說，這個問題更加嚴重，因為支援不足與地位差距，你今天根本沒有辦法要求原開發商將軟體從 `VM` 轉移到 `Container`，這種情況下你會覺得很難處理，因為根本沒有辦法運行。

所以就漸漸有不同的方式被提出來解決這個問題，譬如 `OpenStack` 堆疊在 `Kubernetes `上，或是 `Kubernetes` 堆疊在 `OPenStack` 上，然後重新開發其他的管理工具同時掌管 `Kubernetes` 以及 `OpenStack`。

這樣的架構也許可行，但是卻將複雜度提升到一個難以理解的地方，對於開發者，使用者，維運者都帶來難以除錯與管理的問題，所以問題就退回到，能不能用 `kubernetes` 直接管理 `Virtual Machine`?

曾經覺得困難的問題，現在如果瞭解了 `CRI` 的架構與運作模式，對這個問題似乎就不會覺得太困難了，可以直接打造一個滿足 `CRI` 介面的程式，背後全部都用 `Virtual Machine` 去實現。
> 這個情況下可以完全不需要去管 OCI 標準了，因為我們的目標是純 Virtual Machine，不太需要管 Container。
> 

除了上述的難以容器化的原因外，還有一些原因是打造這種專案的契機
1. 混合作業系統環境的運行環境，對於一個全部都採用 `Linux` 環境架設的 `Kubernetes`  叢集，要如何在其中運行一些基於 `Windows` 環境的服務?
2. 安全性考量，就算有了前幾天關於 `gVisror` 與 `Kata Container` 相關的解決方案，也未必能夠說服所有人目前這兩個專案的開發以經處於 `Production Ready`，所以如果可以繼續研究已經運行長期的 `Virtual Machine` 環境是再好不過。


這方面我目前知道比較有名的專案為 `kubevirt` 以及 `virtlet`，那接下來會針對 `virtlet` 為主去介紹探討一下這種架構的設計，以及怎麼使用

# Virtlet

## Introduction
就跟前述的慣例一下，先看一下 [官方 GitHub](https://github.com/Mirantis/virtlet) 是如何描述自己這個專案的
> Virtlet is a Kubernetes runtime server which allows you to run VM workloads, based on QCOW2 images.
> 

這邊值得注意的是其用的詞是 `Kubernetes runtime server`, 這邊所指的就是 `Container Runtime Interface`，該專案本身額外實現了一個全新的應用程式，該應用程式本身支援 `CRI` 的 `gRPC` 介面，但是底下實現這些功能時全部都使用基於 `QCOW2 Images` 格式的 `Virtual Machine`。

## Design

`virtlet` 開發的初衷並不是要用 `VM` 取代所有的 `Container`, 而是希望能夠提供另外一種選擇。為了達成這個目的，則 `CRI` 的部分勢必要重新撰寫，不能使用原生的 `containerd` 或是 `cri-o`。

同時這個全新設計的 `CRI`處理程式也要能夠根據情況決定使用 `Virtual Machine` 或是 `Container` 來創建對應的運算資源。
於是乎，` CRI Proxy` 這個專案就因應這個需求而生

### CRI Proxy

`CRI Proxy Server` 的功能分成簡單，就是根據條件轉發 `CRI` 請求到不同的後端，針對 `container` 的部分，目前支援 `dockershim` 或是 `containerd` ，而針對 `Virtual Machine` 的部分則是 `virtlet` server 。

![](https://i.imgur.com/ixMsRIl.png)
本圖節錄自[GitHub CRIProxy](https://github.com/Mirantis/criproxy)

`CRI Proxy` 要用什麼條件來判斷到底該怎麼處理這個請求，這部分就使用上了 `kubernetes` 本身針對其資源內部提供的標記欄位，也就是所謂的 `annotation`

對於每個創建的 `Pod`，只要於 `metadata.annotations.kubernetes.io/target-runtime` 設定為 `virtlet.cloud`, 則 `CRI Proxy` 就會認得這個 `Pod` 要走 `VM` 去處理，而非傳統的 `Container`。

```yaml=
apiVersion: v1
kind: Pod
metadata:
  name: cirros-vm
  annotations:
    kubernetes.io/target-runtime: virtlet.cloud
...
```

透過這種標記的方式與架構，可以讓使用者方便的去根據需求來決定要使用 `VM` 還是 `Container`。

此外 `CRI Proxy` 會被 `kubelet` 呼叫，所以本身也是每個節點上都要存在，因此一開始會先用 `systemd` 的方式在每台節點上都運行安裝，這樣基本的 `kubelet` 才可以啟動。 接者所有沒有設定的 `Pod` 就會走 `kubelet` -> `CRI Proxy` -> `dockershim/containerd` 的方式以 `Container` 被創建出來。


### Architecture
除了上述的 `CRI Proxy` 之外，我們接下來看一下其完整的運作架構。

![](https://i.imgur.com/Kbf0zaf.png)
本圖節錄自 [Architecture](https://github.com/Mirantis/virtlet/blob/master/docs/docs/dev/architecture.md)

當 `CRI Proxy` 收到創建 `VM` 的請求後，就會將該 `CRI` 的請求轉發到後端處理，這個處理的角色就是 `Virtlet Container`，也是俗稱的 `virtlet Manager`。

當整個 `kubernetes` 系統起來後，會透過 `daemonset` 的方式去部署 `virtlet Manager` 
```bash=
vagrant@k8s-dev:~$ sudo kubectl -n kube-system get daemonset
NAME         DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-proxy   3         3         3       3            3           <none>          8h
virtlet      1         1         1       1            1           <none>          8h

vagrant@k8s-dev:~$ sudo kubectl get pods --all-namespaces -l runtime=virtlet
NAMESPACE     NAME            READY   STATUS    RESTARTS   AGE
kube-system   virtlet-gghd4   3/3     Running   0          8h
```

然而該 DaemonSet 本身其實也有設定節點的選擇條件，並非所有的節點都會部署，畢竟該節點要有能力產生 `VM`，目前使用的規則是該節點必須要含有個標籤 `extraRuntime: virtlet` 即可，值得注意的是其使用的條件是 `In`, 所以只要含有 `virtlet` 這個字的節點都會被部署 `virtlet Manager`。


```bash=
...
      spec:
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: extraRuntime
                  operator: In
                  values:
                    - virtlet
...
```

當 `virtlet Manager` 收到指令後，會透過 `libvirt` API 的方式進行後續的處理，叫起 `vmwrapper` 來產生對應的 `VM` 環境

> vmrapper is run by libvirt and wraps the emulator (QEMU/KVM). It requests tap file descriptor from Virtlet, adds command line arguments needed by the emulator to use the tap device and then execs the emulator.
> 

其完整架構非常複雜，其中自行設計了不少元件來處理資源的處理，譬如使用 `tapmanager` 來處理整個 `CNI`，這部分幾乎沒有文件，只能依賴閱讀原始碼的方式來理解其實作方法。

[vm-pod-lifecycle](https://github.com/Mirantis/virtlet/blob/master/docs/docs/dev/vm-pod-lifecycle.md) 這邊描述了關於 `Pod` 創造與刪除時整體處理流程，非常的長，有興趣的可以自行閱讀。

## Installation

[官方文件](https://docs.virtlet.cloud/user-guide/virtlet-on-kdc/) 中有提供兩種安裝方式，一種是使用 `kubernetes-dind-cluster` 去安裝整個測試環境，另外一種則是按部就班的描述要安裝的所有元件，只是單純測試跟研究的話，我認為選擇第一種會比較方便

我自己的電腦環境是`MAC Pro`，平常都會透過 `Vagrant + VirtualBox` 產生一個 Linux 環境來測試，這次就基於這個 `Linux` 的環境使用 kubernetes-dind-cluster 安裝 kubernetes 並且在裡面使用 virtlet 產生 VM。

架構如下，非常的有趣
1. 先疊一層 VM
2. 裡面創三個 `Container`, 以這三個 `Container` 組成一個 `Kubernetes Cluster`
3. Kubernetes 使用 `Virtlet` 作為其 `CRI` 解決方案，最後在裡面產生一個基於 `Virtual Machine` 的 `Pod`
![](https://i.imgur.com/Gsh8hwW.png)

### Steps
1. 準備好 Ubuntu 環境，下載[demo.sh](https://github.com/Mirantis/virtlet/blob/master/deploy/demo.sh)
2. 執行安裝，我自己是沒有遇到任何問題
3. 最後會幫你創建好 VM 並且要你透過 ssh 登入到該 VM, 密碼是 `gocubsgo`.

![](https://i.imgur.com/7e93E60.png)

可以看到創建出來的 `pod`, 有特別標注一個 `annotations`，這樣 `CRIProxy` 就會根據需求使用 `containerd` 或是 `VM` 來創建服務
![](https://i.imgur.com/WRQiVBg.png)

這時候透過 `kubectl get pods -o wide` 取得該 `Pod` 運行的節點位置，並且透過 `docker exec -it $name bash` 到節點裡面進行觀察

透過觀察真的發現該節點內透過 `qemu` 創建了一個 `VM`
![](https://i.imgur.com/gxHHxuN.jpg)

除了上述最簡單的範例之外，[GitHub](https://github.com/Mirantis/virtlet/tree/master/examples) 這邊還有提供其他不同的 `Yaml`, 其中我覺得非常有趣的就是 [k8s.yml](https://github.com/Mirantis/virtlet/blob/master/examples/k8s.yaml)

可以讓你在 `kubernetes` 裡面透過 `VM` 產生另外一個 `kubernetes` cluster， 我暫時想不到應用情境，但是就是一個很有趣的架構。
節錄一下裡面的內容，可以看到該 `VM` 起來後會透過 `kubeadm` 的方式去初始化一個 cluster.
```yaml=

          - path: /usr/local/bin/provision.sh
            permissions: "0755"
            owner: root
            content: |
              #!/bin/bash
              set -u -e
              set -o pipefail
              curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
              apt-get update
              apt-get install -y docker.io kubelet kubeadm kubectl kubernetes-cni
              sed -i 's/--cluster-dns=10\.96\.0\.10/--cluster-dns=10.97.0.10/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
              systemctl daemon-reload
              if [[ $(hostname) =~ -0$ ]]; then
                # master node
                kubeadm init --token adcb82.4eae29627dc4c5a6 --pod-network-cidr=10.200.0.0/16 --service-cidr=10.97.0.0/16 --apiserver-cert-extra-sans=127.0.0.1,localhost
                export KUBECONFIG=/etc/kubernetes/admin.conf
                export kubever=$(kubectl version | base64 | tr -d '\n')
                kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"
                while ! kubectl get pods -n kube-system -l k8s-app=kube-dns|grep ' 1/1'; do
                  sleep 1
                done
                mkdir -p /root/.kube
                chmod 700 /root/.kube
                cp "${KUBECONFIG}" /root/.kube/config
                echo "Master setup complete." >&2
              else
                # worker node
                kubeadm join --token adcb82.4eae29627dc4c5a6 --discovery-token-unsafe-skip-ca-verification k8s-0.k8s:6443
                echo "Node setup complete." >&2
              fi
              
```

# Summary

`Container Runtime Interface(CRI)` 的文章到這邊告了一個段落，我個人對於 `CRI` 這種介面的設計是滿喜歡的，透過介面將實作與主體抽離，能夠讓社群開發者自己開發想要的功能，同時又能夠簡單且順利的與 `kubernetes` 整合。

也正是因為如此才可以看到各式各樣針對不同議題而努力的專案，每個專案都有自己的特色與優劣，所以對於一個管理者來說，如果能夠理解這些不同的解決方案的優劣之處，不論是基於 `CRI` 標準的方案，或是更底下相容於 `OCI Runtime` 的實作，對於未來遇到任何不同的使用情境與問題時，腦中就可以很快的反射出是不是有相關的議題與資源可以去研究，而不會只用一套 `docker` 打天下。

接下來將針對網路的部分，從 `Container Network Interface(CNI)` 為出發點介紹其概念與架構，也包含了 `ipam` 的介紹，讓大家知道到底 `IP` 是怎麼被分配與指派的，接者也會探討常見的 `calico` 與 `flannel` 的差異。

# 參考
- https://github.com/Mirantis/criproxy
- https://github.com/Mirantis/virtlet
