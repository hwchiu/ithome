[Day15] CNI - Flannel IP 管理問題
================================

> 本文同步刊登於 [hwchiu.com - CNI - Flannel - IP管理](https://www.hwchiu.com/cni-flannel-ii.html)

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

前篇文章我們探討了 **flannel** 的安裝過程，包含了相關的 **RBAC/PSP** 安全性設定，放置相關設定檔案的 **ConfigMap** 以及最後運行整個運算邏輯的 **DaemonSet**。

接下來本篇文章將來探討 **flannel** 是怎麼處理 **IP**分配的問題。


# 環境建置
為了搭建一個擁有三個節點的 kubernetes cluster，我認為直接使用 **kubernetes-dind-cluster** 是個滿不錯的選擇，可以快速搭建環境，又有多節點。

或是也可以土法煉鋼繼續使用 **kubeadm** 的方式創建多節點的 kubernetes cluster， 這部分並沒有特別規定，總之能搭建起來即可。

此外相關的版本資訊方面
- kubernetes version:v1.15.4
- flannel: 使用[官方安裝 Yaml](https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml)
- kubeadm 安裝過程使用的參數 **--pod-network-cidr=10.244.0.0/16**

# Kubeadm

所有使用 **kubeadm** 安裝過 **flannel** 都遇過需要設定 **--pod-network-cidr** 的情況，但是到底這個參數背後做了什麼，以及為什麼 **flannel** 會需要這個參數? 接下來就來研究一下

## Workflow

直接先講結論，從結論講起再來講流程會比較清楚。
1. **kubernetes** 會針對每個 **node** 去標示一個名為 **PodCIDR** 的值，代表該 **Node** 可以使用的網段是什麼，
2. **flannel** 的 Pod 會去讀取該資訊，並且將該資訊寫道 **/run/flannel/subnet.env** 的這個檔案中
3. **flannel CNI** 收到任何創建 **Pod** 的請求時，會去讀取 **/run/flannel/subnet.env** 的資訊，並且將其內容轉換最後呼叫 **host-local** 這隻 **IPAM CNI**，來取得可以用的 **IP** 並且設定到 **POD** 身上

相關檔案驗證
```bash=
$ kubectl describe nodes | grep PodCIDR
PodCIDR:                     10.244.0.0/24
PodCIDR:                     10.244.1.0/24
PodCIDR:                     10.244.2.0/24

$ sudo cat /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true

$ sudo ls /var/lib/cni/networks/cbr0
10.244.0.2  10.244.0.3  10.244.0.8  last_reserved_ip.0  lock

$ sudo cat /var/lib/cni/networks/cbr0/10.244.0.8
2d39d5afb81e56314a7fd6bdd57c9ccf6d02c32b556273cfb6b9bb8a248c851b

$ sudo docker ps  --no-trunc | grep $(sudo cat /var/lib/cni/networks/cbr0/10.244.0.8)
2d39d5afb81e56314a7fd6bdd57c9ccf6d02c32b556273cfb6b9bb8a248c851b   k8s.gcr.io/pause:3.1 "/pause" Up 4 hours  k8s_POD_k8s-udpserver-6576555bcb-7h8jh_default_87196597-ccda-4643-ac5d-85343a3b6c90_0
```

先根據上面的指令解釋一下每個的含義，接下來再來研究其流程
1. 透過 **kubectl describer node** 可以觀察到每個節點上都有一個 **PodCIDR** 的欄位，代表的是該節點可以使用的網段
2. 由於我的節點是對應到的 **PodCIDR** 是 **10.244.0.0/24**，接下來去觀察  **/run/flannel/subnet.env**，確認裡面的數值一致。
3. 接下來由於我的系統上有跑過一些 **Pod**，這些 **Pod** 形成的過程中會呼叫 **flannel CNI** 來處理，而該 **CNI** 最後會再輾轉呼叫 **host-loacl IPAM CNI** 來處理，所以就會在這邊看到有 **host-local** 的產物
4. 由於前篇介紹 **IPAM** 的文章有介紹過 **host-local** 的運作，該檔案的內容則是對應的 **CONTAINER_ID**，因此這邊得到的也是 **CONTAINER_ID**
5. 最後則是透過 **docker** 指令去尋該 **CONTAINER_ID**，最後就看到對應到的不是真正運行的 **Pod**，而是先前介紹過的 **Infrastructure Contaienr: Pause**

接下來就是細談上述的流程
## kubeadm 

首先是 **kubeadm** 與 **controller-manager** 兩者的關係，當我們透過 **--pod-network-cide** 去初始化 **kubeadm** 後，其創造出來的 **controller-manager** 就會自帶三個參數

```bash=
root     20459  0.8  2.4 217504 100076 ?       Ssl  05:22   0:36 kube-controller-manager 
--authentication-kubeconfig=/etc/kubernetes/controller-manager.conf 
--authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
--bind-address=127.0.0.1 
--client-ca-file=/etc/kubernetes/pki/ca.crt 
--cluster-cidr=10.244.0.0/16 
--node-cidr-mask-size=24 
--allocate-node-cidrs=true 
--cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt 
--cluster-signing-key-file=/etc/kubernetes/pki/ca.key 
--controllers=*,bootstrapsigner,tokencleaner 
--kubeconfig=/etc/kubernetes/controller-manager.conf 
--leader-elect=true 
--requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt 
--root-ca-file=/etc/kubernetes/pki/ca.crt 
--service-account-private-key-file=/etc/kubernetes/pki/sa.key 
--use-service-account-credentials=true
```

裡面的參數過多，直接挑出重點就是
- --cluster-cidr=10.244.0.0/16
- --allocate-node-cidrs=true
- --node-cidr-mask-size=24

這邊就標明的整個 **cluster network** 會使用的網段，除了 **cidr** 大網段之外還透過 **node-cide--mask** 去標示寫網段，所以根據上述的範例，這個節點的數量不能超過255台節點，不然就沒有⻊夠的 **可用網段**去分配了。

此外很有趣的一點是，這邊的運作邏輯再 **controller-managfer** 內被稱為 **nodeipam**，也就是今天 **kubernetes** 自己跳下來幫忙做 **IPAM** 的工作，幫忙分配 **IP/Subnet**，只是單位是以 **Node** 為基準，不是以 **Pod**。 

根據 [GitHub Controoler](https://github.com/kubernetes/kubernetes/blob/103e926604de6f79161b78af3e792d0ed282bc06/pkg/controller/nodeipam/ipam/controller_legacyprovider.go#L65) 可以看到當 **Controller Manager** 物件被創造的時候會根據上述的參數去產生一個名為 **cidrset** 的物件

```golang=
....
set, err := cidrset.NewCIDRSet(clusterCIDR, nodeCIDRMaskSize)
if err != nil {
    return nil, err
}
...
```
    
而 [CIDRSet](https://github.com/kubernetes/kubernetes/blob/a3ccea9d8743f2ff82e41b6c2af6dc2c41dc7b10/pkg/controller/nodeipam/ipam/cidrset/cidr_set.go#L31) 的結構如下

```golang=
type CidrSet struct {
	sync.Mutex
	clusterCIDR     *net.IPNet
	clusterIP       net.IP
	clusterMaskSize int
	maxCIDRs        int
	nextCandidate   int
	used            big.Int
	subNetMaskSize  int
}
```

基本上就是定義了 **subnet** 相關的所有變數，接下來裡面有一個函式叫做 **allocateRange**，顧名思義就是要出一塊可以用的網段

[](https://github.com/kubernetes/kubernetes/blob/a3ccea9d8743f2ff82e41b6c2af6dc2c41dc7b10/pkg/controller/nodeipam/ipam/sync/sync.go#L314)
```golang=
func (op *updateOp) allocateRange(ctx context.Context, sync *NodeSync, node *v1.Node) error {
	if sync.mode != SyncFromCluster {
		sync.kubeAPI.EmitNodeWarningEvent(node.Name, InvalidModeEvent,
			"Cannot allocate CIDRs in mode %q", sync.mode)
		return fmt.Errorf("controller cannot allocate CIDRS in mode %q", sync.mode)
	}

	cidrRange, err := sync.set.AllocateNext()
	if err != nil {
		return err
	}
	// If addAlias returns a hard error, cidrRange will be leaked as there
	// is no durable record of the range. The missing space will be
	// recovered on the next restart of the controller.
	if err := sync.cloudAlias.AddAlias(ctx, node.Name, cidrRange); err != nil {
		klog.Errorf("Could not add alias %v for node %q: %v", cidrRange, node.Name, err)
		return err
	}

	if err := sync.kubeAPI.UpdateNodePodCIDR(ctx, node, cidrRange); err != nil {
		klog.Errorf("Could not update node %q PodCIDR to %v: %v", node.Name, cidrRange, err)
		return err
	}

	if err := sync.kubeAPI.UpdateNodeNetworkUnavailable(node.Name, false); err != nil {
		klog.Errorf("Could not update node NetworkUnavailable status to false: %v", err)
		return err
	}

	klog.V(2).Infof("Allocated PodCIDR %v for node %q", cidrRange, node.Name)

	return nil
}
```

裡面最重要的就是呼叫 **UpdateNodePodCIDR** 這個函式來進行最後的更新

根據其[原始碼](https://github.com/kubernetes/kubernetes/blob/103e926604de6f79161b78af3e792d0ed282bc06/pkg/controller/nodeipam/ipam/adapter.go#L94)
```golang=
func (a *adapter) UpdateNodePodCIDR(ctx context.Context, node *v1.Node, cidrRange *net.IPNet) error {
	patch := map[string]interface{}{
		"apiVersion": node.APIVersion,
		"kind":       node.Kind,
		"metadata":   map[string]interface{}{"name": node.Name},
		"spec":       map[string]interface{}{"podCIDR": cidrRange.String()},
	}
	bytes, err := json.Marshal(patch)
	if err != nil {
		return err
	}

	_, err = a.k8s.CoreV1().Nodes().Patch(node.Name, types.StrategicMergePatchType, bytes)
	return err
}
```

可以看到最後會在 **spec**下面產生一個名稱為 **podCIDR** 的內容，且其數值就是分配後的網段(cidrRange.String())。

這部分可以透過 **kubectl get nodes xxxx -o yaml** 來驗證

```bash=
$ kubectl get nodes k8s-dev -o yaml
apiVersion: v1
kind: Node
metadata:
  annotations:
    flannel.alpha.coreos.com/backend-data: '{"VtepMAC":"3e:94:52:9b:7e:d9"}'
    flannel.alpha.coreos.com/backend-type: vxlan
    flannel.alpha.coreos.com/kube-subnet-manager: "true"
    flannel.alpha.coreos.com/public-ip: 10.0.2.15
    kubeadm.alpha.kubernetes.io/cri-socket: /var/run/dockershim.sock
    node.alpha.kubernetes.io/ttl: "0"
    volumes.kubernetes.io/controller-managed-attach-detach: "true"
  creationTimestamp: "2019-09-23T05:21:46Z"
  labels:
    beta.kubernetes.io/arch: amd64
    beta.kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    kubernetes.io/hostname: k8s-dev
    kubernetes.io/os: linux
    node-role.kubernetes.io/master: ""
  name: k8s-dev
  resourceVersion: "57899"
  selfLink: /api/v1/nodes/k8s-dev
  uid: cd8fadc0-e58c-4509-9056-3a06bdb8440f
spec:
  podCIDR: 10.244.0.0/24
...
```

## Pod Flannel

鏡頭一轉，我們來看當 **flannel** 部署的 **Pod** 運行起來後會做什麼事情。
前文有提過，預設的安裝設定檔案中會使得 **flannel** 使用 **kubernetes API** 來存取資訊，這同時也意味其 **subnet manager** 會使用 **kubernetes API** 來完成，這部分的程式碼都在[這](https://github.com/coreos/flannel/tree/master/subnet/kube)

其中要特別注意的一個函式[AcquireLease](https://github.com/coreos/flannel/blob/master/subnet/kube/kube.go#L222)
可以看到裡面嘗試針對 **node** 底下的 **sped.PodCIDR** 去存取，並且透過 **enet.ParseCIDR** 的方式去解讀。

```golang=
...
	if n.Spec.PodCIDR == "" {
		return nil, fmt.Errorf("node %q pod cidr not assigned", ksm.nodeName)
	}
	bd, err := attrs.BackendData.MarshalJSON()
	if err != nil {
		return nil, err
	}
	_, cidr, err := net.ParseCIDR(n.Spec.PodCIDR)
	if err != nil {
		return nil, err
	}
...
```


接下來於主要的 **main.go** 這邊會在呼叫 **WriteSubnetFile** 把相關的結果寫到檔案內，最後大家就可以到 **/run/flannel/subnet.env** 去得到相關資訊。

```golang=
func WriteSubnetFile(path string, nw ip.IP4Net, ipMasq bool, bn backend.Network) error {
	dir, name := filepath.Split(path)
	os.MkdirAll(dir, 0755)

	tempFile := filepath.Join(dir, "."+name)
	f, err := os.Create(tempFile)
	if err != nil {
		return err
	}

	// Write out the first usable IP by incrementing
	// sn.IP by one
	sn := bn.Lease().Subnet
	sn.IP += 1

	fmt.Fprintf(f, "FLANNEL_NETWORK=%s\n", nw)
	fmt.Fprintf(f, "FLANNEL_SUBNET=%s\n", sn)
	fmt.Fprintf(f, "FLANNEL_MTU=%d\n", bn.MTU())
	_, err = fmt.Fprintf(f, "FLANNEL_IPMASQ=%v\n", ipMasq)
	f.Close()
	if err != nil {
		return err
	}

	// rename(2) the temporary file to the desired location so that it becomes
	// atomically visible with the contents
	return os.Rename(tempFile, path)
	//TODO - is this safe? What if it's not on the same FS?
}
```

## CNI Flannel

話題一轉，我們來看最後一個步驟，當 **CRI** 決定創建 **POD** 並且準備好相關環參數呼叫 **CNI** 後的運作。

這邊要額外提醒， **flannel** 的程式碼分兩的地方存放
1. [CoreOS - Pod](https://github.com/coreos/flannel)
2. [ContainetNetworking - CNI](https://github.com/containernetworking/plugins/tree/master/plugins/meta/flannel)

同時這也可以解釋為什麼一開始安裝好 **kubernetes** 後，系統內就有 **flannel CNI** 的執行檔案了，因為被放在官方的 **repo** 裡面。

我們先來看創建 **POD** 的時候 **Flannel CNI** 會做的[事情](https://github.com/containernetworking/plugins/blob/master/plugins/meta/flannel/flannel.go#L186-L216)

```golang=
const (
	defaultSubnetFile = "/run/flannel/subnet.env"
	defaultDataDir    = "/var/lib/cni/flannel"
)
...
func cmdAdd(args *skel.CmdArgs) error {
	n, err := loadFlannelNetConf(args.StdinData)
	if err != nil {
		return err
	}

	fenv, err := loadFlannelSubnetEnv(n.SubnetFile)
	if err != nil {
		return err
	}

	if n.Delegate == nil {
		n.Delegate = make(map[string]interface{})
	} else {
		if hasKey(n.Delegate, "type") && !isString(n.Delegate["type"]) {
			return fmt.Errorf("'delegate' dictionary, if present, must have (string) 'type' field")
		}
		if hasKey(n.Delegate, "name") {
			return fmt.Errorf("'delegate' dictionary must not have 'name' field, it'll be set by flannel")
		}
		if hasKey(n.Delegate, "ipam") {
			return fmt.Errorf("'delegate' dictionary must not have 'ipam' field, it'll be set by flannel")
		}
	}

	if n.RuntimeConfig != nil {
		n.Delegate["runtimeConfig"] = n.RuntimeConfig
	}

	return doCmdAdd(args, n, fenv)
}
```

有個常見且習慣的名稱 **cmdAdd**，裡面可以看到呼叫了 **loadFlannelSubnetEnv**，其中若使用者沒有特別設定的話，預設的 **SubnetFile** 就是 **defaultSubnetFile**，如上面示，其值為 **/run/flannel/subnet.env**。

接者該[函式](https://github.com/containernetworking/plugins/blob/master/plugins/meta/flannel/flannel.go#L186-L216)
```bash=
func loadFlannelSubnetEnv(fn string) (*subnetEnv, error) {
	f, err := os.Open(fn)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	se := &subnetEnv{}

	s := bufio.NewScanner(f)
	for s.Scan() {
		parts := strings.SplitN(s.Text(), "=", 2)
		switch parts[0] {
		case "FLANNEL_NETWORK":
			_, se.nw, err = net.ParseCIDR(parts[1])
			if err != nil {
				return nil, err
			}

		case "FLANNEL_SUBNET":
			_, se.sn, err = net.ParseCIDR(parts[1])
			if err != nil {
				return nil, err
			}

		case "FLANNEL_MTU":
			mtu, err := strconv.ParseUint(parts[1], 10, 32)
			if err != nil {
				return nil, err
			}
			se.mtu = new(uint)
			*se.mtu = uint(mtu)

		case "FLANNEL_IPMASQ":
			ipmasq := parts[1] == "true"
			se.ipmasq = &ipmasq
		}
	}
	if err := s.Err(); err != nil {
		return nil, err
	}

	if m := se.missing(); m != "" {
		return nil, fmt.Errorf("%v is missing %v", fn, m)
	}

	return se, nil
}
```
就會去讀取該檔案，並且整理成一個 **subnetEnv** 的物件格式，一切都處理完畢後，就會透過 **CNI** 內建的函式去呼叫其他的 **CNI** 來處理


可以再[doCmdAdd](https://github.com/containernetworking/plugins/blob/master/plugins/meta/flannel/flannel_linux.go#L31) 這個函式看到最後塞了一個 **ipam** 的字典資訊進去，然後裡面設定了 **host-local** 會用到的所有參數。
```golang=
func doCmdAdd(args *skel.CmdArgs, n *NetConf, fenv *subnetEnv) error {
	n.Delegate["name"] = n.Name

	if !hasKey(n.Delegate, "type") {
		n.Delegate["type"] = "bridge"
	}

	if !hasKey(n.Delegate, "ipMasq") {
		// if flannel is not doing ipmasq, we should
		ipmasq := !*fenv.ipmasq
		n.Delegate["ipMasq"] = ipmasq
	}

	if !hasKey(n.Delegate, "mtu") {
		mtu := fenv.mtu
		n.Delegate["mtu"] = mtu
	}

	if n.Delegate["type"].(string) == "bridge" {
		if !hasKey(n.Delegate, "isGateway") {
			n.Delegate["isGateway"] = true
		}
	}
	if n.CNIVersion != "" {
		n.Delegate["cniVersion"] = n.CNIVersion
	}

	n.Delegate["ipam"] = map[string]interface{}{
		"type":   "host-local",
		"subnet": fenv.sn.String(),
		"routes": []types.Route{
			{
				Dst: *fenv.nw,
			},
		},
	}

	return delegateAdd(args.ContainerID, n.DataDir, n.Delegate)
}
```

這個檔案其實也無形透露了， **flannel** 最後其實是產生一個使用 **bridge** 作為主體 **CNI** 且 **IPAM** 使用 **host-local** 的設定檔案。
這也是我之前所說的這些由官方維護的基本功能解決方案，不論是基於提供網路功能的，或是 **IPAM** 相關的套件都會給受到其他的套件反覆使用而組合出更強大的功能。

一旦當 **host-local** 處理結束後，就會再 **/var/run/cni/cbr0/networks** 看到一系列由 **host-local** 所維護的正在使用 IP 清單。

# Summary

**flannel** 本身並不處理 **Linux Bridge** 的設定以及 **IPAM** 相關的設定，反而是透過更上層的辦法去處理設定檔案的問題，確保每一台機器上面 **host-local** 看到的網段都不同，而 **host-local** 則專注於對每個網段都能夠不停的產生出唯一不被使用的 **IP** 地址。

這種分工合作的辦法也是現在軟體開發與整合的模式，隨者效能與功能愈來愈強大，很難有一個軟體可以涵括所有領域的功能，適度的合作與整合才有辦法打造出更好的解決方案。

本篇我們大概理解了 **flannel** 是如何處理 **IP** 分配的問題，透過 **kubernetes nodeIPAM** 的設計，以及 **CNI Host-local IPAM** 的處理來完成。

最後使用下圖來作為一個總結

![](https://i.imgur.com/HHKDtsL.png)

# 參考
- https://github.com/coreos/flannel/blob/443d773037ac0f3b8a996a6de018b903b6a58c62/Documentation/kubernetes.md
- https://github.com/coreos/flannel

