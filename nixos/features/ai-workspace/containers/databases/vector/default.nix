{ config, lib, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      etcd = {
        image = "quay.io/coreos/etcd:v3.5.5";
        ports = [ "2379:2379" ];
        volumes = [ "etcd-data:/etcd" ];
        cmd = [
          "/usr/local/bin/etcd"
          "--data-dir=/etcd"
          "--listen-client-urls=http://0.0.0.0:2379"
          "--advertise-client-urls=http://localhost:2379"
        ];
        autoStart = true;
      };

      minio = {
        image = "minio/minio:latest";
        ports = [ "9000:9000" "9001:9001" ];
        volumes = [ "minio-data:/data" ];
        environment = {
          MINIO_ROOT_USER = "minioadmin";
          MINIO_ROOT_PASSWORD = "minioadmin";
        };
        cmd = [ "server" "/data" "--console-address" ":9001" ];
        autoStart = true;
      };

      milvus = {
        image = "milvusdb/milvus:v2.3.3";
        ports = [ "19530:19530" ];
        volumes = [ 
          "milvus-data:/var/lib/milvus"
        ];
        cmd = [ "milvus" "run" "standalone" ];
        environment = {
          ETCD_ENDPOINTS = "localhost:2379";
          MINIO_ADDRESS = "localhost:9000";
          MINIO_ROOT_USER = "minioadmin";
          MINIO_ROOT_PASSWORD = "minioadmin";
        };
        extraOptions = [ "--network=host" ];
        autoStart = true;
      };
    };
  };
}