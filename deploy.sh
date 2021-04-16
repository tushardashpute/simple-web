#!/bin/bash

REGION=us-east-1
SERVICE_NAME=aws-service-1
CLUSTER=ecs-fargate
IMAGE_VERSION="v_"${BUILD_NUMBER}
TASK_FAMILY="ecs-fargate-task"

# Create a new task definition for this build

sed -e "s;%BUILD_NUMBER%;${BUILD_NUMBER};g" aws-task-1.json > aws-task-1-v_${BUILD_NUMBER}.json

aws ecs register-task-definition --family ecs-fargate-task --cli-input-json file://aws-task-1-v_${BUILD_NUMBER}.json --requires-compatibilities FARGATE --network-mode awsvpc --cpu 256 --memory 512  --execution-role-arn "arn:aws:iam::711693673091:role/ecsTaskExecutionRole"

# Update the service with the new task definition and desired count
REVISION=`aws ecs describe-task-definition --task-definition aws-task-1 | egrep "revision" | tr "/" " " | awk '{print $2}' | sed 's/"$//'`
SERVICES=`aws ecs describe-services --services ${SERVICE_NAME} --cluster ${CLUSTER} --region ${REGION} | jq .failures[]`


#Create or update service
if [ "$SERVICES" == "" ]; then
  echo "entered existing service"
  DESIRED_COUNT=`aws ecs describe-services --services ${SERVICE_NAME} --cluster ${CLUSTER} --region ${REGION} | jq .services[].desiredCount`
  if [ ${DESIRED_COUNT} = "0" ]; then
    DESIRED_COUNT="1"
  fi
  aws ecs update-service --cluster ${CLUSTER} --region ${REGION} --service ${SERVICE_NAME} --task-definition ${TASK_FAMILY}:${REVISION} --desired-count ${DESIRED_COUNT} --deployment-configuration maximumPercent=100,minimumHealthyPercent=0
else
  echo "entered new service"
  aws ecs create-service --service-name ${SERVICE_NAME} --desired-count 1 --task-definition ${TASK_FAMILY} --cluster ${CLUSTER} --region ${REGION}
fi
