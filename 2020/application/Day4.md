Day 4 - Helm 操作範例
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)https://www.facebook.com/technologynoteniu)



上篇文章中我們介紹了 Helm 的概念，包含了 Helm Chart, Config 以及 Released，而要瞭解這些概念最好的方式就是直接參考一個實際的範例，



首先根據[官方教學](https://helm.sh/docs/intro/install/)，安裝 `Helm` 指令到系統中, 多種安裝方法，擇一即可

```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```



因此我們會使用 `Helm create` 指令創建一個基本的 Helm Chart，並從中瞭解其架構

```bash
$ helm create ithome
$ tree ithome
ithome
├── Chart.yaml
├── charts
├── templates
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml

3 directories, 10 files
```

一個全新產生的 Helm Chart 內總共有 10 個檔案， 3個資料夾

裡面跟 Kubernetes 有關的物件資源有五個，包含 `deployment.yaml, hpa.yaml, ingress.yaml, service.yaml, serviceaccount.yaml`, 這些 Yaml 內容都含有 Go Template 的內容

```bash
$ cat ithome/templates/hpa.yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2beta1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "ithome.fullname" . }}
  labels:
    {{- include "ithome.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "ithome.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
  {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        targetAverageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
  {{- end }}
  {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        targetAverageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
  {{- end }}
{{- end }}
```



此外還可以看到最外面有一個 Values.yaml，裡面就包含各式各樣的變數以及預設值，

```yaml
╰─$ cat values.yaml
# Default values for ithome.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: ""

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # Annotations to add to the service account
  annotations: {}
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: ""

podAnnotations: {}

podSecurityContext: {}
  # fsGroup: 2000

securityContext: {}
  # capabilities:
  #   drop:
  #   - ALL
  # readOnlyRootFilesystem: true
  # runAsNonRoot: true
  # runAsUser: 1000
service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  annotations: {}
    # kubernetes.io/ingress.class: nginx
    # kubernetes.io/tls-acme: "true"
  hosts:
    - host: chart-example.local
      paths: []
  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local

resources: {}
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  # limits:
  #   cpu: 100m
  #   memory: 128Mi
  # requests:
  #   cpu: 100m
  #   memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  # targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}  
```



如果想要安裝這個 Helm Chart 到系統內，依序執行下列指令

1. 創建測試用 namespace
2. 將該 Helm Chart 安裝到系統中的 ithome namespace 並且將該 released 命名為 ithome. 來源 Helm Charts 是當前資料夾 `.`

```bash
$ kubectl create ns ithome                                                                                                                                             namespace/ithome created
$ helm install --namespace ithome ithome .
NAME: ithome
LAST DEPLOYED: Tue Sep  8 21:54:12 2020
NAMESPACE: ithome
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace ithome -l "app.kubernetes.io/name=ithome,app.kubernetes.io/instance=ithome" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace ithome port-forward $POD_NAME 8080:80
$ kubectl -n ithome get all                                                                                                                                            1 ↵
NAME                          READY   STATUS    RESTARTS   AGE
pod/ithome-5cc87ff5f4-xnpvh   1/1     Running   0          36s

NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/ithome   ClusterIP   10.43.95.165   <none>        80/TCP    36s

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ithome   1/1     1            1           36s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/ithome-5cc87ff5f4   1         1         1       36s  
```



再來則是觀看系統上安裝的哪些的 Helm Chart，可以透過 `helm ls` 的方式來觀看，如果有不同的 namespace 都要透過 `-n` 來指定

```bash
$ helm -n ithome ls
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
ithome  ithome          1               2020-09-08 21:54:12.803147 -0700 PDT    deployed        ithome-0.1.0    1.16.0
```



最後是一系列好用的指令，`helm get` 可以取得該 Released 上的各種資料

```bash
$ helm get --help
Usage:
  helm get [command]

Available Commands:
  all         download all information for a named release
  hooks       download all hooks for a named release
  manifest    download the manifest for a named release
  notes       download the notes for a named release
  values      download the values file for a named release
```

最簡單的兩個範例就是 `manifest` 以及 `values`, 透過 `manifest` 我們可以直接觀察到最後安裝到系統內的 YAML 檔案長什麼樣子

譬如

```bash
$ helm -n ithome get manifest ithome
---
# Source: ithome/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ithome
  labels:
    helm.sh/chart: ithome-0.1.0
    app.kubernetes.io/name: ithome
    app.kubernetes.io/instance: ithome
    app.kubernetes.io/version: "1.16.0"
    app.kubernetes.io/managed-by: Helm
---
# Source: ithome/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: ithome
  labels:
    helm.sh/chart: ithome-0.1.0
    app.kubernetes.io/name: ithome
    app.kubernetes.io/instance: ithome
    app.kubernetes.io/version: "1.16.0"
    app.kubernetes.io/managed-by: Helm
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: ithome
    app.kubernetes.io/instance: ithome
---
# Source: ithome/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ithome
  labels:
    helm.sh/chart: ithome-0.1.0
    app.kubernetes.io/name: ithome
    app.kubernetes.io/instance: ithome
    app.kubernetes.io/version: "1.16.0"
    app.kubernetes.io/managed-by: Helm
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ithome
      app.kubernetes.io/instance: ithome
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ithome
        app.kubernetes.io/instance: ithome
    spec:
      serviceAccountName: ithome
      securityContext:
        {}
      containers:
        - name: ithome
          securityContext:
            {}
          image: "nginx:1.16.0"
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /
              port: http
          readinessProbe:
            httpGet:
              path: /
              port: http
          resources:
            {}
```

可以看到這邊就是上述那些充滿 Go Template 格式Yaml渲染後的結果，我們也可以使用 `helm get values` 來看一次目前是否有任何客製化的設定

```bash
helm -n ithome get values ithome
USER-SUPPLIED VALUES:
null
```

根據這個指令我們可以觀察到本次安裝沒有任何客製化的變動，採用的是最原生的 Values.yaml.

因此接下來我們嘗試升級該 Release，並且修改裡面的設定值

```bash
$ helm -n ithome upgrade ithome --set service.type=NodePort .                                                                                                          
Release "ithome" has been upgraded. Happy Helming!
NAME: ithome
LAST DEPLOYED: Tue Sep  8 22:02:49 2020
NAMESPACE: ithome
STATUS: deployed
REVISION: 2
NOTES:
1. Get the application URL by running these commands:
  export NODE_PORT=$(kubectl get --namespace ithome -o jsonpath="{.spec.ports[0].nodePort}" services ithome)
  export NODE_IP=$(kubectl get nodes --namespace ithome -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
```

指令中我們透過 `helm upgrade` 的方式來升級已經存在的 Released `ithome`, 我們透過 `--set service.type=NodePort` 的方式去覆蓋掉 `values.yaml` 裡面的預設數值(這邊也可以直接修改 values.yaml, 或是產生一個全新的 Yaml 然後送給 Helm 指令)。最後我們指令來源 Helm Chart 的位置 `.` (當前目錄)。

可以看到上述指令後來輸出一些部署的資訊，包含該 Relased 是第二個版本，部署的時間，當前狀態，什麼 namespace.

一切完畢之後，我們再度使用 `helm get values` 的指令來看看是否有什麼變化

```bash
$ helm -n ithome get values ithome
USER-SUPPLIED VALUES:
service:
  type: NodePort
$ kubectl -n ithome get svc                                                                                                                                          
NAME     TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
ithome   NodePort   10.43.95.165   <none>        80:30232/TCP   9m20s
```

這時候可以很明確地看到，當前運行的 `ithome released` 有一個客製化的選項，就是我們前述所輸入的 `service.type` ，同時觀察 `kuberctl -n ithome get svc` 也真的看到 service 的內容變成 NodePort.



Helm 可以操作與設定的東西非常多，這邊的設定只是一個非常簡單的範例，實務上有非常多的事情要處理，也有非常多的小麻煩，譬如當你的客製化資訊本身有雙引號或是個 JSON 字串，你的腳本該怎麼處理。 Helm 要如何跟應用程式整理，開發人員跟維護人員誰要負責設計與維護應用程式的 Helm Chart, 基本上都沒有一個完整答案，只要能夠讓你輕鬆上班，簡單部署，達到薪水小偷的境界就是一個好的解決方案。