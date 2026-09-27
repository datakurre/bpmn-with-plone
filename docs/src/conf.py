# Configuration file for the Sphinx documentation builder.

import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.abspath("_ext"))

# -- Project information -----------------------------------------------------

project = "BPMN with Plone"
author = "Plone community"
copyright = "2026"  # str(datetime.now().year)

# -- General configuration ---------------------------------------------------

extensions = [
    "myst_parser",
    "sphinx_bpmn",  # in-repo, see _ext/sphinx_bpmn.py
    "sphinx_copybutton",
    "sphinx_design",
]

myst_enable_extensions = [
    "attrs_block",
    "colon_fence",
    "deflist",
]

exclude_patterns = ["_build"]

# The `bpmn-to-image` executable, from the Nix devShell / build environment.
# bpmn_to_image = "bpmn-to-image"
# "interactive" (token simulation), or a static "svg", "png", ...
# bpmn_default_mode = "interactive"

# -- Options for HTML output -------------------------------------------------

html_theme = "plone_sphinx_theme"
html_title = project
html_sidebars = {
    "**": [
        "navbar-logo",
        "search-button-field",
        "sbt-sidebar-nav",
    ]
}
html_theme_options = {
    "article_header_start": ["toggle-primary-sidebar"],
    "logo": {"text": project},
    "navigation_with_keys": True,
    "path_to_docs": "docs/src",
    "repository_branch": "main",
    "show_toc_level": 2,
}
