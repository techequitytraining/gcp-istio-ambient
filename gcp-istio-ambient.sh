#!/bin/bash
#
# Copyright 2019 Shiyghan Navti. Email shiyghan@gmail.com
#
#################################################################################
####  Explore Istio BookInfo Microservice Application in Google Cloud Shell #####
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=1 # $(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=1 # $(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-istio-ambient > /dev/null 2>&1
export PROJDIR=`pwd`/gcp-istio-ambient
export SCRIPTNAME=gcp-istio-ambient.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_CLUSTER=istio-gke-cluster
export ISTIO_VERSION=1.24.2
export ISTIO_RELEASE_VERSION=1.24
export GCP_REGION=us-central1
export GCP_ZONE=us-central1-a
EOF
source $PROJDIR/.env
fi

export APPLICATION_NAMESPACE=bookinfo
export APPLICATION_NAME=bookinfo

# Display menu options
while :
do
clear
cat<<EOF
===========================================================================
Explore Traffic Management, Resiliency and Telemetry Features using Istio 
---------------------------------------------------------------------------
 (1) Install tools
 (2) Enable APIs
 (3) Create Kubernetes cluster
 (4) Install Istio
 (5) Configure namespace for automatic sidecar injection
 (6) Configure service and deployment
 (7) Configure gateway and virtualservice
 (8) Configure subsets
 (9) Explore Istio traffic management
 (Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_CLUSTER=$GCP_CLUSTER
export ISTIO_VERSION=$ISTIO_VERSION
export ISTIO_RELEASE_VERSION=$ISTIO_RELEASE_VERSION
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo "*** Istio version is $ISTIO_VERSION ***" | pv -qL 100
        echo "*** Istio release version is $ISTIO_RELEASE_VERSION ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_CLUSTER=$GCP_CLUSTER
export ISTIO_VERSION=$ISTIO_VERSION
export ISTIO_RELEASE_VERSION=$ISTIO_RELEASE_VERSION
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo "*** Istio version is $ISTIO_VERSION ***" | pv -qL 100
                echo "*** Istio release version is $ISTIO_RELEASE_VERSION ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ curl -L https://github.com/istio/istio/releases/download/\${ISTIO_VERSION}/istio-\${ISTIO_VERSION}-linux-amd64.tar.gz | tar xz -C \$HOME # to download Istio" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ curl -L https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz | tar xz -C $HOME # to download Istio" | pv -qL 100
    curl -L https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz | tar xz -C $HOME 
    cd $HOME/istio-${ISTIO_VERSION} > /dev/null 2>&1 #Set project zone
    export PATH=$HOME/istio-${ISTIO_VERSION}/bin:$PATH > /dev/null 2>&1 #Set project zone
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "$ rm -rf $HOME/istio-${ISTIO_VERSION} # to delete download" | pv -qL 100
    rm -rf $HOME/istio-${ISTIO_VERSION}
else
    export STEP="${STEP},1i"   
    echo
    echo "1. Download Istio" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT services enable cloudapis.googleapis.com container.googleapis.com cloudscheduler.googleapis.com appengine.googleapis.com cloudscheduler.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT services enable cloudapis.googleapis.com container.googleapis.com # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services enable cloudapis.googleapis.com container.googleapis.com # to enable APIs
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},2i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta container clusters create \$GCP_CLUSTER --zone \$GCP_ZONE --machine-type n1-standard-2 --num-nodes 5 --labels location=\$GCP_REGION --spot # to create container cluster" | pv -qL 100
    echo      
    echo "$ gcloud --project \$GCP_PROJECT container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type n1-standard-2 --num-nodes 5 --labels location=$GCP_REGION --spot # to create container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type n1-standard-2 --num-nodes 5 --labels location=$GCP_REGION --spot
    echo      
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
    echo
    echo "$ kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || { kubectl kustomize \"github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=v1.0.0\" | kubectl apply -f -; } # to install Kubernetes Gateway CRDs"
    kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=v1.0.0" | kubectl apply -f -; }  
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters delete ${GCP_CLUSTER} --zone $GCP_ZONE # to create container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters delete ${GCP_CLUSTER} --zone $GCP_ZONE
else
    export STEP="${STEP},3i"   
    echo
    echo "1. Create container cluster" | pv -qL 100
    echo "2. Retrieve the credentials for cluster" | pv -qL 100
    echo "3. Enable current user to set RBAC rules" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ \$HOME/istio-\${ISTIO_VERSION}/bin/istioctl install --set profile=ambient --skip-confirmation # to install Istio" | pv -qL 100
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml # to install addon" | pv -qL 100
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml # to install addon" | pv -qL 100
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml # to install addon" | pv -qL 100
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-\${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml # to install addon" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ $HOME/istio-${ISTIO_VERSION}/bin/istioctl install --set profile=ambient --set \"components.ingressGateways[0].enabled=true\" --set \"components.ingressGateways[0].name=istio-ingressgateway\" --skip-confirmation # to install Istio" | pv -qL 100
    $HOME/istio-${ISTIO_VERSION}/bin/istioctl install --set profile=ambient --set "components.ingressGateways[0].enabled=true" --set "components.ingressGateways[0].name=istio-ingressgateway" --skip-confirmation
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml # to install addon" | pv -qL 100
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml # to install addon" | pv -qL 100
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml # to install addon" | pv -qL 100
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml
    echo
    echo "$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml # to install addon" | pv -qL 100
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml
    echo
    echo "$ kubectl create namespace istio-system # to create istio-system namespace"
    kubectl create namespace istio-system
    echo
    echo "$ cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gcp-critical-pods
  namespace: istio-system
spec:
  hard:
    pods: 1000
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values:
      - system-node-critical
EOF # to defined ResourceQuota for the node-critical class"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gcp-critical-pods
  namespace: istio-system
spec:
  hard:
    pods: 1000
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values:
      - system-node-critical
EOF
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ $PROJDIR/istio-$ASM_VERSION/bin/istioctl uninstall --purge # to remove istio" | pv -qL 100
    $PROJDIR/istio-$ASM_VERSION/bin/istioctl uninstall --purge
    echo && echo
    echo "$  kubectl delete namespace istio-system --ignore-not-found=true # to remove namespace" | pv -qL 100
    kubectl delete namespace istio-system --ignore-not-found=true
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml # to delete addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/prometheus.yaml
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml # to delete addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/jaeger.yaml
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml # to delete addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/grafana.yaml
    echo
    echo "$ kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml # to delete addon" | pv -qL 100
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE_VERSION}/samples/addons/kiali.yaml
else
    export STEP="${STEP},4i"   
    echo
    echo "1. Install Istio" | pv -qL 100
    echo "2. Create namespace" | pv -qL 100
    echo "3. Create istio operator" | pv -qL 100
    echo "4. Configure addons" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ kubectl create namespace \$APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    echo
    echo "$ kubectl label namespace \$APPLICATION_NAMESPACE istio.io/dataplane-mode=ambient --overwrite # to label namespaces for automatic sidecar injection" | pv -qL 100
    echo
    echo "$ \$PROJDIR/istio-\$ASM_VERSION/bin/istioctl x waypoint apply --namespace \$APPLICATION_NAMESPACE --wait # to deploy a waypoint proxy for namespace" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl create namespace $APPLICATION_NAMESPACE # to create namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE 2> /dev/null
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio.io/dataplane-mode=ambient --overwrite # to label namespaces for automatic sidecar injection" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio.io/dataplane-mode=ambient --overwrite
    echo
    echo "$ $PROJDIR/istio-$ASM_VERSION/bin/istioctl x waypoint apply --namespace $APPLICATION_NAMESPACE --wait # to deploy a waypoint proxy for namespace" | pv -qL 100
    $PROJDIR/istio-$ASM_VERSION/bin/istioctl x waypoint apply --namespace $APPLICATION_NAMESPACE --wait
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio.io/dataplane-mode- # to delete label" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio.io/dataplane-mode- 
    echo
    echo "$ kubectl label namespace $APPLICATION_NAMESPACE istio.io/use-waypoint- # to delete label" | pv -qL 100
    kubectl label namespace $APPLICATION_NAMESPACE istio.io/use-waypoint- 
    echo
    echo "$ $PROJDIR/istio-$ASM_VERSION/bin/istioctl x waypoint delete --all # to deploy a waypoint proxy for namespace" | pv -qL 100
    $PROJDIR/istio-$ASM_VERSION/bin/istioctl x waypoint delete --all
    echo
    echo "$ kubectl delete namespace $APPLICATION_NAMESPACE # to delete namespace" | pv -qL 100
    kubectl create namespace $APPLICATION_NAMESPACE 2> /dev/null
