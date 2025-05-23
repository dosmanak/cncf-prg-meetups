pandoc --verbose -s --slide-level=3 --highlight-style=zenburn -t revealjs -V revealjs-url=https://unpkg.com/reveal.js kustomize_deepdive.md -o kustomize_deepdive.html
dot -Tsvg diagram/k8s_simple.dot -o diagram/k8s_simple.svg
