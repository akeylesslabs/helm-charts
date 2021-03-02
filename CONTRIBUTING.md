# Contributing Guidelines

Contributions are welcome via GitHub pull requests. This document outlines the process to help get your contribution accepted.

## How to Contribute

1. Fork this repository, develop, and test your changes
2. Submit a pull request

### Technical Requirements

* Any changes to a chart require a version bump following [semver](https://semver.org/) principles. See [Immutability](#immutability) and [Versioning](#versioning) below.

Once the changes have been merged, a release job will automatically run to package and release the changed charts.

### Immutability

Chart releases must be immutable. Any change to a chart warrants a chart version bump even if there are only documentation changes.

### Versioning

The chart `version` should follow [semver](https://semver.org/).

Charts should start at `1.0.0`. Any breaking (backwards incompatible) changes to a chart should:

1. Bump the MAJOR version
2. In the README, under a section called "Upgrading", describe the manual steps necessary to upgrade to the new (specified) MAJOR version