else
    export STEP="${STEP},5i"   
    echo
    echo "1. Create namespace" | pv -qL 100
    echo "2. Label namespace" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml # to configure application" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo-versions.yaml # to configure application" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml # to configure application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo-versions.yaml # to configure application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo-versions.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/sleep/sleep.yaml # to configure application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/sleep/sleep.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/sleep/notsleep.yaml # to configure application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/sleep/notsleep.yaml
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n $APPLICATION_NAMESPACE
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"        
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml # to delete application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo-versions.yaml # to delete application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo-versions.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/sleep/sleep.yaml # to delete application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/sleep/sleep.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/sleep/notsleep.yaml # to delete application" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/sleep/notsleep.yaml
else
    export STEP="${STEP},6i"   
    echo
    echo "1. Configure application" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},7i"
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/gateway-api/bookinfo-gateway.yaml # to create Kubernetes Gateway and HTTPRoute" | pv -qL 100
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE annotate gateway bookinfo-gateway networking.istio.io/service-type=ClusterIP # to change the service type to ClusterIP"
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},7"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/gateway-api/bookinfo-gateway.yaml # to create Kubernetes Gateway and HTTPRoute" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/gateway-api/bookinfo-gateway.yaml
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE annotate gateway bookinfo-gateway networking.istio.io/service-type=ClusterIP # to change the service type to ClusterIP"
    kubectl -n $APPLICATION_NAMESPACE annotate gateway bookinfo-gateway networking.istio.io/service-type=ClusterIP
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},7x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=v1.1.0" | kubectl delete -f - # to delete Kubernetes Gateway and HTTPRoute" | pv -qL 100
    kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=v1.1.0" | kubectl delete -f -
    echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/gateway-api/bookinfo-gateway.yaml # to delete Kubernetes Gateway and HTTPRoute" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE delete -f $HOME/istio-${ISTIO_VERSION}/samples/bookinfo/gateway-api/bookinfo-gateway.yaml
