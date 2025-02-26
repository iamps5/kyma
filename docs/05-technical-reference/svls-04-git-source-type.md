---
title: Git source type
---

Depending on a runtime you use to build your Function (Node.js or Python), your Git repository must contain at least a directory with these files:

- `handler.js` or `handler.py` with Function's code
- `package.json` or `requirements.txt` with Function's dependencies

The Function CR must contain **spec.source.gitRepository** to specify that you use a Git repository for the Function's sources.

To create a Function with the Git source, you must:

1. Create a [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) (optional, only if you must authenticate to the repository).
2. Create a [Function CR](./00-custom-resources/svls-01-function.md) with your Function definition and references to the Git repository.

>**NOTE:** For detailed steps, see the tutorial on [creating a Function from Git repository sources](../03-tutorials/00-serverless/svls-02-create-git-function.md).

You can have various setups for your Function's Git source with different:

- Directory structures

  You can specify the location of your code dependencies with the **baseDir** parameter in the Function CR. For example, use `"/"` if you keep the source files at the root of your repository.

- Authentication methods

  You can define with the **spec.source.gitRepository.auth** parameter in the Function CR that you must authenticate to the repository with a password or token (`basic`), or an SSH key (`key`).

- Function's rebuild triggers

  You can use the **spec.source.gitRepository.reference** parameter in the Function CR to define whether the Function Controller must monitor a given branch or commit in the Git repository to rebuild the Function upon their changes.
