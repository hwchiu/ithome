[Day24] Device Plugin - Implementation
======================================

> 本文同步刊登於 [hwchiu.com - Device Plugin 實作](https://www.hwchiu.com/k8s-device-plugin-implement.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- Device Plugin


有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

前篇文章已經探討了 **device plugin** 的設計理念以及基本使用流程，而本篇文章會比較以技術性的角度來探討這個框架，與此同時也可以看看這個框架的使用方式與前述的 **CRI/CNI/CSI** 這些標準的介面有何不同。

前述提到過 **device plugin** 會透過 **unix socket** 與 **kubelet** 進行溝通，而實際上這個溝通的部分也是透過 **gRPC + protobuf** 描述的介面來進行溝通，因此官方針對 **device plugin** 的框架有定義了一系列的介面，每個解決方案都要滿足這些介面才可以順利地與 **kubelet** 溝通，最後順利的於 kubernetes 內運作。 

再探討 **device plugin** 前，必須要先針對版本有所共識，目前的 **device plugin** 本身的介面有兩個版本，分別是
1. [v1alpha](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/apis/deviceplugin/v1alpha/api.proto)
2. [v1beta1](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/apis/deviceplugin/v1beta1/api.proto)

本文探討的主要基於 **v1beta1** 的版本來探討。

# 架構


要實現一個基於 **device plugin** 框架的解決方案非常簡單，就是實現一個滿足介面需求的 **gRPC** 服務器，介面非常簡單，只有四個函式需要實現而已，如下

```go=
service DevicePlugin {
	// GetDevicePluginOptions returns options to be communicated with Device
        // Manager
	rpc GetDevicePluginOptions(Empty) returns (DevicePluginOptions) {}

	// ListAndWatch returns a stream of List of Devices
	// Whenever a Device state change or a Device disappears, ListAndWatch
	// returns the new list
	rpc ListAndWatch(Empty) returns (stream ListAndWatchResponse) {}

	// Allocate is called during container creation so that the Device
	// Plugin can run device specific operations and instruct Kubelet
	// of the steps to make the Device available in the container
	rpc Allocate(AllocateRequest) returns (AllocateResponse) {}

        // PreStartContainer is called, if indicated by Device Plugin during registeration phase,
        // before each container start. Device plugin can run device specific operations
        // such as reseting the device before making devices available to the container
	rpc PreStartContainer(PreStartContainerRequest) returns (PreStartContainerResponse) {}
}
```

## GetDevicePluginOptions
這個功能滿簡單的，就是回傳一些關於本 **device plugin** 的一些能力，目前定義的能力非常少，只有一個，就是需不需要容器啟動前呼叫的掛勾點 (pre-start-hook)

```go=
message DevicePluginOptions {
        // Indicates if PreStartContainer call is required before each container start
	bool pre_start_required = 1;
}

```

## ListAndWatch
該函式有兩個目的
1. 讓 **kubelet** 去得知該 devices 的特性以及發現到有多少個 **devices**
2. 由 **device plugin** 主動通知 **kubelet** 任何關於 **device** 狀態的改變

## Alloocate
**kubelet** 再創建 **Pod/Container** 前會呼叫該函式來處理如何使得該 **device** 可以被容器掛載使用


滿足這個介面的應用程式可透過下列其中之一方式部署到節點上
1. kubenetes Pod
2. 實機部署

接者透過註冊相關的函示主動通知 **kubelet** 需要註冊一個全新的 **device plugin**，完成這個步驟之後，接下來 **kubelet** 就會開始透過上述的兩個 **gRPC** 介面與解決方案互動

整個過程可以用下圖來解釋
![](https://i.imgur.com/94xAHmh.png)
上圖節錄自[Device Plugin Device Manager Proposal
](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/resource-management/device-plugin.md#device-manager-proposal)

首先一開始，當 **device plugin** 安裝完畢之後，會呼叫 **Register** 這個函式，而這個函式最重要的是背後必須要透過 **gRPC** 的方式與 **kubelet** 溝通，將本解決方案的相關資訊都告知 **kubelet**，所以可以注意到這邊是單線進行。

一但 **kubetlet** 接收到註冊之後，接下來就會開始根據需求進行 **ListWatch** 以及 **Alloacte** 兩個的呼叫，這邊可以特別注意到的是 **ListWatch** 本身是雙向互動的，意味者兩邊都會根據需求互相呼叫對方的函式。而 **Allocate** 就是單一方向的。

本圖片雖然來自官方文件，但是右下方的 **Unload Drivers During Pre-Stop Hook** 
只是早期設計時的發想，畢竟是 **Proposal**，實際上這個點反而很難做，譬如 **Container crash** 算不算 **pre-stop**?
因此不如透過 **pre-start** 的方ㄕ確保每個 **container** 啟動前都可以呼叫的方式去 **reset** 相關資源。


## PreStartContainer
如果前述的 **GetDevicePluginOptions** 有描述有這個需求的話，那這個函式就會再有任何 **Pod** 要被創造前被呼叫，可以用來進行重設 **device** 確保下個 **Pod** 是用到新的。


# 註冊

為了能夠實現註冊功能， **device plugin** 一但創立的時候就必須要有能力跟 **kubelet** 溝通，並且通過 **gRPC** 的方式去呼叫註冊的函式。

而目前這個方式都會透過 **unix socket**  的方式來滿足，正巧的是 **kubelet** 就有配置一個門用來溝通的 **unix socket**，預設情況下都在 **/var/lib/kubelet/device-plugins/kubelet.sock**。
也因為這個原因，任何安裝 **device-plugin** 的 **yaml** 檔案內都會看到下列的設定

```yaml=
...
        volumeMounts:
          - name: device-plugin
            mountPath: /var/lib/kubelet/device-plugins
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
...
```

一旦這條路通上之後， **device plugin** 就需要準備一個基於 **RegisterRequest** 格式的內容去進行註冊，而該格式內包含了幾個重要資訊

1. version
當前使用的版本基本上可以使用函式庫內的變數即可
3. endpoint
後續進行 **ListAndWatch**, **Allocate** 等相關操作使用的 **Unix-Socket**。
4. resoruce_name
預註冊的 **device** 名稱，其有規範，通常是 vendor-name/device-name
5. DevicePluginOptions
當前的 device plugin 有哪些額外參數要設定，目前只有是否需要 **pre-start-hook** 的選項

一旦註冊成功，之後 **kubelet** 就會使用 **endpoint** 中描述的 **UNIX Socket** 來與 **device plugin** 進行溝通。


```go=
message RegisterRequest {
	// Version of the API the Device Plugin was built against
	string version = 1;
	// Name of the unix socket the device plugin is listening on
	// PATH = path.Join(DevicePluginPath, endpoint)
	string endpoint = 2;
	// Schedulable resource name. As of now it's expected to be a DNS Label
	string resource_name = 3;
        // Options to be communicated with Device Manager
        DevicePluginOptions options = 4;
}
```

這意味者一個有效的 **device plugin** 會透過兩個不同的 **UNIX socket** 來與 **kubelet** 溝通，一個是固定位置，專門用來註冊的，另外一個則是每個 **device plugin** 自行設定的位置，只要 **kubelet** 能夠存取即可。


# Allocate

接下來探討一下最重要的 **Allocate** 的函式，主要是要對這個函式有點大概的瞭解，則接下來去看任何的 **device plugin** 解決方案都會更容易理解其實作邏輯。

首先我們知道，使用者可以於 **Pod** 中去要求**整數數量**的 **device**，當這些需求最後被 **kubelet** 轉換為實際需求送到 **device plugin gRPC** 服務器時，就會變成一個以陣列型態表示的 **deviceID**。

**device plugin** 本身依據這些流水號的 **id** 去分配對應的 **device** 資源，而分配的方式與內容都會於其回傳封包 ** AllocateResponse** 中設定。

```go=
// - Allocate is expected to be called during pod creation since allocation
//   failures for any container would result in pod startup failure.
// - Allocate allows kubelet to exposes additional artifacts in a pod's
//   environment as directed by the plugin.
// - Allocate allows Device Plugin to run device specific operations on
//   the Devices requested
message AllocateRequest {
	repeated ContainerAllocateRequest container_requests = 1;
}

message ContainerAllocateRequest {
	repeated string devicesIDs = 1;
}
```

往下探討之前，先來複習一點東西，就是所謂的 **device** 到底跟容器可以怎麼用?
以 **docker** 為範例，常常使用 **volume** 會知道可以透過 **-v** 的方式標明來源與目的的映射關係，想要複雜一點的設定可以採用 **--mount** 來處理。
然而對於 **device** 來說，也有對應的指令，就是 **--device**

可以參考 Docker [官網範例](https://docs.docker.com/engine/reference/commandline/run/#add-host-device-to-container---device)

```bash=
$ docker run --device=/dev/sdc:/dev/xvdc \
             --device=/dev/sdd --device=/dev/zero:/dev/nulo \
             -i -t \
             ubuntu ls -l /dev/{xvdc,sdd,nulo}

brw-rw---- 1 root disk 8, 2 Feb  9 16:05 /dev/xvdc
brw-rw---- 1 root disk 8, 3 Feb  9 16:05 /dev/sdd
crw-rw-rw- 1 root root 1, 5 Feb  9 16:05 /dev/nulo
```

由上述可以看到其使用方式與 **volume(mount)** 相似，都是透過路徑的方式來處理。
有了這個概念，接下來就可以看一下 **Allocate** 這個函式的回傳值 **AllocateResponse** 的格式。

首先 **Request** 可以要求多個 **device**，所以 **Response** 本身的回傳也會是一個陣列，而每個陣列都是一個基於 **ContainerAllocateResponse** 的格式。

該格式使用了四個欄位來輔助，分別是
1. envs
2. mounts
3. devices
4. annotations


```go=
// AllocateResponse includes the artifacts that needs to be injected into
// a container for accessing 'deviceIDs' that were mentioned as part of
// 'AllocateRequest'.
// Failure Handling:
// if Kubelet sends an allocation request for dev1 and dev2.
// Allocation on dev1 succeeds but allocation on dev2 fails.
// The Device plugin should send a ListAndWatch update and fail the
// Allocation request
message AllocateResponse {
	repeated ContainerAllocateResponse container_responses = 1;
}

message ContainerAllocateResponse {
  	// List of environment variable to be set in the container to access one of more devices.
	map<string, string> envs = 1;
	// Mounts for the container.
	repeated Mount mounts = 2;
	// Devices for the container.
	repeated DeviceSpec devices = 3;
	// Container annotations to pass to the container runtime
	map<string, string> annotations = 4;
}

```

其中最重要的就是 **mounts** 以及 **devics**，其格式如下，可以看到格式非常類似，也非常清楚
1. host_path
2. container_path
3. read_only/permissions

其中前面兩個資訊是不是與我們前述的 **docekr** 範例非常相似？
透過用路徑的方式去表達欲掛載到目標容器內的 **volume** 或是 **devices** 

所以回傳的格式可能如下
```json=
"devics":[
            {
                container_path: "/dev/sda1",
                host_path: "/dev/sda1",
                permissoin: "rwm"
            },
            {
                container_path: "/dev/sda2",
                host_path: "/dev/sda2",
                permissoin: "rwm"
            },
            {
                container_path: "/dev/sda3",
                host_path: "/dev/sda3",
                permissoin: "rwm"
            },
    ]
```


```go=
// Mount specifies a host volume to mount into a container.
// where device library or tools are installed on host and container
message Mount {
	// Path of the mount within the container.
	string container_path = 1;
	// Path of the mount on the host.
	string host_path = 2;
	// If set, the mount is read-only.
	bool read_only = 3;
}

// DeviceSpec specifies a host device to mount into a container.
message DeviceSpec {
    // Path of the device within the container.
    string container_path = 1;
    // Path of the device on the host.
    string host_path = 2;
    // Cgroups permissions of the device, candidates are one or more of
    // * r - allows container to read from the specified device.
    // * w - allows container to write to the specified device.
    // * m - allows container to create device files that do not yet exist.
    string permissions = 3;
}
```


看到這邊對於 **Allocate** 已經有一個基本的概念了，對於 **device plugin** 的解決方案來說，根據需求去配置需要的 **device**，如果有需要也可以準備相關的 **volume**，最後一起將這些路徑回傳回去，這樣對應的 **Pod** 再啟動的時候就會透過類似 **docekr --device xxx --mount** 的方式把這些資訊都掛載到容器內使用。

# Summary
本文透過實際探索 **device plugin** 框架的面貌來學習其解決方案會怎麼設計，相對於 **CRI/CNI/CSI**， 整個 **device plugin** 的內容非常簡單，只有少少四個介面需要設計，也因為如此的設計能夠讓第三方解決方案的人員，專心致力於 **device** 的處理與開發，就可以很順利的銜接到 **kubernetes** 叢集運算中。


# 參考
- https://github.com/kubernetes/community/blob/master/contributors/design-proposals/resource-management/device-plugin.md#device-manager-proposal
- https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/apis/deviceplugin/v1beta1/api.proto