else
    export STEP="${STEP},7i"   
    echo
    echo "1. Configure gateway and virtualservice" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"8")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},8i"
    echo
    echo "$ kubectl -n \$APPLICATION_NAMESPACE apply -f \$HOME/istio-\${ISTIO_VERSION}/samples/bookinfo/networking/destination-rule-all.yaml # to apply yaml file" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},8"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/destination-rule-all.yaml
    echo 
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to apply yaml file" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},8x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER} > /dev/null 2>&1 
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/networking/destination-rule-all.yaml
else
    export STEP="${STEP},8i"   
    echo
    echo "1. Configure subsets" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;
    
"9")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},9i"
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},9"
    gcloud config set project $GCP_PROJECT  > /dev/null 2>&1
    kubectl config use-context gke_${GCP_PROJECT}_${GCP_ZONE}_${GCP_CLUSTER}  > /dev/null 2>&1
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER  > /dev/null 2>&1
    echo
    echo "$ export GATEWAY_HOST=bookinfo-gateway-istio.default # to set Kubernetes gateway" | pv -qL 100
    export GATEWAY_HOST=bookinfo-gateway-istio.default
    echo
    echo "$ export GATEWAY_SERVICE_ACCOUNT=ns/default/sa/bookinfo-gateway-istio # to set Kubernetes Gateway service account"
    export GATEWAY_SERVICE_ACCOUNT=ns/default/sa/bookinfo-gateway-istio
    echo
    echo "$ while true; do curl -s -o /dev/null http://${GATEWAY_HOST}/productpage ; sleep 1; done & # to generate traffic" | pv -qL 100
    while true; do curl -s -o /dev/null http://${GATEWAY_HOST}/productpage ; sleep 1; done &
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage-viewer
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/default/sa/sleep
        - cluster.local/$GATEWAY_SERVICE_ACCOUNT
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage-viewer
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/default/sa/sleep
        - cluster.local/$GATEWAY_SERVICE_ACCOUNT
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec deploy/sleep -- curl -s "http://$GATEWAY_HOST/productpage" | grep -o \"<title>.*</title>\" # to confirm authorization policy. This should succeed" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec deploy/sleep -- curl -s "http://$GATEWAY_HOST/productpage" | grep -o "<title>.*</title>"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec deploy/notsleep -- curl -s http://productpage:9080/ | grep -o \"<title>.*</title>\" # to confirm authorization policy. This should succeed" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec deploy/notsleep -- curl -s http://productpage:9080/ | grep -o "<title>.*</title>"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec deploy/sleep -- curl -s http://productpage:9080/ | grep -o \"<title>.*</title>\" # to confirm authorization policy. This should fail with a connection reset error code 56" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec deploy/sleep -- curl -s http://productpage:9080/ | grep -o "<title>.*</title>"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage-viewer
  namespace: default
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: productpage
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/default/sa/sleep
    to:
    - operation:
        methods: [\"GET\"]
EOF" | pv -qL 100
kubectl apply -n $APPLICATION_NAMESPACE -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: productpage-viewer
  namespace: default
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: productpage
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/default/sa/sleep
    to:
    - operation:
        methods: ["GET"]
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec deploy/sleep -- curl -s "http://productpage:9080/productpage" -X DELETE # to the new waypoint proxy is enforcing the updated authorization policy. This should fail with an RBAC error because it is not a GET operation" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec deploy/sleep -- curl -s "http://productpage:9080/productpage" -X DELETE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec deploy/notsleep -- curl -s http://productpage:9080/ # to the new waypoint proxy is enforcing the updated authorization policy. This should fail with an RBAC error because the identity is not allowed" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec deploy/notsleep -- curl -s http://productpage:9080/
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE exec deploy/sleep -- curl -s http://productpage:9080/ | grep -o \"<title>.*</title>\" # to the new waypoint proxy is enforcing the updated authorization policy. This should continue to work" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE exec deploy/sleep -- curl -s http://productpage:9080/ | grep -o "<title>.*</title>"
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    export CFILE=$HOME/istio-${ISTIO_VERSION}/samples/bookinfo/gateway-api/route-reviews-90-10.yaml
    echo 
    echo "$ cat $CFILE # to view yaml file" | pv -qL 100
    cat $CFILE
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'    
    echo && echo
    echo "$ kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE # to route requests to jason user" | pv -qL 100
    kubectl -n $APPLICATION_NAMESPACE apply -f $CFILE
    echo
    echo "$ kubectl exec deploy/sleep -- sh -c \"for i in \\$(seq 1 100); do curl -s http://\${GATEWAY_HOST}:9080/productpage | grep reviews-v.-; done\" & # to confirm 10% of the traffic from 100 requests goes to reviews-v2" | pv -qL 100
    $ kubectl exec deploy/sleep -- sh -c "for i in \$(seq 1 100); do curl -s http://${GATEWAY_HOST}:9080/productpage | grep reviews-v.-; done" &
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},9x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},9i"   
    echo
    echo "1. Explore traffic management" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done

