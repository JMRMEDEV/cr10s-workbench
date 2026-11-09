# coding=utf-8
"""
OctoPrint-ZShift
Middleware plugin: adds a fixed offset to the Z of every absolute G0/G1 move
before it reaches the printer. Works around firmware that ignores M851/M206/G92.
"""
from __future__ import absolute_import
import re
import octoprint.plugin

# Match a Z word (e.g. Z0.28, Z10, Z-1.5, Z.5) in a gcode line.
_Z_RE = re.compile(r"(?i)\bZ(-?\d*\.?\d+)")
# G0/G1 at the start of the (stripped) command.
_MOVE_RE = re.compile(r"(?i)^\s*G[01](\s|$)")


class ZShiftPlugin(
    octoprint.plugin.SettingsPlugin,
    octoprint.plugin.AssetPlugin,
    octoprint.plugin.TemplatePlugin,
):
    def __init__(self):
        # Track absolute (G90) vs relative (G91) positioning; printers boot absolute.
        self._absolute = True

    # ---- SettingsPlugin ----
    def get_settings_defaults(self):
        return dict(enabled=True, z_offset=0.9)

    def get_template_configs(self):
        return [dict(type="settings", custom_bindings=False)]

    # ---- the middleware hook ----
    # Called for every command QUEUED to be sent to the printer.
    # Returning None = leave unchanged; returning a string/list = rewrite.
    def rewrite_z(self, comm_instance, phase, cmd, cmd_type, gcode, *args, **kwargs):
        if not cmd:
            return

        stripped = cmd.strip()

        # Track positioning mode so we never offset a *relative* Z step.
        upper = stripped.upper()
        if upper.startswith("G90"):
            self._absolute = True
            return
        if upper.startswith("G91"):
            self._absolute = False
            return

        if not self._settings.get_boolean(["enabled"]):
            return
        if not self._absolute:
            return  # don't touch relative moves
        if not _MOVE_RE.match(stripped):
            return  # only G0/G1

        m = _Z_RE.search(stripped)
        if not m:
            return  # no Z word -> leave as-is

        try:
            offset = float(self._settings.get(["z_offset"]))
        except (TypeError, ValueError):
            return
        if offset == 0.0:
            return

        z = float(m.group(1))
        new_z = z + offset

        # Replace just the Z value, preserving the rest of the command.
        new_cmd = stripped[: m.start()] + "Z{:.4f}".format(new_z) + stripped[m.end():]
        return [new_cmd]

    def get_update_information(self):
        return dict(
            zshift=dict(
                displayName="ZShift",
                displayVersion=self._plugin_version,
                type="github_release",
                user="local",
                repo="OctoPrint-ZShift",
                current=self._plugin_version,
            )
        )


__plugin_name__ = "ZShift"
__plugin_pythoncompat__ = ">=3.7,<4"


def __plugin_load__():
    global __plugin_implementation__
    __plugin_implementation__ = ZShiftPlugin()

    global __plugin_hooks__
    __plugin_hooks__ = {
        "octoprint.comm.protocol.gcode.queuing": __plugin_implementation__.rewrite_z,
    }
