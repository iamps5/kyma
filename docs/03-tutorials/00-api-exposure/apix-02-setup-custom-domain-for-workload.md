---
title: Set up a custom domain for a workload
---

This tutorial shows how to set up a custom domain and prepare a certificate required for exposing a workload. It uses Gardener [External DNS Management](https://github.com/gardener/external-dns-management) and [Certificate Management](https://github.com/gardener/cert-management) components.

>**NOTE:** Skip this tutorial if you use a Kyma domain instead of your custom domain.

## Prerequisites

* Deploy [a sample HttpBin service and a sample Function](./apix-01-create-workload.md).
* If you use a cluster not managed by Gardener, install the [External DNS Management](https://github.com/gardener/external-dns-management#quick-start) and [Certificate Management](https://github.com/gardener/cert-management) components manually in a dedicated Namespace.

## Steps

1. Create a Secret containing credentials for the DNS cloud service provider account in your Namespace.

     * Choose your DNS cloud service provider and create a Secret in your Namespace. To learn how to do it, follow [the guidelines](https://github.com/gardener/external-dns-management/blob/master/README.md#external-dns-management) provided in the External DNS Management documentation. 
     * Export the name of the created Secret as an environment variable:

       ```bash
       export SECRET={SECRET_NAME}
       ```

2. Create a `DNSProvider` custom resource (CR).

     * Export the following values as environment variables. 
        >**NOTE:** As the `SPEC_TYPE`, use the relevant provider type. The `DOMAIN_NAME` value specifies the name of a domain that you own, for example, `mydomain.com`. 

        ```bash
        export SPEC_TYPE={PROVIDER_TYPE}
        export DOMAIN_TO_EXPOSE_WORKLOADS={DOMAIN_NAME} 
        ````
  
     * To create a `DNSProvider` CR, run: 

       ```bash
       cat <<EOF | kubectl apply -f -
       apiVersion: dns.gardener.cloud/v1alpha1
       kind: DNSProvider
       metadata:
         name: dns-provider
         namespace: $NAMESPACE
         annotations:
           dns.gardener.cloud/class: garden
       spec:
         type: $SPEC_TYPE
         secretRef:
           name: $SECRET
         domains:
           include:
             - $DOMAIN_TO_EXPOSE_WORKLOADS
       EOF
       ```
  
3. Create a `DNSEntry` CR.
   
     * Export the following values as environment variables:

       ```bash
       export IP=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}') # Assuming only one LoadBalancer with external IP
       ```
        >**NOTE:** For some cluster providers you need to replace the `ip` with the `hostname`, for example, in AWS, set `jsonpath='{.status.loadBalancer.ingress[0].hostname}'`.

     * To create a `DNSEntry` CR, run:

       ```bash
       cat <<EOF | kubectl apply -f -
       apiVersion: dns.gardener.cloud/v1alpha1
       kind: DNSEntry
       metadata:
         name: dns-entry
         namespace: $NAMESPACE
         annotations:
           dns.gardener.cloud/class: garden
       spec:
         dnsName: "*.$DOMAIN_TO_EXPOSE_WORKLOADS"
         ttl: 600
         targets:
           - $IP
       EOF
       ```

4. Create a Certificate CR.

     * Export the following values as environment variables:

        >**NOTE:** The `TLS_SECRET` is the name of the TLS Secret, for example `httpbin-tls-credentials`.

        ```bash
        export TLS_SECRET={TLS_SECRET_NAME}
        ```

     * To create a Certificate CR, run:

        ```bash
        cat <<EOF | kubectl apply -f -
        apiVersion: cert.gardener.cloud/v1alpha1
        kind: Certificate
        metadata:
          name: httpbin-cert
          namespace: istio-system
        spec:  
          secretName: $TLS_SECRET
          commonName: $DOMAIN_TO_EXPOSE_WORKLOADS
        EOF
        ```
        >**NOTE:** While using the default configuration, certificates with the Let's Encrypt Issuer are valid for 90 days and automatically renewed 30 days before their validity expires. For more information, read the documentation on [Gardener Certificate Management](https://github.com/gardener/cert-management#requesting-a-certificate) and [Gardener extensions for certificate services](https://gardener.cloud/docs/extensions/others/gardener-extension-shoot-cert-service/).

     * To check the certificate status, run: 
     
        ```bash
        kubectl get certificate httpbin-cert -n istio-system
        ```
       
5. [Set up a TLS Gateway](./apix-03-set-up-tls-gateway.md).

Visit the [Gardener external DNS management documentation](https://github.com/gardener/external-dns-management/tree/master/examples) to see more examples of custom resources for services and ingresses.