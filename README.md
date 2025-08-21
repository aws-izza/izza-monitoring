# Kubernetes 모니터링 스택 자동 배포 프로젝트

이 프로젝트는 EKS 클러스터에 `kube-prometheus-stack`을 사용하여 Prometheus, Grafana, Alertmanager를 자동으로 배포하고 설정합니다.

## 주요 기능

- Prometheus, Grafana, Alertmanager 배포
- 커스텀 알림 규칙 및 Slack 연동 설정
- 커스텀 Grafana 대시보드 자동 프로비저닝
- 모든 과정은 `deploy-monitoring.sh` 스크립트로 자동화

## 사전 준비 사항

- `aws-cli`, `kubectl`, `helm`, `eksctl`이 설치되어 있어야 합니다. (스크립트가 자동으로 설치를 시도합니다.)
- EKS 클러스터에 접근할 수 있는 `kubeconfig`가 설정되어 있어야 합니다.
- AWS 자격 증명(Credentials)이 설정되어 있어야 합니다.
예를 들어
export AWS_ACCESS_KEY_ID=<Your_ID>
export AWS_SECRET_ACCESS_KEY=<Your Access Key>
- eks inbound rule에 해당 ec2의 접근권한을 열어야합니다.

## 사용 방법

1.  이 저장소를 클론합니다.
    ```sh
    git clone <your-repository-url>
    cd my-monitoring-project
    ```

2.  Slack Webhook URL을 환경 변수로 설정합니다. (CI/CD 환경에서는 Secret 변수로 설정)
    ```sh
    export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...'
    ```
    만약약, 환경 변수 없이 스크립트를 실행하면 URL을 입력하라는 메시지가 나타납니다.

3.  배포 스크립트를 실행합니다.
    ```sh
    chmod +x deploy-monitoring.sh
    ./deploy-monitoring.sh
    ```

4. eks 삭제시
   ```sh
    helm uninstall izza-prometheus -n metric
   ```

## 파일들
- `prometheus-values.yaml`: Prometheus 및 grafana의 주요 설정을 담고 있습니다. 알림 규칙은 이 파일 안에 정의되어 있습니다.
- 'my-dashoboard.json' : Grafana 대시보드의 json 파일
- 'metric.sh' : 의존성 해결 및 repo등록까지 하는 올인원 shell 파일.
- `my-grafana-dashboard.yaml`: Grafana에 자동으로 프로비저닝될 커스텀 대시보드를 정의합니다.

#해결해야할 문제
- Secret을 넣었을 때 alertmanager가 동작을 안하는 모습
- grafana dashboard의 configMap data를 grafana가 가져오지 못함
- zombie node들의 node exporter까지 query하여 dashboard에 생기는 오류류
