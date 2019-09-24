[Day14] CNI - Flannel 安裝與設定原理
==================================

> 本文同步刊登於 [hwchiu.com - CNI - Flannel - 安裝設定篇](https://www.hwchiu.com/cni-flannel-i.html)

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

藉由前面四篇文章，我們對於 **CNI** 已經有了一些基本個概念，包含了
1. CNI 的標準規範以及使用範例
2. CNI 與 kubernetes 的整合與設定
3. 透過實際操作開發一個基於 Linux Bridge 的 CNI，並且知道如何透過設定檔與之互動
4. 研究三個官方維護的 IPAM 解決方案，理解 IP 分配的問題以及可能的解決辦法

接下來我們將實戰進行分析，直接對大家最常用也是最知名的 **CNI** 之一， **flannel**


# 環境建置
為了搭建一個擁有三個節點的 kubernetes cluster，我認為直接使用 **kubernetes-dind-cluster** 是個滿不錯的選擇，可以快速搭建環境，又有多節點。

或是也可以土法煉鋼繼續使用 **kubeadm** 的方式創建多節點的 kubernetes cluster， 這部分並沒有特別規定，總之能搭建起來即可。

此外相關的版本資訊方面
- kubernetes version:v1.15.4
- flannel: 使用[官方安裝 Yaml](https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml)
- kubeadm 安裝過程使用的參數 **--pod-network-cidr=10.244.0.0/16**

# 目標

基於前述的觀察，針對 flaennl 這套 CNI 解決方案，我想要觀察並討論的重點有
1. 理解 [官方安裝 Yaml](https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml) 實際上安裝了什麼元件到 kubernetes cluster 中，同時這些元件又各自扮演什麼角色
2. flannel 使用的 CNI config 有什麼特色以及用到什麼功能
3. IP 管理的問題 flannel 是怎麼解決的
4. flannel 是如何提供網路能力，單一 Pod 是如何存取外網的
5. 跨節點的 Pod 是如何互相存取彼此的

## 安裝過程理解
官方的 [安裝yaml](https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml) 非常的長，這裡面包含了六種 kubernetes 的資源，分別如下。
- PodSecurityPolicy
- ClusterRole
- ClusterRoleBinding
- ServiceAccount
- ConfigMap
- DaemonSet

雖然這邊有六個資源，但是基於使用類別來看，我個人認為其實就是分成兩大類別，前面四個類別是相互依賴一起運作的，目的就是創造一個可控管且權利被限制的 **kubernetes service account**，而後面兩個則算是整個邏輯處理的核心，所有上述的問題都在這兩個資源內處理。

### PodSecurityPolicy
用來限制每個被創造 **Pod** 的定義，一旦 **Pod** 本身資源的定義沒有滿足 **PodSecurityPolicy** 的規範，該 **Pod** 就不會被拒絕建立。

這些規範與限制都是希望能夠加強 **Pod** 本身的安全性，基於沒有用到的部分就不要打開，針對有需求的部分才去使用。

這個功能目前預設沒有開啟，若要開啟的話需要對 **admission controller** 設定參數，同時要注意的是一但開啟這個功能，但是卻沒有任何相關的 **PodSecuirtyPolicy** 設定的話，預設情況下所有的 **Pod** 都不能被創造，算是一個白名單的機制
>Pod security policy control is implemented as an optional (but recommended) admission controller. PodSecurityPolicies are enforced by enabling the admission controller, but doing so without authorizing any policies will prevent any pods from being created in the cluster.
>


此功能沒有辦法單獨使用，需要搭配 Service Account 一併使用，所以接下來的 RBAC 等都是串連再一起使用的。

對於 **flannel** 來說，其規範了下列安全設定來確保其創建的 **Pod** 的能力是被限制的
1. privileged
2. volumes 
3. allowedHostPaths
這邊可以看到一個跟 **cni** 相關的地址，代表 **flannel** 的 **pod** 勢必會對該資料夾進行一些手腳
4. Users/Groups
5. Capabilities
這邊特別允許了只能給 **NET_ADMIN** 這個選項，這個意味 **flannel** 會想要針對 **Pod** 上的網路部分做些設定，這些設定跟其網路連接有很大的關係。
6. Host namespaces
之前 **CNI** 章節忘了提到的就是所謂的 **hostnetwork** 的設定，如果 **pod** 裡面有設定 **hostnetwork:true** 就意味該 **pod** 所屬的 **infrastructure container: Pause** 其實不會創建新的 **network namespace**，而是會跟 **host** 也就是 **kubernetes node** 共用相同的網路空間。
這個功能相對危險，只要該 **Pod** 也有其他的能力，譬如 **NET_ADMIN**，其實該 **Pod** 是有能力摧毀整個 **kubernetes cluster** 的連線能力的，譬如亂修改 **route table**, **ip address** 等

更多關於這個資源的介紹可以參考 [PodSecurityPolicy](https://kubernetes.io/docs/concepts/policy/pod-security-policy/)。

```json=
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: psp.flannel.unprivileged
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: docker/default
    seccomp.security.alpha.kubernetes.io/defaultProfileName: docker/default
    apparmor.security.beta.kubernetes.io/allowedProfileNames: runtime/default
    apparmor.security.beta.kubernetes.io/defaultProfileName: runtime/default
spec:
  privileged: false
  volumes:
    - configMap
    - secret
    - emptyDir
    - hostPath
  allowedHostPaths:
    - pathPrefix: "/etc/cni/net.d"
    - pathPrefix: "/etc/kube-flannel"
    - pathPrefix: "/run/flannel"
  readOnlyRootFilesystem: false
  # Users and groups
  runAsUser:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  # Privilege Escalation
  allowPrivilegeEscalation: false
  defaultAllowPrivilegeEscalation: false
  # Capabilities
  allowedCapabilities: ['NET_ADMIN']
  defaultAddCapabilities: []
  requiredDropCapabilities: []
  # Host namespaces
  hostPID: false
  hostIPC: false
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  # SELinux
  seLinux:
    # SELinux is unsed in CaaSP
    rule: 'RunAsAny'
---
```

這邊定義了 **ClusterRole** 的資源，其中會透過 **use** 這個動作與上述的 **PodSecurityPolicy** 給綁定，此外也可以看到其他相關的能力，譬如
1. 對 pod 的取得
2. 對 node 本身要可以 list 以及 watch
3. 對 nodes/status 執行 patch

有 **Patch** 就可以期待 **flannel** 會對 **node** 本身添加什麼樣的資訊，之後會再討論。
### ClusterRole
```json=
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: flannel
rules:
  - apiGroups: ['extensions']
    resources: ['podsecuritypolicies']
    verbs: ['use']
    resourceNames: ['psp.flannel.unprivileged']
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - get
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - nodes/status
    verbs:
      - patch
```


### ClusterRoleBinding/Service Account

最後就是透過 **Service Account** 以及 **ClusterRoleBinding** 這兩個資源將上述的資源全部整合起來，創造出一個名為 **flannel**  的 **service account**。 

可以預期之後看到 **daemonset** 的時候會使用這個 **service account** 來作為創建的使用者。

```json=
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-system
----
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-system
```


```bash=
$ kubectl -n kube-system get sa,clusterrole,clusterrolebinding,psp | grep flannel
serviceaccount/flannel                              1         14h
clusterrole.rbac.authorization.k8s.io/flannel                                                                14h
clusterrolebinding.rbac.authorization.k8s.io/flannel                                                14h
podsecuritypolicy.extensions/psp.flannel.unprivileged   false   NET_ADMIN   RunAsAny   RunAsAny    RunAsAny   RunAsAny   false            configMap,secret,emptyDir,hostPath
```

### ConfigMap

下一個要研究的資源就是牽扯到檔案的 **configmap**， **flannel** 這邊設定了兩個檔案，分別是 **cni-conf.json** 以及 **net-conf.json**。

```json=
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cfg
  namespace: kube-system
  labels:
    tier: node
    app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
```

**cni-conf** 如其名稱，就是給 **CNI** 使用的設定檔案，我們可以觀察到其使用了 **plugins** 的關鍵字，其格式則是 **Network Configuration List**，而裡面包含了兩個 **CNI**，分別是 **flannel** 以及 **portmap**。

#### Portmap CNI
**portmap** 這個 **CNI** 則是[官方維護](https://github.com/containernetworking/plugins/tree/master/plugins/meta/portmap)的，其功能是類似提供 **docker -p host_port:container_port** 的功用，能夠幫忙在 **host** 也提供一個路口幫忙轉發封包到 **container** 裡面。 基本上我覺得有使用 **kubernetes service** 的話就不需要這個功能了。

若要開啟這個功能除了 **CNI** 有要支援之外，也必須要在 **pod** 裡面去描述 **hostPort**，這樣 **CRI** 創建的時候就會把這些資訊包裝起來一併傳給 **CNI** 去處理。

以下是一個範例，創建該資源後可以在有部署該 **Pod** 的節點上發現一些由 **CNI** 創建的 **iptables** 規則，這種情況下可以達到類似 **NodePort** 的效果。


```bash=
$ cat server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-udpserver
spec:
  selector:
    matchLabels:
      run: k8s-udpserver
  replicas: 6
  template:
    metadata:
      labels:
        run: k8s-udpserver
    spec:
      containers:
      - name: k8s-udpserver
        imagePullPolicy: IfNotPresent
        image: hwchiu/pythontest
        ports:
        - containerPort: 20001
          hostPort: 20001
          protocol: UDP
          
$ sudo iptables-save -t nat | grep 20001
-A CNI-DN-eb9116f984fef9374c9e2 -s 10.244.0.6/32 -p udp -m udp --dport 20001 -j CNI-HOSTPORT-SETMARK
-A CNI-DN-eb9116f984fef9374c9e2 -s 127.0.0.1/32 -p udp -m udp --dport 20001 -j CNI-HOSTPORT-SETMARK
-A CNI-DN-eb9116f984fef9374c9e2 -p udp -m udp --dport 20001 -j DNAT --to-destination 10.244.0.6:20001
-A CNI-HOSTPORT-DNAT -p udp -m comment --comment "dnat name: \"cbr0\" id: \"c55a611c4b8e8a4bef86ac05a3328258a858165b3bf4a3982997f9662bd82916\"" -m mult
iport --dports 20001 -j CNI-DN-eb9116f984fef9374c9e2
vagrant@k8s-dev:~$
```

但是使用這個最大的問題是 **host port** 是獨佔的，所以如果今天 **pod** 的數量超過 **node** 的數量，就會發生很多 **pod** 創建不起來，譬如下圖
```bash=
$ kubectl get pods
NAME                             READY   STATUS    RESTARTS   AGE
k8s-udpserver-5b989865bf-8jlwv   1/1     Running   0          15m
k8s-udpserver-5b989865bf-jmljc   0/1     Pending   0          15m
k8s-udpserver-5b989865bf-l25f4   1/1     Running   0          15m
k8s-udpserver-5b989865bf-ps2wx   1/1     Running   0          15m
k8s-udpserver-5b989865bf-t9glv   0/1     Pending   0          15m
k8s-udpserver-5b989865bf-zvw6r   0/1     Pending   0          15m

$ kubectl describe pod k8s-udpserver-5b989865bf-jmljc
...
Events:
  Type     Reason            Age                 From               Message
  ----     ------            ----                ----               -------
  Warning  FailedScheduling  74s (x16 over 15m)  default-scheduler  0/3 nodes are available: 3 node(s) didn't have free ports for the requested pod ports.
```

**CNI**這邊除了 **portmapping** 之外還有各式各樣的組合，譬如可以限速的 **bandwidth**，調整 **MAC** 地址的，一時之間難以講完，就有遇到再來分享吧

除了 **CNI** 設定外，另外一個檔案 **net-conf.json** 則是給 **flannel** 程式使用的設定檔案。
這邊會設定 **flannel** 的相關資訊，特別要注意的是如果使用的是 **kubeadm** 來安裝 **kubernetes** 的話，要確認 **net-conf.json** 裡面關於 **network** 的資訊需要與 **kubeadm --init --pod-network-cidr=xxxx** 一致。

如果沒有使用 **kubeadm** 的話，該參數則會被用來分配 **ip** 地址給所有的 **Pod**。

根據[官方文件](https://github.com/coreos/flannel/blob/443d773037ac0f3b8a996a6de018b903b6a58c62/Documentation/kubernetes.md)
> A ConfigMap containing both a CNI configuration and a flannel configuration. The network in the flannel configuration should match the pod network CIDR. The choice of backend is also made here and defaults to VXLAN.

## DaemonSet

接下來就要來看最大的重點 **DaemonSet**，首先 **flannel** 準備了非常多的 **daemonset** 檔案，分別針對不同的系統架構，譬如 **amd64**, **arm**, **ppc** 之類的，由於內容大同小異，差別於 **node selector**  而已，因此這邊我們就針對 **amd64** 這個範例來看


### Configuration
前述文章都有探討到， **CNI** 本身是一個以節點為單位的設定檔案，每個節點都需要一份獨立的設定檔案，這意味者所有新加入的節點也都要有該設定檔案，不單純只是現在有的節點需要維護而已。
這個情況下最常用的方式就是透過 **daemonset** 的方式，讓每一台機器上都跑一個特定的 **Pod**，該 **Pod** 會透過
1. configmap 的方式安裝相關設定檔案到 kubernetes 中
2. 啟動一個 **Pod**，並且將相關資料夾掛載到 **Pod** 裡面
3. 透過 **cp** 的方式將檔案安裝到各節點中

**flannel** 就是採用這樣的方式，並且把這個動作放到 **init container** 去執行，因為這類型的指令其實不太算是 **daemon**，比較類似 **job**，執行完就結束離開的應用程式，放到 **Container** 這邊則會使得該 **Container** 必須要一直利用 **pause/sleep** 等方式來運作得像一個 **daemon**，反而搞得複雜。

此外也可以觀察到該 **DaemonSet** 有特別指定 **serviceAccountName: flannel**， 算是把上述的資源跟這邊給接起來。更重要的是基於安全性方面的設定完全與上面的 **PodSecutityPolicy** 一致。
```
securityContext:
    privileged: false
    capabilities:
        add: ["NET_ADMIN"]
 ```

```yaml=
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds-amd64
  namespace: kube-system
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      hostNetwork: true
      nodeSelector:
        beta.kubernetes.io/arch: amd64
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni
        image: quay.io/coreos/flannel:v0.11.0-amd64
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: quay.io/coreos/flannel:v0.11.0-amd64
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
             add: ["NET_ADMIN"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      volumes:
        - name: run
          hostPath:
            path: /run/flannel
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: flannel-cfg
          configMap:
            name: kube-flannel-cfg         
```

接下來看看主要的 **Container**，這個 **Container** 是一個額外的應用程式，會幫忙處理 **CNI** 當下不方便處理的事情。

目前官方預設的安裝檔案內只有設定兩個變數，分別是
1. --ip-masq
會透過 `masqueradr` 的功能幫往外送出的封包進行 SNAT，譬如下列這些規則就是 **flannel** 幫忙下的
```bash=
-A POSTROUTING -s 10.244.0.0/16 -d 10.244.0.0/16 -j RETURN
-A POSTROUTING -s 10.244.0.0/16 ! -d 224.0.0.0/4 -j MASQUERADE
-A POSTROUTING ! -s 10.244.0.0/16 -d 10.244.0.0/24 -j RETURN
-A POSTROUTING ! -s 10.244.0.0/16 -d 10.244.0.0/16 -j MASQUERADE
```
2. --kube-subnet-mgr
這個主要是用來告訴 **flannel** 如何處理 **IP Subnet**，目前有兩種模式，如果有特別開啟 **kube-subnet-mgr** 的話就會使用 **kubernetes** API 來處理，同時相關的設定檔案也會從 **net-conf.json** 來讀取，反之就全部都從 **etcd** 來儲存與處理。

此外我們還可以看一下相關的 **Volume** 到底有哪些，除了上述的 **configMap** 之外，我們發現該 **Pod** 也掛載了下列的位置
1. /run/flannel

接下來我們就實際看一下這個位置的檔案

```bash=
$ sudo ls /run/flannel/
subnet.env

$ sudo cat /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true

```

看到跟 **IP** 有關的設定，決定看一下另外幾台機器
```bash=
$ sudo cat /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.2.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
```

可以看到不同機器上面的 **SUBNET** 欄位不同，同時 **Pod** 得到的 **IP** 去觀察
```bash=

$ kubectl get pods -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP           NODE        NOMINATED NODE   READINESS GATES
k8s-udpserver-6576555bcb-7h8jh   1/1     Running   0          13m   10.244.0.8   k8s-dev     <none>           <none>
k8s-udpserver-6576555bcb-c52rk   1/1     Running   0          13m   10.244.1.7   k8s-dev-1   <none>           <none>
k8s-udpserver-6576555bcb-dxm8h   1/1     Running   0          13m   10.244.1.6   k8s-dev-1   <none>           <none>
k8s-udpserver-6576555bcb-f49m4   1/1     Running   0          13m   10.244.2.7   k8s-dev-2   <none>           <none>
k8s-udpserver-6576555bcb-hfhw2   1/1     Running   0          13m   10.244.2.8   k8s-dev-2   <none>           <none>
k8s-udpserver-6576555bcb-hswhn   1/1     Running   0          13m   10.244.2.6   k8s-dev-2   <none>           <none>
```

很巧的是每個 **Node** 上面該檔案的 **SUBNET** 都與運行 **POD** 的 **IP** 網段符合，看起來這個檔案勢必有動了一些手腳。

對於整體 **IP** 分配的過程我們將到下篇文章再來分析

# Summary

本篇文章探討了的 **Flanel** 的安裝過程，從官方提供的 **yaml** 過程中來一一探討每個資源的用途，同時也觀察到了其利用 **DaemonSet** 配上 **init container** 來幫每個節點安裝 **CNI** 以及本身運行的設定檔案，確保未來任何新加入的節點都能夠順利的擁有這些檔案並正常運作。

用下圖幫本章節做個總結
![](https://i.imgur.com/DlbQ55O.png)


- https://github.com/coreos/flannel/blob/443d773037ac0f3b8a996a6de018b903b6a58c62/Documentation/kubernetes.md
- https://github.com/kubernetes/kubernetes
- https://kubernetes.io/docs/concepts/policy/pod-security-policy/
- https://github.com/coreos/flannel/blob/ba49cd4c1e49d566da4a08b370384ce8ced0c0e3/Documentation/troubleshooting.md
