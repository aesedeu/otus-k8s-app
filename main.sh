# ===== I часть =====


# Запуск FastAPI
python app.py

# Проверка ответа
curl -v -X POST "http://localhost:80/rec" -H "Content-Type: application/json" -d '{"Age": 30, "Sex": 1, "BloodPressure": 150, "MaxHeartRate": 160}'  
curl -X POST "http://localhost:80/rec" -H "Content-Type: application/json" -d '{"Age": 30, "Sex": 1, "BloodPressure": 150, "MaxHeartRate": 160}'  

# Сборка модели v1
cd build/app_v1 && docker build --tag aesedeu/otus_k8s_app:1.0 --file Dockerfile . && cd ../../
docker run --name model_v1 -p 80:80 -d aesedeu/otus_k8s_app:1.0
docker push aesedeu/otus_k8s_app:1.0

# Сборка модели v2
cd build/app_v2 && docker build --tag aesedeu/otus_k8s_app:2.0 --file Dockerfile . && cd ../../
docker run --name model_v2 -p 80:80 -d aesedeu/otus_k8s_app:2.0
docker push aesedeu/otus_k8s_app:2.0

# Запуск k8s
minikube start --vm-driver=docker --cpus=4 --memory=4G --nodes=2

# 1 - ConfigMap
kubectl apply -f k8s/1_ConfigMap/configmap.yaml
kubectl delete configmap welcome-configmap

# 2 - Pod
kubectl apply -f k8s/2_Pod/pod.yaml
kubectl delete pod otus-app-v1

# 3 - Service
kubectl apply -f k8s/3_Service/service.yaml
kubectl port-forward svc/otus-app-service -n default 80:80 # не будет балансировать нагрузку
kubectl delete service otus-app-service

# 4 - Deployment
kubectl apply -f k8s/4_Deployment/deployment.yaml
# Просмотр инфо о подах
kubectl get pods --output=wide 

# 5 - Ubuntu
kubectl apply -f k8s/5_Ubuntu_pod/ubuntu.yaml
# Проваливаемся вовнутрь пода с убунтой
kubectl exec -it ubuntu-pod bash
uname -a
apt-get update
apt-get install curl
# Дергаем ручку у конкретного пода. Необходимо указать актуальный ip пода внутри кластера
curl -X POST "http://10.244.1.5:80/rec" -H "Content-Type: application/json" -d '{"Age": 30, "Sex": 1, "BloodPressure": 150, "MaxHeartRate": 160}'
# Дергаем ручки у сервиса и видим Round-Robin
curl -X POST "http://otus-app-service:80/rec" -H "Content-Type: application/json" -d '{"Age": 30, "Sex": 1, "BloodPressure": 150, "MaxHeartRate": 160}'
# Циклом 30 раз
for i in {1..30};
do curl -X POST "http://otus-app-service:80/rec" -H "Content-Type: application/json" -d '{"Age": 30, "Sex": 1, "BloodPressure": 150, "MaxHeartRate": 160}';
done
exit


# ===== II часть =====


# Устанавливаем ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.4/manifests/install.yaml
# Ждем около 2-х минут. Проверяем чтобы все контейнеры были активны
# Получаем пароль для входа в арго
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# ЗАПУСК: выполняем проброс портов. ArgoCD будет доступен на localhost:8080
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Декларативное создание приложения
kubectl apply -f application.yaml

# Можно выставить порт сервиса наружу (не будет балансировать нагрузку)
kubectl port-forward svc/otus-app-service -n default 80:80

# Можно менять версию приложения в файле values.yaml
# Проваливаемся вовнутрь пода с убунтой
kubectl exec -it ubuntu-pod bash
uname -a
apt-get update
apt-get install curl
# Дергаем ручку у конкретного пода. Необходимо указать актуальный ip пода внутри кластера
curl -X POST "http://10.244.1.5:80/rec" -H "Content-Type: application/json" -d '{"Age": 30, "Sex": 1, "BloodPressure": 150, "MaxHeartRate": 160}'
# Дергаем ручки у сервиса и видим Round-Robin
curl -v -X POST "http://otus-app-service:80/rec" -H "Content-Type: application/json" -d '{"Age": 30, "Sex": 1, "BloodPressure": 150, "MaxHeartRate": 160}'
exit

# История обновлений
# Можно откатиться через интерфейс ArgoCD в разделе "History and Rollback"

# Ингресс
minikube addons enable ingress
minikube ip
kubectl apply -f ingress.yaml
sudo vim /etc/hosts

# Проброс для БД
kubectl port-forward svc/postgres-app -n default 5432:5432