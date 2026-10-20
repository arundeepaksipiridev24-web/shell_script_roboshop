#!/bin/bash

AMI_ID="ami-0055977a6e828a4f4"
INSTANCE_TYPE="t3.micro"
SECURITY_GROUP_ID="sg-0a89d548ef86c3b6b"
HOSTED_ZONE_ID="Z047542739NDVFK4NND1"

COMPONENT=$1

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --security-group-ids $SECURITY_GROUP_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$COMPONENT}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance Created: $INSTANCE_ID"

PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch "{
      \"Changes\": [{
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"$COMPONENT.sodhichebutha.online\",
          \"Type\": \"A\",
          \"TTL\": 1,
          \"ResourceRecords\": [{\"Value\": \"$PRIVATE_IP\"}]
        }
      }]
    }"

echo "DNS Record Created: $COMPONENT.sodhichebutha.online -> $PRIVATE_IP"