# How to View VictoriaLogs Logs Archived in S3

tl;dr:
Set up a VictoriaLogs vlstorage cluster with mounted files using `--retentionPeriod=100y`,
and you can query the logs via vlselect (VictoriaLogs node with `--storageNode` flag).

You could use docker compose, minikube, EKS, or any other approach you like to provision a VictoriaLogs cluster locally.

https://docs.victoriametrics.com/victorialogs/

## Instructions

1. Download logs for the date you want to view.
   Since VictoriaLogs is sharded, if there are multiple files within a date folder, download all of them.
   
   Example: `s3://dev-victoria-logs-archive/archives/20250602/vl-victoria-logs-cluster-vlstorage-0.tar`

2. Place each shard's logs in `./data/vlstorage-${shard}/`.
   
   Example: `./data/vlstorage-0/vl-victoria-logs-cluster-vlstorage-0.tar`

3. Extract the tar files and delete the original .tar files.
   
   Example:
   ```shell
   `tar -xvf vl-victoria-logs-cluster-vlstorage-0.tar`
   rm vl-victoria-logs-cluster-vlstorage-0.tar
   ```

4. Start docker compose: `docker compose up -d`
5. Access Grafana at http://localhost:3000 (username, password) = (admin, admin)
6. Search logs from Explore (http://localhost:3000/explore) - the rest is the same as regular search
