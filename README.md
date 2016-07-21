# Kubernetes => Route53 Mapping Service

This is a Kubernetes service that polls services on its cluster that are
configured with the label `dns=route53` and adds an entry to route 53 as
specified by the annotation `domainName=test-app`

The app requires the following environment variables to be set in order to run:
* `HOSTED_ZONE_ID=EXAMPLEID` - The hosted zone ID of the route53 zone you wish the app to modify
* `AWS_REGION=ap-southeast-2` - The region of your hosted zone
* `ROUTE53_TTL=60` - Time to live sent in the API call to route53, defaults to 60
* `KUBERNETES_SERVICE_HOST=127.0.0.1` - IP of Kubernetes service API, should be in env by default
* `KUBERNETES_PORT_443_TCP_PORT=443` - Port of Kubernetes service API, should be in env by default
* `TOKEN_PATH=/var/run/secrets/kubernetes.io/serviceaccount/token` - path to token file for kube service account, set to path shown by default

For example, given the below Kubernetes service definition:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  labels:
    app: my-app
    role: web
    dns: route53
  annotations:
    domainName: "test-app"
spec:
  selector:
    app: my-app
    role: web
  ports:
  - name: web
    port: 80
    protocol: TCP
    targetPort: web
  - name: web-ssl
    port: 443
    protocol: TCP
    targetPort: web-ssl
  type: LoadBalancer
```

A DNS `CNAME` record is created/modified for
`test-app.myhostedzonedomain.com` pointing to the Elastic Load Balancer
that is configured by Kubernetes.

This service expects that it is running on a Kubernetes node on AWS and
that the IAM profile for that node is set up to allow the following,
along with the default permissions needed by Kubernetes:

```json
{
    "Effect": "Allow",
    "Action": "route53:ListHostedZonesByName",
    "Resource": "*"
},
{
    "Effect": "Allow",
    "Action": [
      "route53:ChangeResourceRecordSets",
      "route53:GetHostedZone"
    ],
    "Resource": "*"
}
```
