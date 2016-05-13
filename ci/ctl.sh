#!/bin/bash -e

pushd `dirname $0` > /dev/null
base=$(pwd -P)
popd > /dev/null

opts=w:
w=true
while getopts $opts opt; do
  case $opt in
    w)   w=false ;;
    ?|*) exit 2  ;;
  esac
done

shift $(($OPTIND-1))

[ -z "$1" ] && { echo "usage: $0 <domain>" 2>&1; exit 1; }

domain="$1"
tpl=$base/cfn-template.json
stackname=$(echo $domain | tr '.' '-')

[ -f $tpl ] || { echo "$tpl not found" 2>&1; exit 1; }

##
# valid template?
tps=$(aws cloudformation validate-template --template-body file://$tpl) || exit

# create or update?
up=false
aws cloudformation describe-stacks --stack-name $stackname >/dev/null 2>&1 \
  && { action=update; up=true; } || action=create; 
##

zone=$(echo $domain | sed -E 's/(.*\.)([a-zA-Z0-9-]*\.[a-zA-Z0-9]*$)/\2./')
echo $zone
zoneid=$(aws route53 list-hosted-zones-by-name \
                    --query="HostedZones[?Name=='$zone'].Id" \
                    --output=text | sed 's/\/hostedzone\///')

[ -z "$zoneid" ] && { echo "No access to hosted zone for $domain" 2>&1; exit 1; }

##
# params
parameters=
iam=
parameters="$parameters ParameterKey=HostedZoneId,ParameterValue=$zoneid"
parameters="$parameters ParameterKey=Domain,ParameterValue=$domain"

##


##
# action
echo "${action} $stackname"
aws cloudformation $action-stack \
  --stack-name $stackname \
  --template-body file://$tpl \
  --output text \
  --capabilities CAPABILITY_IAM \
  --parameters $parameters \
  --tags "Key=Name,Value=$stackname" \
         "Key=Domain,Value=$domain" \
         "Key=Service,Value=website"
s=$?
##

$w || exit $s


##
# wait for completion
event="IN_PROGRESS"

while [[ $event =~ IN_PROGRESS$ ]]; do
  sleep 5
  event=`aws cloudformation describe-stacks --stack-name $stackname --query Stacks[].StackStatus --output text 2>/dev/null`
  aws cloudformation describe-stack-events --stack-name $stackname --output text \
    --max-items=1 --query=StackEvents[].[LogicalResourceId,ResourceStatus] | head -n 1
done

echo $event
##


$base/sync.sh -d $domain
