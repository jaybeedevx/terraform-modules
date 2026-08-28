apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${cluster_name}
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${cluster_name}
  instanceProfile: ${instance_profile}
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 100Gi
        volumeType: gp3
        encrypted: true