[Day18] Container Storage Interface 基本介紹
==========================================

> 本文同步刊登於 [hwchiu.com - CSI 介紹](https://www.hwchiu.com/csi.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

講完了 **Container Rnntime Interface(CRI)** 以及 **Container Network Interface(CNI)** 兩大資源後，我們將來探討最後的一塊拼圖，所謂的 **Container Storage Interface(CSI)**。

儲存這個領域於系統應用中也是百百情境百百解，與網路一樣都需要根據不同的需求導入不同的解決方案。
此外儲存這領域到底與 **kubernetes** 彼此之間的責任歸屬到底該怎麼分配，我覺得也是一個很重要的議題，因為最近實在看到太多為了 **kubernetes** 而 **kubernetes** 的推法，完全沒有考慮到轉移的成本與難題，就希望 **kuberntes** 能夠接手一切事物，因此接下來的文章機會著重於 **Storage** 這一塊的介紹。

## Before Kubernetes

各位其實可以回想一下過往所有的經驗中，遇過儲存什麼樣的問題以及議題?
1. 光檔案系統本身就是一個戰局，BTRFS, Ext4, ZFS, CephFS, GLusterFS，各自的特色與優劣該如何選擇
2. 快照的支援，以及快照後容量是否加倍？
3. LLVM/RAID/RAID2.0 等相關議題的討論，能夠容錯多少硬碟，能夠多快修復?
4. RWO 讀寫的限制，可否同時多重讀寫或是只能單一處理?
5. 介面的選擇，是更底層的 Block Device 還是上層已經包裝可以使用的檔案系統路徑?
6. 異地備援? 本地備援? 
7. 儲存服務本身有沒有HA的機制，有沒有SLA的保障?
9. ...等

過往方面就有洋洋灑灑的議題要處理，很多情況甚至都是尋找獨立的儲存廠商進來與現存系統整合，提供一個儲存解決方案，將這些問題都責任歸屬來處理，讓儲存伺服器本身來負責這些議題，而自己的服務則專注於處理獨特的商業邏輯。

如果過往操作與維運上有這些經驗與概念，今天要將服務全面導向 Kubernetes，也一定要有一樣的概念來處理，因為 kubernetes 本身沒有任何進階的儲存功能，上面提到的概念與技術全部都沒有，一切都是要仰賴額外的儲存設備與技術來提供這些功能，所以不要抱持太大的夢想 kubernetes 能夠提供一步到位解決所有事情。

## Kubernetes

**kubernetes** 針對儲存部分，使用者可以使用的方式有很多種，雖然看似多種，其實背後的邏輯脈絡是一致的。
1. 宣告／請求 儲存空間
2. **Pod** 去請求使用以創立的儲存空間來使用
3. **Container** 裡面描述如何使用 **Pod** 請求來的儲存空間

最簡單的使用方法就是將上述所有邏輯全部都描述在同一個 **Pod** 的資源中，統一管理統一維護，但是這種方法一旦該儲存空間是需要跨 **Pod** 使用時就會帶來維護不見。

所以可以透過 **PersistemVolume** 以及 **PersistemVolumeClaim** 等不同層級的儲存空間概念來維護，作為整個 kubernetes cluster 內部資源的話對於共用，管理方面也都有相當好的控管性。

然而上述的資源調度有時候又太過於靜態，缺乏彈性，因此後來又衍生出 **StorageClass** 這種動態請求的資源，對於使用者來說可以減少更多設定，整體使用起來會更加順手。

關於上述三種資源的彼此關係，概念，可以參考這篇文章 [kubernetes storage](https://www.hwchiu.com/kubernetes-storage-i.html)

除了這三個類別資源外，其實還有兩個常用的資源也與儲存息息相關，**ConfigMap** 以及 **Secret**， 這兩個資源設定的介面與上述提到的些許不同，但是最後都會以檔案或其他的形式出現於 **Container** 供應用程式使用。
只要能夠讓 **Container** 有辦法存取到外部的存取空間，這過程都會牽扯到 **Container** 的創造，甚至是 **Linux Mount Namespace** 的涉入與處理。

對於大部分的使用者來說， **Storage** 的介面(上述概念)用起來都不會有太多的問題，選定好自己要使用的儲存後端，參考文件如何設定，接下來到 **Pod** 層級時使用就相對簡單，不會有太多設定上的困擾。 那到底 **Container Storage Interface** 於整個過程中是扮演什麼角色? 這個問題就是接下來的幾篇文章會探討的，並且說明為什麼要引入 **CSI** 以及其可以帶來什麼樣的幫助。

## Why Container Storage Interface

如同前述探討 **CRI** 以及 **CNI** 時都有討論過為什麼要使用 **Interface** 的理由，藉由將模組與主程式抽離，讓各自的專案都有自己的開發週期，彼此不會互相被影響而導致開發或使用受阻。

這一篇官方部落格的文章 [Container Storage Interface (CSI) for Kubernetes GA](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/) 有特別描述到為什麼需要 **Container Storage Interface**。

> Although prior to CSI Kubernetes provided a powerful volume plugin system, it was challenging to add support for new volume plugins to Kubernetes: volume plugins were “in-tree” meaning their code was part of the core Kubernetes code and shipped with the core Kubernetes binaries—vendors wanting to add support for their storage system to Kubernetes (or even fix a bug in an existing volume plugin) were forced to align with the Kubernetes release process. In addition, third-party storage code caused reliability and security issues in core Kubernetes binaries and the code was often difficult (and in some cases impossible) for Kubernetes 
> maintainers to test and maintain.

長期以來所有儲存的解決方案的整合端都是直接實作於 **Kubernetes** 的程式碼內，也是所謂的 **in-tree** 所描述的概念，這導致對於這些儲存應用服務的提供者很難及時的增加修復任何問題，因為全部的功能都跟 **kubernetes** 本身綁再一起，若 **kubernetes** 本身沒有更新，則使用者也都享受不到修復或是新功能。
更重要的是這些儲存相關程式碼本身的安全性程度以及穩定性都會變成額外的隱憂，是否會對 **kubernetes** 本身帶來各種負面的都是不能掌握的，同時這些程式碼的維護對於 **kubernetes** 維護者來說也是不好維護及掌握的。


>CSI was developed as a standard for exposing arbitrary block and file storage storage systems to containerized workloads on Container Orchestration Systems (COs) like Kubernetes. With the adoption of the Container Storage Interface, the Kubernetes volume layer becomes truly extensible. Using CSI, third-party storage providers can write and deploy plugins exposing new storage systems in Kubernetes without ever having to touch the core Kubernetes code. This gives Kubernetes users more options for storage and 
>makes the system more secure and reliable.

為了解決這個問題於是提出了 **Container Storage Interface** 的概念，希望能夠將儲存方面的程式碼都搬出去 **kubernetes** 本身，如同 **CRI/CNI** 一樣，能夠讓 **kubernetes** 專心維護與介面供通的整合，而其餘的儲存解決方案提供商專注於 **CSI** 介面的開發，最後就可以透過參數等方式來間接使用與整合。

那說了這麼多，今天 **CSI** 全面引進後，對於使用者到底會有什麼差異? 有什麼部分需要修改以符合新的架構?

我們先來看一下沒有使用 **CSI** 的架構，會怎麼使用 **Network File System (NFS)**。

```yaml=
kind: Pod
apiVersion: v1
metadata:
  name: nfs-in-a-pod
spec:
  containers:
    - name: app
      image: alpine
      volumeMounts:
        - name: nfs-volume
          mountPath: /var/nfs # Please change the destination you like the share to be mounted too
      command: ["/bin/sh"]
      args: ["-c", "sleep 500000"]
  volumes:
    - name: nfs-volume
      nfs:
        server: nfs.example.com # Please change this to your NFS server
        path: /share1 # Please change this to the relevant share
```
從上述的 **yaml** 中可以看到直接描述使用 **NFS** 的結構，並且因為 **NFS** 需要的參數有兩個，因此也需要於 **yaml** 去描述這兩個參數。

這個用法非常的綁死，實際上這些 **yaml** 的解讀都是依賴 **kubernetes** 本身去處理，所以其本身關於 **volume** 的資料結構中就包含了 **NFS** 的欄位，以及相關的參數，這種情況對於 **NFS** 來說有任何修改增減，都必須要修改 **kubernetes** 原始碼，也是所謂的 **in-tree** 架構造成的困境。


如果改善成 **CSI** 之後，整個應用會變成怎麼樣？
```yaml=
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-nfsplugin
  labels:
    name: data-nfsplugin
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 100Gi
  csi:
    driver: csi-nfsplugin
    volumeHandle: data-id
    volumeAttributes: 
      server: 127.0.0.1
      share: /export
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-nfsplugin
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  selector:
    matchExpressions:
    - key: name
      operator: In
      values: ["data-nfsplugin"]
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx 
spec:
  containers:
  - image: maersk/nginx
    imagePullPolicy: Always
    name: nginx
    ports:
    - containerPort: 80
      protocol: TCP
    volumeMounts:
      - mountPath: /var/www
        name: data-nfsplugin 
  volumes:
  - name: data-nfsplugin
    persistentVolumeClaim:
      claimName: data-nfsplugin 
``` 

可以看到這個範例中，不再使用 **NFS** 的關鍵字，而是採用了 **CSI** 這個關鍵字，並且於其中描述了幾個資訊
1. driver:
類似 **CNI** 設定檔案中的 **type**，描述要用哪個對應的 driver 來處理這個儲存需求
2. volumeHandle:
一組重複使用的 ID，之後會再介紹
3. volumeAttributes: 
    - server: 127.0.0.1
    - share: /export    
    客製化的參數，根據不同的 Driver 傳入不同的參數。
        
根據目前[官方文件](https://kubernetes.io/docs/concepts/storage/volumes/#csi) 裡面的描述，現在 **CSI** 使用的參數如戲ㄚ
- driver
- volumeHandle
- readOnly
- fsType
- volumeAttributes
- controllerPublishSecretRef
- nodeStageSecretRef
- nodePublishSecretRef

這邊的參數與 **CSI** 的標準以及運作流程有關，因此等到介紹 **CSI** 標準後會再來重新看這些參數。


套用 **CSI** 的架構後，最大的差異使用就是之後所有的儲存連接都要使用 **CSI** 這個選項來描述，而非以前直接去描述目標的儲存解決方案。

# Summary
本文討論了 Kubernetes 與儲存的一些基本關係，並且帶出了 **Container Storage Interface** 與 **Kubernetes** 的使用方式。

接下來會開始探討 **CSI** 相關的架構，並且以一些已經實現的 **CSI** 解決方案來討論該怎麼使用。

# 參考
- https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/
- https://github.com/kubernetes-csi/drivers/blob/master/pkg/nfs/examples/kubernetes/nginx.yaml
- https://docs.docker.com/ee/ucp/kubernetes/storage/use-nfs-volumes/
