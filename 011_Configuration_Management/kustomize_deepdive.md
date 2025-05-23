---
lang: en_GB
notes: |
    dodat info ke strukture base resource a overlays
    stava se, ze patch se muze z prostredi dostat do template
    otazka na prehledovem slidu
    lepe popsat zdrojove manifesty - kde se berou
    nakonec dat nejaky info z praxe jak v etnetera pouzivame
title: |
    ![ETN Core](etnetera-core-vertical-white.svg){width=15% style="position:absolute;left:0px"}</br>
    Kustomize deep dive
author: Petr Studený <petr.studeny@etnetera.cz>
parallaxBackgroundImage: parallaxETNBCK.svg
parallaxBackgroundSize: 3840px 2160px
header-includes: |
    <style>
    div.sourceCode {
        background-color: rgba(255,255,205,0.03);
        margin: 10px
        }
    .reveal .sourceCode {
        overflow-y: scroll;
        }
    .reveal code {
        background-color: rgba(0,0,0,0.3);
        font-family: Iosevka
        }
    </style>

...
# Scratch the surface

## Kubernetes API and kubectl

* REST API including PUT and PATCH with dry-run option
* write your manifests
* kubectl `apply` vs. `replace`; `patch`
  * prefer declarative way with `apply` for GitOps
  * `kubectl patch` - partial update using strategic merge, json merge or json patch
  * strategic merge requires merge strategy defined in [API reference][1]

## Kubernetes configuration management systems

* Helm
* [Kustomize][2]
* Jsonnet
* Kpt; [Ansible][3]; [Terraform][4]; Pulumi; etc.

## Kustomize

* native and part of kubectl or standalone binary
* rebase and patch like in software packaging
* embrace manifests
* declarative or imperative
* template free {{ approach }}
* base resource is valid kubernetes manifest
* e.g. configMap key is the smallest item

# Deep dive
## Kustomization.yaml

`kustomize init --auto-detect`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-cool-app
images: []  # accepts glob
replicas: []
resources: []
patches: []
configMapGenerator: []
secretGenerator: []
```
## Resources & Components

```yaml
resources:
  - base     # directory with kustomization.yaml
  - service.yaml
  - git@github.com:prometheus-operator/prometheus-operator.git?ref=master # git:: deprecated
  - https://github.com/mongodb/mongodb-kubernetes-operator.git//config/default
```
* [Components][5] like resources but can be included from multiple overlays,
  transformers (patches) are applied on resources included from different sources

## Generators & Transfomers

* Fundamental concepts - not used directly
* configMapGenerator and secretGenerator - implementations of Generator
* HelmChartInflator is special kind of Generator with [limited support][6]
* images, namespace, replicas, patches, ... - implementations of Transformer

## Patches

* choose target using mostly its `kind` and `name` or `labelSelector`
* anchored regex for `name` and `namespace` fields
* patch can be a file or inline string

### JSON Patch

* for brief syntax
* Jsonpointer [[RFC-6901](https://datatracker.ietf.org/doc/html/rfc6901)]
  * `/` delimited json path with `~` encoded as `~0`,
    `/` encoded as `~1`
  * cannot address list item by its value
* Jsonpatch [[RFC-6902](https://datatracker.ietf.org/doc/html/rfc6902)]
  * add, replace, remove; `-` append at the end of list

### JSON Patch example

```yaml
  - target:
      kind: Deployment
      name: my-(back|front)end
    patch: |-
      - op: add
        path: /spec/template/spec/volumes/-
        value:
          name: import
          persistentVolumeClaim:
            claimName: import
      - op: add
        path: /spec/template/spec/containers/0/volumeMounts/-
        value:
          name: import
          mountPath: /data/import
      - op: replace
        path: "/metadata/annotations/haproxy.org~1forwarder-for"
        value: "true"
```

### Strategic Merge

* verbose yet precise
* unknown resource treated as json merge [[RFC-7389](https://datatracker.ietf.org/doc/html/rfc7386)]
* can delete whole yaml objects using the special key `$patch: delete`

### Strategic Merge Patch example

* Delete whole resource
```yaml
- target:
    kind: Service
    name: cilium-agent
  patch: |-
    kind: Service
    metadata:
      name: cilium-agent
    $patch: delete
```
* provide context so [SMP][10] knows what to change
* `metadata.name` is required but not used.

## Replacemets

* replace resource value with value from other resource

| - | + |
| ---- | ---- |
| the source resource must be part of applied manifest | can address list item by content |
|   | multiple targets |
|   | partial string replacement |

### Replacement example

```yaml
replacements:
  - source:
      kind: Namespace
      fieldPath: metadata.name
    targets:
      - select:
          kind: RoleBinding
        fieldPaths:
          - subjects.[name=etndevel].namespace
```

## Extras

* `kubectl diff -k` is noisy
  ```bash
  kubectl kustomize --enable-helm |
  kubectl diff -f - |
  grep -v -e "f:[[:alnum:]]" -e "k:[^[:alnum:]]" -e "\.: {}" \
       -e "^-    app.kubernetes.io/instance:" -e "^-  labels:"
  ```
* `kustomize localize` resolve remote dependencies
* helmChart Inflator (wait for more)
* [KRM functions][9] little containers that help build final manifests

### HelmChart inflator

* kustomization approach is buggy [#4593][7]
* use generators with manifest of kind: HelmChartInflationGenerator
* use with `--enable-helm`
* local charts directory not [pulled][8] if present
* generated template can be used as any kustomize base

#

![[Diagram from the wild](diagram/k8s_simple.dot)](diagram/k8s_simple.svg){ height=550px }

# Q&A

> Created with pandoc and reveal.js, from markdown to interactive html;  
> can be printed to PDF.

> Petr Studený @dosmanak

[1]: https://kubernetes.io/docs/reference/using-api/server-side-apply/#merge-strategy
[2]: https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/
[3]: https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_module.html
[4]: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
[5]: https://github.com/kubernetes/enhancements/tree/master/keps/sig-cli/1802-kustomize-components
[6]: https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/helmcharts/
[7]: https://github.com/kubernetes-sigs/kustomize/issues/4593
[8]: https://github.com/kubernetes-sigs/kustomize/blob/master/examples/chart.md#how-does-the-pull-work
[9]: https://github.com/kubernetes-sigs/kustomize/blob/master/cmd/config/docs/api-conventions/functions-spec.md
[10]: https://github.com/kubernetes/community/blob/master/contributors/devel/sig-api-machinery/strategic-merge-patch.md


