[Day21] Container Storage Interface(CSI) - NFS 初體驗
====================================================

> 本文同步刊登於 [hwchiu.com - CSI NFS 初體驗](https://www.hwchiu.com/csi-nfs.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- Container Storage Interface
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

本文會透過使用 **CSI** 的方式於 kubernetes 內使用 NFS 作為儲存解決方案，並且嘗試觀察各種與  CSI 有關的概念與架構，嘗試將實際部署的結果與前篇文章探討的架構與文件結合。

# NFS

先前我有寫過一篇關於 **NFS** 各種用法的文章，有興趣的人可以前往閱讀 [NFS 於 Kubernetes 內的各種應用
](https://www.hwchiu.com/kubernetes-storage-ii.html)
在該篇文章裡面我描述了兩種 **NFS** 的用法，第一種就是最基本的架設一個 **NFS** 服務器，接者將其分享出來的空間直接掛載到欲使用的 **Pod**，這種情況下就是 **NFS**服務器上面有什麼樣的資源與檔案，則 **Pod** 裡面看到的也就是相同的資源。這種用法也是最常見的使用方法。

而第二種方法則是希望採用 **StorageClass** 的方式來使用 **NFS** 伺服器，這種情況下就是 **NFS**服務器本身也是會分享一個空間，但是每次透過 **StorageClass** 以及 **PVC** 綁定的情況下，會在 **NFS** 分享的資料夾內在創建一個資料夾，專屬給該 **PVC** 去使用，使用起來的感覺就像是動態分割空間一樣，這部分過去是仰賴額外的 **NFS Provisioner** 來實現。

而本文要討論的架構屬於第一種，所以到時候掛載的 **Pod** 內部觀看到的資料就會與 **NFS** 本身分享的資料一致。

# 環境建置

本文環境基於
1. kubernetes: 1.15.3
2. CSI: 1.0.0
3. NFS CSI Driver: https://github.com/hwchiu/csi-driver-nfs
從官方 fork 過來，但是稍微調整了一下 nfs 掛載的位置以及相關的 image tag

上述的環境已經整理成一個 **Vagrant** 的檔案

```ruby=
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-18.04"
  config.vm.hostname = 'k8s-dev'
  config.vm.define vm_name = 'k8s'

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -e -x -u
    export DEBIAN_FRONTEND=noninteractive

    #change the source.list
    sudo apt-get update
    sudo apt-get install -y vim git cmake build-essential tcpdump tig jq
    # Install ntp
    sudo apt-get install -y ntp
    # Install Docker
    # kubernetes official max validated version: 17.03.2~ce-0~ubuntu-xenial
    export DOCKER_VERSION="18.06.3~ce~3-0~ubuntu"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce=${DOCKER_VERSION}
    
    # Install Kubernetes
    export KUBE_VERSION="1.15.3"
    export NET_IF_NAME="enp0s8"
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee --append /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubeadm=${KUBE_VERSION}-00 kubelet=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00 kubernetes-cni=0.7.5-00
    # Disable swap
    sudo swapoff -a && sudo sysctl -w vm.swappiness=0
    sudo sed '/swap.img/d' -i /etc/fstab
    sudo kubeadm init --kubernetes-version v${KUBE_VERSION} --apiserver-advertise-address=172.17.8.101 --pod-network-cidr=10.244.0.0/16
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml
    kubectl taint nodes --all node-role.kubernetes.io/master-

    sudo apt-get install -qqy nfs-kernel-server
    sudo mkdir /nfsshare
    sudo mkdir /nfsshare/mongodb
    sudo mkdir /nfsshare/influxdb
    sudo mkdir /nfsshare/user
    echo "/nfsshare *(rw,sync,no_root_squash)" | sudo tee /etc/exports
    sudo exportfs -r
    sudo showmount -e

    git clone https://github.com/hwchiu/csi-driver-nfs.git
    kubectl apply -f csi-driver-nfs/deploy/kubernetes/
    kubectl apply -f csi-driver-nfs/examples/kubernetes/nginx.yaml
  SHELL

  config.vm.network :private_network, ip: "172.17.8.101"
  config.vm.provider :virtualbox do |v|
      v.customize ["modifyvm", :id, "--cpus", 2]
      v.customize ["modifyvm", :id, "--memory", 4096]
      v.customize ['modifyvm', :id, '--nicpromisc1', 'allow-all']
  end
end
```

該檔案會自動架設一個基於 **1.15.3** 的 **kubernetes cluster**，同時也會自動安裝 **NFS** 伺服器，並且將其底下的 **/nfsshare** 資料夾分享出去。

此外也會自動部署 **NFS CSI** 解決方案的相關檔案，並且最後部署一個使用該 **NFS** 服務的 **nginx** 作為一個範例。

如果遇到下列錯誤，就進到機器後重新創建一次 **nginx** 相關的檔案即可
```bash=
k8s: Error from server (Forbidden): error when creating "csi-driver-nfs/examples/kubernetes/nginx.yaml": pods "nginx" is forbidden: error looking up service account default/default: serviceaccount "default" not found
####
$ kubectl apply -f csi-driver-nfs/examples/kubernetes/nginx.yaml 
```

## 安裝內容

接下來我們來看一下剛剛安裝的過程到底裝了哪些資源到系統中，這邊我們就忽略其他資源，專注於跟儲存有關的資源上

### Controller

首先我們先看一下所謂的 **CSI** Controller  相關的設定檔案，如之前所述，這種情況通常會使用 **StatefulSet** 來設定，除非你的 **Controller** 本身有額外實現多實例的架構，可確保同時只有會一個副本正在運行。

```bash=
kind: StatefulSet
apiVersion: apps/v1beta1
metadata:
  name: csi-attacher-nfsplugin
spec:
  serviceName: "csi-attacher"
  replicas: 1
  template:
    metadata:
      labels:
        app: csi-attacher-nfsplugin
    spec:
      serviceAccount: csi-attacher
      containers:
        - name: csi-attacher
          image: quay.io/k8scsi/csi-attacher:v1.0.1
          args:
            - "--v=5"
            - "--csi-address=$(ADDRESS)"
          env:
            - name: ADDRESS
              value: /csi/csi.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi

        - name: nfs
          image: quay.io/k8scsi/nfsplugin:canary
          args :
            - "--nodeid=$(NODE_ID)"
            - "--endpoint=$(CSI_ENDPOINT)"
          env:
            - name: NODE_ID
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: CSI_ENDPOINT
              value: unix://plugin/csi.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /plugin
      volumes:
        - name: socket-dir
          emptyDir:
```

該 **Pod** 中運行了兩個 **Container**，分別是
1. quay.io/k8scsi/nfsplugin:canary
2. quay.io/k8scsi/csi-attacher:v1.0.1

第一個則是關於基於 **NFS** 所實現相容於 **CSI Controller** 的解決方案，而第二個則是由官方推出便於發開者的 **sidecar container**，用來監聽相關的 kubernetes 事件並且透過 **gRPC** 的方式告知第一個容器。

這邊同時可以觀察到
1. 系統上透過 **emptyDir** 的方式創建了一個空間，並且讓兩個 **container** 都共同使用，而該檔案則是其實背後就是創建出來的 **unix://plugin/csi.sock**， 因此這兩個 **container** 就會透過這種方式來進行 IPC 的交談。

### Node


接下來觀察一下另外一個部署，使用 **DaemonSet** 來部署，對應的就是之前提到的 **CSI Node** 服務，是必須每台需要使用儲存方案的節點都要部署的。

```yaml=
kind: DaemonSet
apiVersion: apps/v1beta2
metadata:
  name: csi-nodeplugin-nfsplugin
spec:
  selector:
    matchLabels:
      app: csi-nodeplugin-nfsplugin
  template:
    metadata:
      labels:
        app: csi-nodeplugin-nfsplugin
    spec:
      serviceAccount: csi-nodeplugin
      hostNetwork: true
      containers:
        - name: node-driver-registrar
          image: quay.io/k8scsi/csi-node-driver-registrar:v1.0.2
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "rm -rf /registration/csi-nfsplugin /registration/csi-nfsplugin-reg.sock"]
          args:
            - --v=5
            - --csi-address=/plugin/csi.sock
            - --kubelet-registration-path=/var/lib/kubelet/plugins/csi-nfsplugin/csi.sock
          env:
            - name: KUBE_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          volumeMounts:
            - name: plugin-dir
              mountPath: /plugin
            - name: registration-dir
              mountPath: /registration
        - name: nfs
          securityContext:
            privileged: true
            capabilities:
              add: ["SYS_ADMIN"]
            allowPrivilegeEscalation: true
          image: quay.io/k8scsi/nfsplugin:canary
          args :
            - "--nodeid=$(NODE_ID)"
            - "--endpoint=$(CSI_ENDPOINT)"
          env:
            - name: NODE_ID
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
                - name:  
            - name: CSI_ENDPOINT
              value: unix://plugin/csi.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: plugin-dir
              mountPath: /plugin
            - name: pods-mount-dir
              mountPath: /var/lib/kubelet/pods
              mountPropagation: "Bidirectional"
      volumes:
        - name: plugin-dir
          hostPath:
            path: /var/lib/kubelet/plugins/csi-nfsplugin
            type: DirectoryOrCreate
        - name: pods-mount-dir
          hostPath:
            path: /var/lib/kubelet/pods
            type: Directory
        - hostPath:
            path: /var/lib/kubelet/plugins_registry
            type: Directory
          name: registration-dir
```

該 **Pod** 中也是部署了兩個 **Container**，分別是
1. quay.io/k8scsi/csi-node-driver-registrar:v1.0.2
2. quay.io/k8scsi/nfsplugin:canary

跟 **Controller** 的部署一樣，其中一個是自行解決方案的設計，另外一個則是官方提供的好用輔助容器。

首先看一下**Volume** 的部分，這邊有三個資料夾並且都是透過 **hostpath** 的方式來使用
1. /var/lib/kubelet/plugins/csi-nfsplugin
2. /var/lib/kubelet/pods
3. /var/lib/kubelet/plugins_registry

第一個 **/var/lib/kubelet/plugins/csi-nfsplugin** 根據觀察可以發現最後其實是用來指定相關的 **unix socket**。

```bash=
vagrant@k8s-dev:~$ sudo ls /var/lib/kubelet/plugins/csi-nfsplugin
csi.sock

vagrant@k8s-dev:~$ sudo file /var/lib/kubelet/plugins/csi-nfsplugin/csi.sock
/var/lib/kubelet/plugins/csi-nfsplugin/csi.sock: socket
```

第二個 **/var/lib/kubelet/pods** 比較特別，這個資料夾是 **kubelet** 用來存放跟 **pod** 相關的資訊，其中該目錄底下都是基於 **pod ID** 來區隔的。

```bash=
vagrant@k8s-dev:~$ sudo ls /var/lib/kubelet/pods/
16010371-22a4-4152-af23-712def2a764d  7a5a5fa4-ea62-4106-8e2e-69f3a0abf48d  8bf65cf7-a02a-4829-9fab-784355fe5ba5  af50052304877bc1d4cd4d3409c6be5a      c3aedceb2d751faeb02f85ebcec869a6      db52b7d4-c828-49d8-b899-e52be600f0b5
28f76958a7cfb29c8091821d6746ddea      7d5d3c0a6786e517a8973fa06754cb75      9f7d3f8c-63a8-46b9-8d69-d70656caf0b7  bd4f816d-01f0-4217-a66c-27bd4893c130  c9da1474-797c-4386-acb1-f7c74cc30dbd

vagrant@k8s-dev:~$ sudo docker ps | grep nginx
2107ec8d04e1        maersk/nginx                               "nginx"                  10 hours ago        Up 10 hours                             k8s_nginx_nginx_default_8bf65cf7-a02a-4829-9fab-784355fe5ba5_0
dad41423889e        k8s.gcr.io/pause:3.1                       "/pause"                 10 hours ago        Up 10 hours                             k8s_POD_nginx_default_8bf65cf7-a02a-4829-9fab-784355fe5ba5_0

vagrant@k8s-dev:~$ sudo ls /var/lib/kubelet/pods/8bf65cf7-a02a-4829-9fab-784355fe5ba5
containers  etc-hosts  plugins  volumes
vagrant@k8s-dev:~$
```

可以看到基於測試的 **nginx pod** 底下有個 volumes 的資料夾，接下來往下去看裡面有什麼資訊

```bash=
vagrant@k8s-dev:~$ sudo tree /var/lib/kubelet/pods/8bf65cf7-a02a-4829-9fab-784355fe5ba5/volumes
/var/lib/kubelet/pods/8bf65cf7-a02a-4829-9fab-784355fe5ba5/volumes
├── kubernetes.io~csi
│ └── data-nfsplugin
|     ├── mount
│     │ ├── influxdb
│     │ ├── mongodb
│     │ ├── test1
│     │ └── user
│     └── vol_data.json
└── kubernetes.io~secret
    └── default-token-6bcvc
        ├── ca.crt -> ..data/ca.crt
        ├── namespace -> ..data/namespace
        └── token -> ..data/token

vagrant@k8s-dev:~$ sudo cat /var/lib/kubelet/pods/8bf65cf7-a02a-4829-9fab-784355fe5ba5/volumes//kubernetes.io~csi/data-nfsplugin/vol_data.json | jq
{
  "attachmentID": "csi-f642ae48557f63a1f4377a265c43d6afe2e8d859837925fef2331b9e541e31a3",
  "driverMode": "persistent",
  "driverName": "csi-nfsplugin",
  "nodeName": "k8s-dev",
  "specVolID": "data-nfsplugin",
  "volumeHandle": "data-id"
}
```

同時也可以看到上述的 **mount**  資料夾內有之前設定的 **NFS** 相關的分享資料夾內容，這部分引起我的好奇心，所以透過 **mount** 再次觀察。
```bash=
vagrant@k8s-dev:~$ mount | grep nfsshare
127.0.0.1:/nfsshare on /var/lib/kubelet/pods/8bf65cf7-a02a-4829-9fab-784355fe5ba5/volumes/kubernetes.io~csi/data-nfsplugin/mount type nfs4 (rw,relatime,vers=4.1,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=127.0.0.1,local_lock=none,addr=127.0.0.1)
```
大概可以瞭解整個運作原理了，先透過 **CSI** 的方式把目標的解決方案掛載到相關節點上，而掛載的地點必須是 **/var/lib/kubelet/pods/${pod_id}/volumes/kubernetes.io~csi/${csi_name}** 這個位置，當這邊處理完畢後。一旦 **Pod** 開始啟用後，就會透過 **mount namespace** 的方式再度的把這個空間給掛載到 **Pod** 裡面去使用。


最後的 **/var/lib/kubelet/plugins_registry** 看名稱就跟註冊有關，的確也是專門給 **Register** 這個額外的容器使用。
根據該[專案說明](https://github.com/kubernetes-csi/node-driver-registrar)

>Registration socket:
Registers the driver with kubelet.
Created by the node-driver-registrar.
Exposed on a Kubernetes node via hostpath in the Kubelet plugin registry. (typically /var/lib/kubelet/plugins_registry/<drivername.example.com>-reg.sock). The hostpath volume must be mounted at /registration.

所以可以看到這算是一個該容器的標準用法，如果要將該CSI解決方案註冊到 **Node** 上，就直接透過這個容器加上 **Unix socket** 與 **kubelet** 溝通，就算是完成註冊相關的功能了。

```bash=
vagrant@k8s-dev:~$ sudo ls /var/lib/kubelet/plugins_registry
csi-nfsplugin-reg.sock
vagrant@k8s-dev:~$ sudo file /var/lib/kubelet/plugins_registry/csi-nfsplugin-reg.sock
/var/lib/kubelet/plugins_registry/csi-nfsplugin-reg.sock: socket
```


根據官方提供的參考部署架構圖
![](https://i.imgur.com/sx31Z1w.png)
該圖節錄自[Recommended Mechanism for Deploying CSI Drivers on Kubernetes
](kubernetes.io/blog/2019/01/15/container-storage-interface-ga/)

可以對應到上述所描述的部署方式以及相關的 **volume** 操作，同時對於整體的運作邏輯有更清晰的表達。

### Nginx

作為一個使用者 **Pod** 來說，這邊採用 **PV/PVC** 這種預先配置的方式來使用前述部署完畢的 **CSI** 環境，其中只有 **PV** 的部分使用方式跟過往不同，剩下的 **PVC/Pod** 都沒有任何變化。

可以看到 **PV** 之中必須要採用 **csi** 的架構，並且透過 **volumeAttrivutes** 傳遞每個解決方案需要的參數過去，以 **NFS** 為範例，就是目標伺服器的 **IP** 地址以及欲分享的資料夾。

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
      share: /nfsshare
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


## 觀察
環境都架設完畢之後，第一步先觀察 **NFS** 是否如預期般的運作

```bash=
vagrant@k8s-dev:~$ kubectl exec nginx ls /var/www
influxdb
mongodb
user

vagrant@k8s-dev:~$ ls /nfsshare/
influxdb  mongodb  user

vagrant@k8s-dev:~$ sudo touch /nfsshare/test1

vagrant@k8s-dev:~$ kubectl exec nginx ls /var/www
influxdb
mongodb
test1
user
```

看起來非常順利，基本的 **NFS** 掛載已經成功，接下來我們就要來觀察基於 **CSI** 的環境有什麼不同

```bash=
vagrant@k8s-dev:~$ kubectl api-resources | grep -i storage
csidrivers                                     storage.k8s.io                 false        CSIDriver
csinodes                                       storage.k8s.io                 false        CSINode
storageclasses                    sc           storage.k8s.io                 false        StorageClass
volumeattachments                              storage.k8s.io                 false        VolumeAttachment
```

我們透過 **kubectl api-resources** 去觀察系統上目前有哪些跟 **storage** 有關的資源，發現除了過往的 **storageclasses** 之外，還多出了三個資源，分別是 **csidrivers**, **csinodes** 以及 **volumeattachmenets**。

### CSIDriver
非常不幸的，我們的範例中並沒有創建任何資源於這個物件類別下
```bash
vagrant@k8s-dev:~$ kubectl get csidrivers
No resources found.
```
根據[官方開發指南](https://kubernetes-csi.github.io/docs/csi-driver-object.html)，裡面對於 **CSIDriver** 的描述是

>The CSIDriver Kubernetes API object serves two purposes:
Simplify driver discovery
If a CSI driver creates a CSIDriver object, Kubernetes users can easily discover the CSI Drivers installed on their cluster (simply by issuing kubectl get CSIDriver)
Customizing Kubernetes behavior
Kubernetes has a default set of behaviors when dealing with CSI Drivers (for example, it calls the Attach/Detach operations by default). This object 
>allows CSI drivers to specify how Kubernetes should interact with it.

簡單來說這個資源不一定會有，主要取決於 **CSI** 解決方案有沒有要創建，創建的話提供兩個好處
1. 使用者更容易的觀察到系統上安裝了哪些 **CSI** 解決方案
我認為這滿方便的，但是能夠強制要求創建該物件就更棒了
2. 讓 **CSI**解決方案能夠有機會對 **kubelet** 進行控制，去管理整個 **CSI** 的運作邏輯。

一個合法的內容可能如下
```yaml=
apiVersion: storage.k8s.io/v1beta1
kind: CSIDriver
metadata:
  name: mycsidriver.example.com
spec:
  attachRequired: true
  podInfoOnMount: true
  volumeLifecycleModes: # added in Kubernetes 1.16
  - Persistent
  - Ephemeral
```

其中 **volumeLifycecleModes** 甚至是 **kubernetes 1.16** 所加入的，有興趣的可以自行參閱[開發指南](https://kubernetes-csi.github.io/docs/csi-driver-object.html#what-fields-does-the-csidriver-object-have) 去瞭解每個欄位的定義。


### CSINodes

透過 **kubectl describe** 我們可以看到更多關於 **CSINodes** 的資料。
```bash=
vagrant@k8s-dev:~$ kubectl get csinodes
NAME      CREATED AT
k8s-dev   2019-09-29T07:19:27Z
vagrant@k8s-dev:~$ kubectl describe csinodes k8s-dev
Name:         k8s-dev
Namespace:
Labels:       <none>
Annotations:  <none>
API Version:  storage.k8s.io/v1beta1
Kind:         CSINode
Metadata:
  Creation Timestamp:  2019-09-29T07:19:27Z
  Owner References:
    API Version:     v1
    Kind:            Node
    Name:            k8s-dev
    UID:             8ed067fe-dbe7-4297-8177-c8a9da227962
  Resource Version:  540
  Self Link:         /apis/storage.k8s.io/v1beta1/csinodes/k8s-dev
  UID:               1fd550dd-194a-4f20-8d41-fd1f42fbe16a
Spec:
  Drivers:
    Name:           csi-nfsplugin
    Node ID:        k8s-dev
    Topology Keys:  <nil>
Events:             <none>
```

其中最重要的就是 **spec.drivers** 內的資料，包含了
1. 該解決方案的名稱，定義於該解決方案內的程式碼。
2. 該節點的名稱，因為 **CSI** 裡面有很多的介面都會需要 **NodeID** 來進行一些處理，特別是 **Controller** 端的介面。

根據 [官方開發指南](https://kubernetes-csi.github.io/docs/csi-node-object.html#what-is-the-csinode-object) 內的描述， CSINode 有下列的事項要注意

1. **CSI** 解決方案本身不需要自行創造，只要透過上篇介紹過的開發小幫手 - sidecar containers 中的 **node-device-register** 就會自動創造該物件
2. 該物件創立的目的是希望提供下列資訊
    - 將 kubernetes node 的名稱轉換至 CSI node name
    - 透過相關物件判斷特定節點上是否有註冊相關的 CSI 解決方案

### VolumeAttachments
這個物件是用來描述 **CSI** 使用過程中去掛載 **Volume** 的相關資訊。
```bash=
vagrant@k8s-dev:~$ kubectl get volumeattachments
NAME                                                                   ATTACHER        PV               NODE      ATTACHED   AGE
csi-f642ae48557f63a1f4377a265c43d6afe2e8d859837925fef2331b9e541e31a3   csi-nfsplugin   data-nfsplugin   k8s-dev   true       20m
vagrant@k8s-dev:~$ kubectl describe volumeattachments
Name:         csi-f642ae48557f63a1f4377a265c43d6afe2e8d859837925fef2331b9e541e31a3
Namespace:
Labels:       <none>
Annotations:  <none>
API Version:  storage.k8s.io/v1
Kind:         VolumeAttachment
Metadata:
  Creation Timestamp:  2019-09-29T07:19:49Z
  Resource Version:    577
  Self Link:           /apis/storage.k8s.io/v1/volumeattachments/csi-f642ae48557f63a1f4377a265c43d6afe2e8d859837925fef2331b9e541e31a3
  UID:                 991d3c32-0d4f-43e8-bcdc-c5a5d038cd38
Spec:
  Attacher:   csi-nfsplugin
  Node Name:  k8s-dev
  Source:
    Persistent Volume Name:  data-nfsplugin
Status:
  Attached:  true
Events:      <none>
```

譬如從 **spec** 可以看到有一個掛載的行為是
1. 透過 Attacher **csi-nfsplugin** 於 node **k8s-dev** 上掛載一個 **volume**，而該 **volume** 的來源是名為 **data-nfsplugin** 的 **PVC** 所定義的。
 
這些資訊都可以幫忙釐清與確認當前是否 **CSI** 的儲存功能有正常運作，我覺得相對於之前單純的 **PV/PVC** 有來得清楚一些。

# Summary

本文基於 **CSI** 架構下部署了一個 **NFS** 的儲存方案，並且用一個 **Pod** 作為掛載的範例，來實際部署的流程與架構，同時觀察整個 kubernetes 本身是否有新增加的資源與內容。


# 參考
- https://github.com/kubernetes-csi/csi-driver-nfs
- https://kubernetes-csi.github.io/docs
- https://github.com/kubernetes-csi/node-driver-registrar
- kubernetes.io/blog/2019/01/15/container-storage-interface-ga/
