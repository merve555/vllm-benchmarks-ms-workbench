#!/bin/bash

# Test GCS FUSE mount in a pod
# This creates a simple test pod to verify GCS FUSE works

set -e

echo "Testing GCS FUSE mount..."

# Create a test job that mounts GCS and writes a test file
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: gcs-fuse-test
  namespace: default
spec:
  template:
    spec:
      containers:
        - name: test
          image: google/cloud-sdk:latest
          command: ["/bin/bash"]
          args:
            - -c
            - |
              echo "Testing GCS FUSE mount..."
              ls -la /gcs-results || echo "Mount not found"
              echo "Test file created at $(date)" > /gcs-results/test-file.txt
              ls -la /gcs-results/
              echo "Test file written successfully!"
              cat /gcs-results/test-file.txt
          volumeMounts:
            - name: gcs-results
              mountPath: /gcs-results
      volumes:
        - name: gcs-results
          csi:
            driver: gcsfuse.csi.storage.gke.io
            volumeAttributes:
              bucketName: merves-vllm-bm-results
              mountOptions: "implicit-dirs"
      restartPolicy: Never
  backoffLimit: 1
EOF

echo "Waiting for test job to complete..."
kubectl wait --for=condition=complete --timeout=60s job/gcs-fuse-test || true

echo ""
echo "Test job logs:"
kubectl logs job/gcs-fuse-test

echo ""
echo "Checking if file exists in GCS bucket:"
gsutil ls gs://merves-vllm-bm-results/test-file.txt || echo "File not found in bucket"

echo ""
echo "Cleaning up test job..."
kubectl delete job gcs-fuse-test --ignore-not-found=true

