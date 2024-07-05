# QA Content Examples

This is a place to store content for internal testing & demos. Please keep things organized and well documented in this README file.

## Contents

* [Data Files](data-files/README.md) - Place to store example data files. E.g. csv, parquet.

* [Utilities] (utilities/README.md) - A collection of utilities used to create test data.

* [Workspaces](workspaces/README.md) - Example workspaces/projects.

## Dependencies

In the root of the repository, there are 2 dependency files:

* `requirements.txt` - Python packages needed for the [Workspaces](workspaces/README.md)
  - `pip install -r requirements.txt`

* `DESCRIPTION` - R packages needed for the [Workspaces](workspaces/README.md)
  - `Rscript -e "pak::local_install_dev_deps(ask = FALSE)"`