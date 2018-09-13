#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry
# Hint: Make sure to wait until Nexus if fully up and running
#       before configuring nexus with repositories.
#       You could use the following code:
# while : ; do
#   echo "Checking if Nexus is Ready..."
#   oc get pod -n ${GUID}-nexus|grep '\-2\-'|grep -v deploy|grep "1/1"
#   [[ "$?" == "1" ]] || break
#   echo "...no. Sleeping 10 seconds."
#   sleep 10
# done

# Ideally just calls a template
# oc new-app -f ../templates/nexus.yaml --param .....

# To be Implemented by Student

TEMPLATES_ROOT=$(dirname $0)/../templates
oc new-app sonatype/nexus3:latest -n ${GUID}-nexus 
oc expose svc nexus3 -n ${GUID}-nexus 
oc rollout pause dc nexus3 -n ${GUID}-nexus 
oc patch dc nexus3 --patch='{ "spec": { "strategy": { "type": "Recreate" }}}' -n ${GUID}-nexus 
oc set resources dc nexus3 --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m -n ${GUID}-nexus 
echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nexus-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi" | oc create -f -

oc set volume dc/nexus3 --add --overwrite --name=nexus3-volume-1 --mount-path=/nexus-data/ --type persistentVolumeClaim --claim-name=nexus-pvc -n ${GUID}-nexus 
oc set probe dc/nexus3 --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok -n ${GUID}-nexus 
oc set probe dc/nexus3 --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/repository/maven-public/ -n ${GUID}-nexus 
oc rollout resume dc nexus3 -n ${GUID}-nexus 

while : ; do
    echo "Checking if Nexus is Ready..."
    oc get pod -n ${GUID}-nexus|grep "1/1"
    [[ "$?" == "1" ]] || break
    echo "...no. Sleeping 10 seconds."
	sleep 10
done

echo "Configure Nexus"
chmod +x ./Infrastructure/bin/nexus_configuration.sh
./Infrastructure/bin/nexus_configuration.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus )

oc expose dc nexus3 --port=5000 --name=nexus-registry -n ${GUID}-nexus 
oc create route edge nexus-registry --service=nexus-registry --port=5000 -n ${GUID}-nexus 
oc annotate route nexus3 console.alpha.openshift.io/overview-app-route=true -n ${GUID}-nexus 
oc annotate route nexus-registry console.alpha.openshift.io/overview-app-route=false -n ${GUID}-nexus 