#!/bin/bash

# set secretkey for metallb
echo "generating secret for metallb"
yq eval -i ".stringData.secretkey = \"$(openssl rand -base64 128)\"" metallb/secret.yaml

if [ -z "$1" ]
    then
        echo "no repo URL provided, using upstream"
    else
        yq e -i ".spec.source.repoURL = \"$1\"" kubeflow.yaml
        for filename in ./argocd-applications/*.yaml; do
            if [ $(yq e ".spec.source | has (\"helm\")" $filename) == false ]
                then
                    yq e -i ".spec.source.repoURL = \"$1\"" $filename
            fi
        done
fi

if [ -z "$2" ]
    then
        echo "no target branch provided, using HEAD"
    else
        yq e -i ".spec.source.targetRevision = \"$2\"" kubeflow.yaml
        for filename in ./argocd-applications/*.yaml; do
            if [ $(yq e ".spec.source | has (\"helm\")" $filename) == false ]
                then
                    yq e -i ".spec.source.targetRevision = \"$2\"" $filename
            fi
        done
fi
