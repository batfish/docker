**Got questions, feedback, or feature requests? Join our community on [Slack!](https://join.slack.com/t/batfish-org/shared_invite/enQtMzA0Nzg2OTAzNzQ1LTUxOTJlY2YyNTVlNGQ3MTJkOTIwZTU2YjY3YzRjZWFiYzE4ODE5ODZiNjA4NGI5NTJhZmU2ZTllOTMwZDhjMzA)**

# Batfish Docker

This repo has the source files to build `Batfish` and `allinone` docker containers that provide a quick way to start using Batfish.

Follow the [instructions on readthedocs to get started using Batfish](https://pybatfish.readthedocs.io/en/latest/getting_started.html).

## Building and pushing Batfish artifacts

This repo defines a couple buildkite pipelines, including an `upload` pipeline. The `upload` pipeline builds and tests candidate release artifacts: docker images and the Pybatfish wheel.

This pipeline runs several cross-version tests: different versions of Batfish versus different versions of Pybatfish to ensure backward compatibility of new releases.  For example, the pipeline step `:snake: dev <-> :batfish: prod` tests the new Pybatfish Python wheel (dev) versus the most recent release of Batfish (prod). Each of these cross-version checks run the integration tests defined in the [Pybatfish repo](https://github.com/batfish/pybatfish).

### Fixing new-feature tests

The most common cross-version test failure we see comes from adding tests for something not supported in old versions of Batfish or Pybatfish. In this case, the new integration test needs to have a minimum-version annotation ([see details in the Pybatfish developer readme, here](https://github.com/batfish/pybatfish/blob/master/README.dev.md#adding-tests)) attached in order to run the test to only on that version (or later) Batfish and Pybatfish.
