#!/bin/bash

# Define the list of projects to choose from
PROJECTS=("ganesha001" "netaji-001")

# Create the output file
OUTPUT_FILE="instances.csv"
echo "Project,Instance,MachineType,vCPUs,Mem" > "${OUTPUT_FILE}"

# Loop through the list of projects and print the instances
for PROJECT in "${PROJECTS[@]}"; do
  # Check if the required APIs are enabled for the project
  if ! gcloud services list --project=${PROJECT} --enabled | grep -q "compute.googleapis.com"; then
    echo "Skipping project ${PROJECT} as compute API is not enabled."
    continue
  fi
  echo "Project: ${PROJECT}"
  # Get instance name,zone,machine type for ${PROJECT}
  for PAIR in $(\
    gcloud compute instances list \
    --project=${PROJECT} \
    --format="csv[no-heading](name,zone.scope(zones),machineType.scope(machineTypes))")
  do
    # Parse result from above into instance, zone, and machine type vars
    IFS=, read INSTANCE ZONE MACHINE_TYPE <<< ${PAIR}
    # If it's custom-${vCPUs}-${RAM} we've sufficient info
    if [[ ${MACHINE_TYPE} == custom* ]]
    then
      IFS=- read CUSTOM CPU MEM <<< ${MACHINE_TYPE}
      MACHINE_TYPE="Custom"
      MACHINE_FAMILY="Custom"
    else
      # Otherwise, we need to call `machine-types describe`
      MACHINE_TYPE=$(\
        gcloud compute machine-types describe ${MACHINE_TYPE} \
        --project=${PROJECT} \
        --zone=${ZONE} \
        --format="csv[no-heading](name)")
      MACHINE_FAMILY=${MACHINE_TYPE}
      case "${MACHINE_FAMILY}" in
        "n1"*) MACHINE_FAMILY="N1";;
        "Custom"*) MACHINE_FAMILY = "Custom";;
        "n2"*) MACHINE_FAMILY="N2";;
        "g1"*) MACHINE_FAMILY="G1";;
        "e2"*) MACHINE_FAMILY="E2";;
        "e2d"*) MACHINE_FAMILY="E2D";;
        "e2-m"*) MACHINE_FAMILY="E2-M";;
        "n2d"*) MACHINE_FAMILY="N2D";;
        "c2"*) MACHINE_FAMILY="C2";;
        "a2"*) MACHINE_FAMILY="A2";;
        "m2"*) MACHINE_FAMILY="M2";;
        "n2-highcpu"*) MACHINE_FAMILY="N2-highcpu";;
        *) MACHINE_FAMILY="Unknown";;
      esac
      CPU_MEMORY=$(\
        gcloud compute machine-types describe ${MACHINE_TYPE} \
        --project=${PROJECT} \
        --zone=${ZONE} \
        --format="csv[no-heading](guestCpus,memoryMb)")
      IFS=, read CPU MEM <<< ${CPU_MEMORY}
    fi
    echo "${PROJECT},${INSTANCE},${MACHINE_FAMILY},${CPU},${MEM}" >> "${OUTPUT_FILE}"
  done
done