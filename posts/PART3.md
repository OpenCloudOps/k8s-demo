# Kubernetes learning - Part 2

## Summary


## ConfigMap

Normally, we configure our single-base-service application using **.env**, **setting** or **config** file. For example we have a config for sa-webapp:

```yaml
# file .env
SA_LOGIC_URL=sa-logic.abc.com
SA_LOGIC_PORT=3306
```

Main entry will read config here and start connection to ```sa-logic.abc.com:3306```. In case we want to run a **test** environment with url as below:

```yaml
# file .env.test
SA_LOGIC_URL=sa-logic-test.abc.com
SA_LOGIC_PORT=3307
```

We can not modify **.env** for sa-webapp service manually. In kubernetes we use **ConfigMap** to do that. It's where we store all configurations in defferent environments for our app. The Pod will refer to the right values in run-time. 

### Do I really need a ConfigMap 

In general, you should use env if you have a few simple variables that can be tightly-coupled with the Pod definition. For example, the log verbosity level of your application.

On the other hand, configMaps are more suited to complex configurations. For example, you can load php.ini or package.json files into a configMap and inject them into the container. In this specific case, it’d be better to expose the files as volumes instead of environment variables.

Alternatively, you should use Secrets whenever you need to inject sensitive information into the container. For example, database passwords, private SSH keys, and certificates should all go into Secrets instead of configMaps.

### How does a ConfigMap work

More detail [here](https://matthewpalmer.net/kubernetes-app-developer/articles/ultimate-configmap-guide-kubernetes.html)

First, you have multiple ConfigMaps, one for each environment.

Second, a ConfigMap is created and added to the Kubernetes cluster.

Third, containers in the Pod reference the ConfigMap and use its values.

![ConfigMap](../docs/configmap-diagram.gif)


### How to use ConfigMap

There are 2 cases to use ConfigMap as I know now:

  - **Use ConfigMap as a Volume**: Each property name in this ConfigMap becomes a new file in the mounted directory (`/etc/config`) after you mount it.
  - **Use ConfigMap with Environment Variables**: each key from the ConfigMap is now available as an environment variable.


In this part, we will use ConfigMap with ENV Variables. I hope to try the first one at later parts.

### Tell me the steps:

1. Define the ConfigMap in a YAML file.


## DNS