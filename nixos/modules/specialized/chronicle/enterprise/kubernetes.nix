{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.modules.specialized.chronicle.enterprise.kubernetes or {};
in
{
  options.services.chronicle.enterprise.kubernetes = {
    enable = mkEnableOption "Kubernetes deployment support";

    deployment = {
      namespace = mkOption {
        type = types.str;
        default = "chronicle";
        description = "Kubernetes namespace";
      };

      replicas = mkOption {
        type = types.int;
        default = 3;
        description = "Number of pod replicas";
      };

      image = mkOption {
        type = types.str;
        default = "chronicle:v4.0.0";
        description = "Container image";
      };

      imagePullPolicy = mkOption {
        type = types.enum [ "Always" "IfNotPresent" "Never" ];
        default = "IfNotPresent";
        description = "Image pull policy";
      };
    };

    resources = {
      requests = {
        cpu = mkOption {
          type = types.str;
          default = "500m";
          description = "CPU request";
        };

        memory = mkOption {
          type = types.str;
          default = "1Gi";
          description = "Memory request";
        };
      };

      limits = {
        cpu = mkOption {
          type = types.str;
          default = "2000m";
          description = "CPU limit";
        };

        memory = mkOption {
          type = types.str;
          default = "4Gi";
          description = "Memory limit";
        };
      };
    };

    autoscaling = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable horizontal pod autoscaling";
      };

      minReplicas = mkOption {
        type = types.int;
        default = 2;
        description = "Minimum replicas";
      };

      maxReplicas = mkOption {
        type = types.int;
        default = 10;
        description = "Maximum replicas";
      };

      targetCPU = mkOption {
        type = types.int;
        default = 70;
        description = "Target CPU utilization percentage";
      };

      targetMemory = mkOption {
        type = types.int;
        default = 80;
        description = "Target memory utilization percentage";
      };
    };

    service = {
      type = mkOption {
        type = types.enum [ "ClusterIP" "NodePort" "LoadBalancer" ];
        default = "LoadBalancer";
        description = "Kubernetes service type";
      };

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Service port";
      };
    };

    ingress = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable ingress";
      };

      className = mkOption {
        type = types.str;
        default = "nginx";
        description = "Ingress class name";
      };

      host = mkOption {
        type = types.str;
        default = "chronicle.example.com";
        description = "Ingress hostname";
      };

      tls = {
        enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Enable TLS";
        };

        secretName = mkOption {
          type = types.str;
          default = "chronicle-tls";
          description = "TLS secret name";
        };
      };
    };

    persistence = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable persistent storage";
      };

      storageClass = mkOption {
        type = types.str;
        default = "standard";
        description = "Storage class name";
      };

      size = mkOption {
        type = types.str;
        default = "50Gi";
        description = "Storage size";
      };
    };

    helm = {
      chartVersion = mkOption {
        type = types.str;
        default = "4.0.0";
        description = "Helm chart version";
      };

      repository = mkOption {
        type = types.str;
        default = "https://charts.chronicle.org";
        description = "Helm chart repository";
      };
    };
  };

  config = mkIf (cfg.enable or false) {
    environment.systemPackages = with pkgs; [
      (writeScriptBin "chronicle-k8s" ''
        #!${pkgs.bash}/bin/bash
        # Kubernetes Deployment Management
        
        set -euo pipefail
        
        NAMESPACE="${cfg.deployment.namespace}"
        REPLICAS=${toString cfg.deployment.replicas}
        IMAGE="${cfg.deployment.image}"
        
        generate_deployment() {
            cat << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chronicle
  namespace: $NAMESPACE
  labels:
    app: chronicle
    version: v4.0.0
spec:
  replicas: $REPLICAS
  selector:
    matchLabels:
      app: chronicle
  template:
    metadata:
      labels:
        app: chronicle
        version: v4.0.0
    spec:
      containers:
      - name: chronicle
        image: $IMAGE
        imagePullPolicy: ${cfg.deployment.imagePullPolicy}
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        resources:
          requests:
            cpu: ${cfg.resources.requests.cpu}
            memory: ${cfg.resources.requests.memory}
          limits:
            cpu: ${cfg.resources.limits.cpu}
            memory: ${cfg.resources.limits.memory}
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: NAMESPACE
          value: $NAMESPACE
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
${if cfg.persistence.enabled then ''
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: chronicle-pvc
'' else ""}
---
apiVersion: v1
kind: Service
metadata:
  name: chronicle
  namespace: $NAMESPACE
spec:
  type: ${cfg.service.type}
  ports:
  - port: ${toString cfg.service.port}
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: chronicle
${if cfg.autoscaling.enabled then ''
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: chronicle-hpa
  namespace: $NAMESPACE
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: chronicle
  minReplicas: ${toString cfg.autoscaling.minReplicas}
  maxReplicas: ${toString cfg.autoscaling.maxReplicas}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: ${toString cfg.autoscaling.targetCPU}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: ${toString cfg.autoscaling.targetMemory}
'' else ""}
${if cfg.ingress.enabled then ''
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: chronicle-ingress
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/ingress.class: ${cfg.ingress.className}
spec:
${if cfg.ingress.tls.enabled then ''
  tls:
  - hosts:
    - ${cfg.ingress.host}
    secretName: ${cfg.ingress.tls.secretName}
'' else ""}
  rules:
  - host: ${cfg.ingress.host}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: chronicle
            port:
              number: ${toString cfg.service.port}
'' else ""}
${if cfg.persistence.enabled then ''
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: chronicle-pvc
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ${cfg.persistence.storageClass}
  resources:
    requests:
      storage: ${cfg.persistence.size}
'' else ""}
EOF
        }
        
        case "''${1:-help}" in
            deploy)
                echo "Deploying Step Recorder to Kubernetes..."
                kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
                generate_deployment | kubectl apply -f -
                echo "✓ Deployment created"
                ;;
            status)
                echo "=== Step Recorder Kubernetes Status ==="
                kubectl -n $NAMESPACE get deployments,pods,services,ingress
                ;;
            scale)
                replicas="''${2:-3}"
                kubectl -n $NAMESPACE scale deployment chronicle --replicas=$replicas
                echo "✓ Scaled to $replicas replicas"
                ;;
            logs)
                kubectl -n $NAMESPACE logs -l app=chronicle --tail=100 -f
                ;;
            delete)
                echo "Deleting Step Recorder from Kubernetes..."
                generate_deployment | kubectl delete -f - --ignore-not-found=true
                echo "✓ Deleted"
                ;;
            generate)
                generate_deployment
                ;;
            helm-install)
                echo "Installing via Helm..."
                helm repo add chronicle ${cfg.helm.repository}
                helm repo update
                helm install chronicle chronicle/chronicle \
                  --namespace $NAMESPACE \
                  --create-namespace \
                  --version ${cfg.helm.chartVersion}
                echo "✓ Helm installation complete"
                ;;
            *)
                echo "Usage: chronicle-k8s {deploy|status|scale|logs|delete|generate|helm-install}"
                echo ""
                echo "Commands:"
                echo "  deploy       - Deploy to Kubernetes"
                echo "  status       - Show deployment status"
                echo "  scale <N>    - Scale to N replicas"
                echo "  logs         - View pod logs"
                echo "  delete       - Delete deployment"
                echo "  generate     - Generate manifests"
                echo "  helm-install - Install via Helm"
                exit 1
                ;;
        esac
      '')
    ];
  };
}
