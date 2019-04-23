#! /usr/bin/env bash

kubectl delete service postgres-service && \
kubectl delete deploy --all && \
kubectl delete configmap --all && \
kubectl delete pvc --all && \
kubectl delete pv --all
