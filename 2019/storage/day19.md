[Day19] Container Storage Interface 標準介紹
==========================================

> 本文同步刊登於 [hwchiu.com - CSI 標準介紹](https://www.hwchiu.com/csi-ii.html)

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

上篇文章已經基於儲存的部分進行了一些討論，簡單介紹一下目前 **kubernetes** 提供跟儲存有關的資源之外，也探討了一下 **CSI** 標準的引進以及為什麼需要有這個標準，同時也用了一個範例展示有無 **CSI** 對於使用者所帶來的影響。此外我覺得上篇最重要的還是一個觀念，就是 **kubernetes** 本身只作為一個容器管理平台，透過介面標準與第三方儲存方案整合並且將該儲存方案提供給容器使用，而各式各樣儲存本身的議題，功能都是第三方儲存方案需要提供， **kubernetes** 本身並不負責這些功能，所以各位選擇儲存方案時，本身就需要對儲存伺服器以及相關知識有所概念，而不是一昧的都在 **kubernetes** 這邊打轉，這樣其實對於解決問題沒有太大的幫助。

本篇文章則會探討一下 **CSI** 的架構，就如同 **CRI/CNI** 兩個標準一樣，會先探討這個標準的介面，以及相關流程，接下來會用一些範例來實際演練試試看使用 **CSI** 的操作過程

# CSI

**Container Storage Interface** 標準相關的檔案都由 [GitHub container-storager-interface](https://github.com/container-storage-interface) 這個組織維護，裡面最主要的部分有兩個，分別是 **specification** 以及 **protobuf** 這兩個類別。

**protobuf** 這部分先暫時不探討，等等介紹標準時若有相對的部分就會拿出來剩下比對，剩下的就有興趣自己實作的可以再參考文件與該[檔案](https://github.com/container-storage-interface/spec/blob/master/csi.proto)
來學習怎麼實現一個 **CSI** 的一個解決方案。

題外話，除了 **CSI** 之外，[CRI](https://github.com/kubernetes/cri-api/blob/master/pkg/apis/runtime/v1alpha2/api.proto) 也使用 **protobuf** 定義其溝通介面標準，近年來 **protobuf** 的使用量逐漸上升，而且各大專案都可以看到<

# 回顧 Kubernetes

讓我們回顧一下以前怎麼使用 **kubernetes** 裡面的資源來取用第三方的儲存服務，這邊以 **glusterfs** 為範例，一個簡單的使用流程是
1. 安裝 **glusterfs** 到所有節點，包含相關設定以及相關應用程式
2. 部署與儲存解決方案整合的檔案
    - 動態部署的話會採用 **storageClass**
    - 靜態事先部署的會採用 **PersistentVolume**
4. 部署 PersistentVolumeClaim 去描述怎麼要資源
5. 運行運算資源 **Pod** 的時候描述要使用上述的 **PersistentVolumeClaim**。

示意範例如下列三個 **yaml** 檔案
```yaml=
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: gluster-heketi-external
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://a.b.c.d:8080"
  restuser: "admin"
  secretName: "heketi-secret"
  secretNamespace: "default"
  volumetype: "replicate:3"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: gluster-pvc
 annotations:
   volume.beta.kubernetes.io/storage-class: gluster-heketi-external
spec:
 accessModes:
  - ReadWriteMany
 resources:
   requests:
     storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: gluster-pod
  labels:
    name: gluster-pod  
spec:
  containers:
  - name: gluster-pod
    image: busybox       
    command: ["sleep", "60000"]
    volumeMounts:
    - name: gluster-vol
      mountPath: /usr/share/busybox 
      readOnly: false
  securityContext:
    supplementalGroups: [590]       
    privileged: true
  volumes:
  - name: gluster-vol   
    persistentVolumeClaim:
      claimName: gluster-pvc
```

今天如果換成其他類型的儲存方案，譬如 **NFS**, **Ceph**, 相關公有雲的解決方案，大致上流程都差不多，主要就是(1)與(2)的部分有所不同。

所以回到 **Container Storage Interface** 來看，今天該標準希望能夠把上述裡面跟第三方儲存方案有關的部分都標準化，其實主要的部分也就是(2)。

首先因為 (1) 安裝各種相關檔案與設定這個部分本來就無法標準，這個是各個方案自己去處理的，而 **PersistentVolumeClaim** 這邊本來就是已經抽象化過，所以需要處理的部份就是(2)的部分，不論是 **StorageClass** 或是 **PersistentVolume** 都需要重新整理，譬如下列兩個用法都會分別是用 **provisioner** 或是 **csi.driver** 兩個格式來描述該儲存解決方案提供者的名稱。

```yaml=
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: fast-storage
provisioner: csi-driver.example.com
parameters:
  type: pd-ssd
  csi.storage.k8s.io/provisioner-secret-name: mysecret
  csi.storage.k8s.io/provisioner-secret-namespace: mynamespace
```

```yaml=
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-manually-created-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  csi:
    driver: csi-driver.example.com
    volumeHandle: existingVolumeName
    readOnly: false
    fsType: ext4
    volumeAttributes:
      foo: bar
    controllerPublishSecretRef:
      name: mysecret1
      namespace: mynamespace
    nodeStageSecretRef:
      name: mysecret2
      namespace: mynamespace
    nodePublishSecretRef
      name: mysecret3
      namespace: mynamespace
```      

# CSI 標準
回到 **Container Storage Interface** 的架構，先來看看官方怎麼描述 **CSI** 的[目標](https://github.com/container-storage-interface/spec/blob/master/spec.md#goals-in-mvp)
>The Container Storage Interface (CSI) will
* Enable Storage Provider authors to write one CSI compliant Plugin that “just works” across all Container Orchestration systems that implement CSI.
* Define API (RPCs) that enable:
  * Dynamic provisioning and deprovisioning of a volume.
  * Attaching or detaching a volume from a node.
  * Mounting/unmounting a volume from a node.
  * Consumption of both block and mountable volumes.
  * Local storage providers (e.g., device mapper, lvm).
  * Creating and deleting a snapshot (source of the snapshot is a volume).
  * Provisioning a new volume from a snapshot (reverting snapshot, where data in the original volume is erased and replaced with data in the snapshot, is out of scope).
 

1. 跟其他標準有一樣的目標，可以讓任何解決方案的提供者(這邊是儲存)，只要撰寫一套解決方案的實作，就可以再所有支持該 **CSI** 標準的容器管理平台使用。這對於開發者來說是個非常好的吸引力，只要這個標準夠大，支援平台夠多，就可以專注的維護本身解決方案的程式碼，而減少去整合各式各樣不同平台的心力

透過 **protobuf** 所描述的 **API** 希望滿足下列條件
- 支援動態配置或是靜態配置，其實對應到 **kubernetes** 就是 **storageclass** 以及 **PersistentVolume** 的概念
- Attach/Mount 的差異我認為在於層級不同，Attach 代表的是該 Node 有能力可以跟該儲存方案連接起來，而 Mount 則是將該儲存空間給實體化後可以透過 **Filesystem** 去存取。
- 支援 Block Device (EBS) 或是可直接 Mountable Volumes (大家應該大部分都用這個)
- 支援本地儲存設備解決方案，譬如 (device mapper, lvm)，這些又是以前的儲存議題了
- 支援創建/刪除快照
- 可提供從先前創造的快照復原出任何空間

以上是 **API** 定義的標準，沒有規定 **CSI** 解決方案要全部實作，這部分是依據每個方案的特性去實現即可。

## 組成架構

接下來看一下 **CSI** 的架構中會有什麼樣的角色，譬如 **CRI** 中規定要有一個伺服器實現 **CRI** 標準即可，而 **CNI** 則是要有一個支援 **CNI** 標準的執行檔案即可。

**CSI** 相對複雜，其組成至少要有兩個元件，分別是 **Controller** 以及 **Node** 這兩種不同 **API** 的實作。

根據 [官方說明](https://github.com/container-storage-interface/spec/blob/master/spec.md#rpc-interface)
> Node Plugin: A gRPC endpoint serving CSI RPCs that MUST be run on the Node whereupon an SP-provisioned volume will be published.
Controller Plugin: A gRPC endpoint serving CSI RPCs that MAY be run anywhere.
>

所有要使用該儲存解決方案的節點都必須要有一個對應的應用程式來提供 **Node** 的服務，而控管整個儲存解決方案的管理者 **Controller** 本身並沒有限定要運行在哪個節點。

從剛剛上述的 **CSI protobuf** 的檔案也可以看到有兩個明顯的 service 需要實作，如下

```golang=
service Controller {
  rpc CreateVolume (CreateVolumeRequest)
    returns (CreateVolumeResponse) {}

  rpc DeleteVolume (DeleteVolumeRequest)
    returns (DeleteVolumeResponse) {}

  rpc ControllerPublishVolume (ControllerPublishVolumeRequest)
    returns (ControllerPublishVolumeResponse) {}

  rpc ControllerUnpublishVolume (ControllerUnpublishVolumeRequest)
    returns (ControllerUnpublishVolumeResponse) {}

  rpc ValidateVolumeCapabilities (ValidateVolumeCapabilitiesRequest)
    returns (ValidateVolumeCapabilitiesResponse) {}

  rpc ListVolumes (ListVolumesRequest)
    returns (ListVolumesResponse) {}

  rpc GetCapacity (GetCapacityRequest)
    returns (GetCapacityResponse) {}

  rpc ControllerGetCapabilities (ControllerGetCapabilitiesRequest)
    returns (ControllerGetCapabilitiesResponse) {}

  rpc CreateSnapshot (CreateSnapshotRequest)
    returns (CreateSnapshotResponse) {}

  rpc DeleteSnapshot (DeleteSnapshotRequest)
    returns (DeleteSnapshotResponse) {}

  rpc ListSnapshots (ListSnapshotsRequest)
    returns (ListSnapshotsResponse) {}

  rpc ControllerExpandVolume (ControllerExpandVolumeRequest)
    returns (ControllerExpandVolumeResponse) {}
}
```

```golang=
service Node {
  rpc NodeStageVolume (NodeStageVolumeRequest)
    returns (NodeStageVolumeResponse) {}

  rpc NodeUnstageVolume (NodeUnstageVolumeRequest)
    returns (NodeUnstageVolumeResponse) {}

  rpc NodePublishVolume (NodePublishVolumeRequest)
    returns (NodePublishVolumeResponse) {}

  rpc NodeUnpublishVolume (NodeUnpublishVolumeRequest)
    returns (NodeUnpublishVolumeResponse) {}

  rpc NodeGetVolumeStats (NodeGetVolumeStatsRequest)
    returns (NodeGetVolumeStatsResponse) {}


  rpc NodeExpandVolume(NodeExpandVolumeRequest)
    returns (NodeExpandVolumeResponse) {}


  rpc NodeGetCapabilities (NodeGetCapabilitiesRequest)
    returns (NodeGetCapabilitiesResponse) {}

  rpc NodeGetInfo (NodeGetInfoRequest)
    returns (NodeGetInfoResponse) {}
}
```

此外 **Node** 以及 **Controller** 都必須要實現另外一個名為 **Identity** 的 Service 來表明自己的身份與能力。

```golang=
service Identity {
  rpc GetPluginInfo(GetPluginInfoRequest)
    returns (GetPluginInfoResponse) {}

  rpc GetPluginCapabilities(GetPluginCapabilitiesRequest)
    returns (GetPluginCapabilitiesResponse) {}

  rpc Probe (ProbeRequest)
    returns (ProbeResponse) {}
}
```

所以基於這種情況下，我們可以想像一個解決方案可能會有一些不同的架構
1. 不同的應用程式，分別各自實現 **Controller** 以及 **Node** 的服務
2. 使用相同的應用程式，內部同時實現兩個服務。

此外官方也提供了四種參考的部署方式，主要還是會依據不同儲存方案本身的特性去設計。
下圖的 **master** 以及 **node** 兩種不同的節點身份可對應到 **kubernetes** 內的 **master** 以及 **worker** 節點。

第一種是中央集權管理的部署方式，於 **Master** 去部署 **Controller** 服務，而剩下**所有的**工作節點都要部署 **Node** 服務。
![](https://i.imgur.com/db7o9fq.png)

第二種則是不管 **Master** 節點了，把 **Controller** 服務部署到其中一個 **worker** 節點即可。
![](https://i.imgur.com/1h1vlVs.png)

第三種則是將兩個服務整合，透過一個應用程式去實現 **Controller** 以及 **Node** 的介面，這種情況下部署就是將該應用程式部署到所有的 **worker** 節點即可
![](https://i.imgur.com/5W7XtVW.png)

第四種則是一個非常稀少，少到官方也沒有說明什麼類型會這樣部署，就是沒有 **Controller** 的解決方案，單純依賴 **Node** 的服務來處理所有儲存相關資院的創建與釋放。
![](https://i.imgur.com/3D4vvqR.png)


基於這些內容的討論，至少可以確認對於 **CSI** 的儲存方案來說，可以預想到部署時應該會採用 **DaemonSet** 的方式來部署 **Noode** 服務，而對於 **Controller** 服務來說則是不一定。

## Lifecycle

接下來看一下最重要的生命週期，看看到底 **Container Orchestration**, **Controller**, **Node** 這三者到底會怎麼合作來提供儲存空間。

這部分也是有多種流程，主要取決於儲存方案本身的能力。
開始前先來定義一些相關名詞

### Controller
- Create Volume
此呼叫是請求儲存方案根據需求去創建一個可用的儲存空間，但是就只是創造出來該空間而已，還沒有辦法被使用。以 **AWS** 來說可能就是創造一個 **Volume**
- Controller Publish Volume
此呼叫是請求儲存空間將之前創造的 **volume** 與特定的節點進行連動，譬如該節點有能力去存取該創造出來的 **Volume**。 以 **AWS** 來說就將創造好的 **Volume** 掛載到特定的運算資源上(VM)
### Node
- Stage Volume
當透過上述 **Controller** 的相關操作將 **Volume** 給掛載到節點後，接下來可以對 **Node** 進行 **stage** 的動作，將該 **Volume** 給掛到一個暫時的位置，接下來相關的工作資源**Pod** 就可以使用，甚至可以多個 **Pod** 共享。
此外這個步驟也需要確保該 **Volume** 有被格式化過
- Publish Volume
這是最後一個步驟，透過類似 **bind mount** 的方式將欲使用的儲存空間給投入到 **Pod** 裡面去使用 

上面的敘述沒有非常精準的描述一切行為，因為對於 **Block Device** 以及 **Mountable Volume** 來說，兩者的使用方法不太一樣，因此執行的行為也會有點差異。而上述的行為描述比較偏向將一個 (block device) 提供給多個 **Pod** 去使用。


>The main difference between block volumes and mount volumes is the expected result of the NodePublish(). For mount volumes, the CO expects the result to be a mounted directory, at TargetPath. For block volumes, the CO expects there to be a device file at TargetPath. The device file can by a bind-mounted device from the hosts /dev file system, or it can be a device node created at that location using mknod()
>


接下來看一下[官方](https://github.com/container-storage-interface/spec/blob/master/spec.md#volume-lifecycle)分享的幾個可能的運作流程
```
   CreateVolume +------------+ DeleteVolume
 +------------->|  CREATED   +--------------+
 |              +---+----+---+              |
 |       Controller |    | Controller       v
+++         Publish |    | Unpublish       +++
|X|          Volume |    | Volume          | |
+-+             +---v----+---+             +-+
                | NODE_READY |
                +---+----^---+
               Node |    | Node
            Publish |    | Unpublish
             Volume |    | Volume
                +---v----+---+
                | PUBLISHED  |
                +------------+

Figure 5: The lifecycle of a dynamically provisioned volume, from
creation to destruction.
```

可以看到這邊描述的是 **Dynamically Provisioned Volume**，對應到 **kubernetes** 就是所謂的 **StorageClass**。 此範例中就是呼叫 **Controller** 去創建空間，接者透過 Publish 使其與 **Node** 互動，最後直接透過 **Publish Volume** 掛到對應的 **Container** 中。這範例中就沒有去使用 **Stage** 的概念，因為創造出來的空間就是直接可存取的 **Mount Volume**，譬如 [NFS](https://github.com/kubernetes-csi/csi-driver-nfs/blob/adb36fc9cd2a078c34311cf78828e6aad2c9d996/pkg/nfs/nodeserver.go#L134)


```
   CreateVolume +------------+ DeleteVolume
 +------------->|  CREATED   +--------------+
 |              +---+----+---+              |
 |       Controller |    | Controller       v
+++         Publish |    | Unpublish       +++
|X|          Volume |    | Volume          | |
+-+             +---v----+---+             +-+
                | NODE_READY |
                +---+----^---+
               Node |    | Node
              Stage |    | Unstage
             Volume |    | Volume
                +---v----+---+
                |  VOL_READY |
                +------------+
               Node |    | Node
            Publish |    | Unpublish
             Volume |    | Volume
                +---v----+---+
                | PUBLISHED  |
                +------------+

Figure 6: The lifecycle of a dynamically provisioned volume, from
creation to destruction, when the Node Plugin advertises the
STAGE_UNSTAGE_VOLUME capability.
```

與上述行為雷同，不過面對的是 **block device** 的類別，所以還需要經過 **stage** 階段進行一次處理，才可以讓 **block device** 能夠被多次存取。


```
    Controller                  Controller
       Publish                  Unpublish
        Volume  +------------+  Volume
 +------------->+ NODE_READY +--------------+
 |              +---+----^---+              |
 |             Node |    | Node             v
+++         Publish |    | Unpublish       +++
|X| <-+      Volume |    | Volume          | |
+++   |         +---v----+---+             +-+
 |    |         | PUBLISHED  |
 |    |         +------------+
 +----+
   Validate
   Volume
   Capabilities

Figure 7: The lifecycle of a pre-provisioned volume that requires
controller to publish to a node (`ControllerPublishVolume`) prior to
publishing on the node (`NodePublishVolume`).
```
最後一個則是 **pre-provisioned** 的類別，所以事先創立好的空間已經先準備好相關的資源，所以就透過兩次的 **Push** 把該空間給掛載到 **Pod** 裡面使用。

除了這些基本流程之外，整個 **CSI** 裡面的規範還有非常多的細節，譬如 snapshot的處理，各式各樣能力需要怎麼處理請求與回應，這邊我想就是針對儲存空間有興趣的人可以自行研究，並且嘗試開發一個簡易的 **CSI** 套件看看。


# Summary

綜觀下來， **CSI** 其運作的流程與之前使用 **StorageClass**, **PVC** ,**PV** 非常雷同，此外若本身有在使用公有雲的服務，裡面提供的儲存服務用法也大概如此。
先創建，接者連接，最後存取，而這次只是把存取的角色限定為 **Container** 而連接的部分都是所謂的系統節點罷了。

說罷了系統設計本一家，看似嶄新的發展其實背後也是用到了很多過往的經驗與技術，譬如所謂的 **block device/mountable volume** 或是 **mount, bind mount**，這些底子的技術若平常就有精進累積，來看這些相關的知識與架構就會覺得沒那麼陌生，甚至覺得上手不會太困難。

# 參考

- https://kubernetes.io/docs/concepts/storage/volumes/#csi
- https://github.com/container-storage-interface/spec
- https://medium.com/searce/glusterfs-dynamic-provisioning-using-heketi-as-external-storage-with-gke-bd9af17434e5
- https://arslan.io/2018/06/21/how-to-write-a-container-storage-interface-csi-plugin/
