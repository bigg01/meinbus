# Meinbus

Stationsfahrplan für unsere Famillie :oncoming_bus: :tram:

# screeenshot

![example](images/example1.png)


# build

make docker-build
```bash
cd deployment
kubectl create  -f .

kubectl get all
NAME                                      READY   STATUS    RESTARTS   AGE
pod/meinbus-deployment-5d4ccbfb67-l5c8d   1/1     Running   0          14m
pod/meinbus-deployment-5d4ccbfb67-qx2rx   1/1     Running   0          14m

NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/meinbus   ClusterIP   10.43.181.230   <none>        5000/TCP   14m

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/meinbus-deployment   2/2     2            2           14m

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/meinbus-deployment-5d4ccbfb67   2         2         2       14m
```

https://realfavicongenerator.net/