# LAN of DOOM respawn plugin
A SourceMod plugin that respawns players after death for CS:S servers.

# Building
Check out the repository and run the ``./build.sh`` script.

# Installation
Copy ``lan_of_doom_respawn.smx`` to your server's
``css/cstrike/addons/sourcemod/plugins`` directory.

# Console Variables

``sm_lanofdoom_respawn_enabled`` If ``1``, players respawn after death. ``1`` by
default.

``sm_lanofdoom_respawn_time`` Time in seconds after which dead players will
respawn. ``2.0`` by default.