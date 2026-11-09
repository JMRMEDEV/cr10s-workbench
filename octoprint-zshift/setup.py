# coding=utf-8
from setuptools import setup

plugin_identifier = "zshift"
plugin_package = "octoprint_zshift"
plugin_name = "OctoPrint-ZShift"
plugin_version = "0.1.0"
plugin_description = "Adds a fixed offset to Z of every absolute G0/G1 move before sending to the printer."
plugin_author = "jmrmedev"
plugin_license = "AGPLv3"

try:
    import octoprint_setuptools
except ImportError:
    print("Could not import OctoPrint's setuptools; is OctoPrint's venv active?")
    raise SystemExit(1)

setup_parameters = octoprint_setuptools.create_plugin_setup_parameters(
    identifier=plugin_identifier,
    package=plugin_package,
    name=plugin_name,
    version=plugin_version,
    description=plugin_description,
    author=plugin_author,
    license=plugin_license,
    requires=[],
)

setup(**setup_parameters)
