{ config, lib, pkgs, nixfiles, ... }:

{
	xdg.configFile."waybar/style.css" = { inherit (nixfiles.sassTemplate { name = "waybar-style"; src = ./waybar.sass; }) source; };

#systemd.user.services.waybar.Service.Environment = lib.singleton "NOTMUCH_CONFIG=${config.home.sessionVariables.NOTMUCH_CONFIG}";

	programs.waybar = {
		enable = true;
		systemd.enable = true;
		settings = [{
			height = 10;
			modules-left = [
				"sway/workspaces"
					"sway/mode"
					"sway/window"
			];
			modules-center = [
				"clock#original"
			];
			modules-right = [
				"pulseaudio#icon"
					"pulseaudio"
					"custom/headset-icon"
					"custom/headset"
					"custom/cpu-icon"
					"cpu"
					"custom/memory-icon"
					"memory"
					"temperature#icon"
					"temperature"
					"battery#icon"
					"battery"
					"battery#icon"
					"backlight"
					"backlight"
					"network"
					"idle_inhibitor"
					"custom/konawall"
					"custom/gpg-status"
					"tray"
					];

			modules = {
				"sway/workspaces" = {
					format = "{icon}";
					format-icons = {
						"1" = "1:";
						"2" = "2:";
						"3" = "3:";
					};
				};
				"sway/window" = {
					icon = true;
					icon-size = 12;
					format = "{}";
				};
				tray = {
					icon-size = 12;
					spacing = 2;
				};
				"backlight#icon" = {
					format = "{icon}";
					format-icons = ["" ""];
				};
				backlight = {
					format = "{percent}%";
				};
				"custom/gpg-status" = {
					format = "{}";
					interval = 300;
					return-type = "json";
					exec = "${pkgs.waybar-gpg}/bin/kat-gpg-status";
				};
				"custom/headset-icon" = {
					format = "";
					interval = 60;
					exec-if = "${pkgs.headsetcontrol}/bin/headsetcontrol -c";
					exec = "echo 'mew'";
				};
				"custom/headset" = {
					format = "{}";
					interval = 60;
					exec-if = "${pkgs.headsetcontrol}/bin/headsetcontrol -c";
					exec = "${pkgs.headsetcontrol}/bin/headsetcontrol -b | ${pkgs.gnugrep}/bin/grep Battery | ${pkgs.coreutils}/bin/cut -d ' ' -f2";
				};
				"custom/konawall" = {
					format = "{}";
					interval = "once";
					return-type = "json";
					exec = "${pkgs.waybar-konawall}/bin/konawall-status";
					on-click = "${pkgs.waybar-konawall}/bin/konawall-toggle";
					on-click-right = "systemctl --user restart konawall";
					signal = 8;
				};
				"custom/cpu-icon".format = "";
				cpu.format = "{usage}%";
				"custom/memory-icon".format = "";
				memory.format = "{percentage}%";
				"temperature#icon" = {
					format = "{icon}";
					format-icons = ["" "" ""];
					critical-threshold = 80;
				};
				temperature = {
					format = "{temperatureC}°C";
					critical-threshold = 80;
				};
				idle_inhibitor = {
					format = "{icon}";
					format-icons = {
						activated = "";
						deactivated = "";
					};
				};
				"battery#icon" = {
					states = {
						good = 90;
						warning = 30;
						critical = 15;
					};
					format = "{icon}";
					format-charging = "";
					format-plugged = "";
					format-icons = [ "" "" "" "" "" ];
				};
				battery = {
					states = {
						good = 90;
						warning = 30;
						critical = 15;
					};
					format = "{capacity}%";
					format-charging = "{capacity}%";
					format-plugged = "{capacity}%";
					format-alt = "{time}";
				};
				"pulseaudio#icon" = {
					format = "{icon}";
					format-muted = "婢";
					on-click = "foot pulsemixer";
					format-icons = {
						default = [
							""
								""
								""
						];
					};
				};
				pulseaudio = {
					format = "{volume}%";
					on-click = "foot pulsemixer";
				};
				network = {
					format-wifi = "直";
					format-ethernet = "";
					format-linked = " {ifname} (NO IP)";
					format-disconnected = " DC";
					format-alt = "{ifname}: {ipaddr}/{cidr}";
					tooltip-format-wifi = "{essid} ({signalStrength}%)";
				};
				"clock#original" = {
					format = "{:%a, %F %T}";
					tooltip = true;
					tooltip-format = "{:%A, %F %T %z (%Z)}";
					timezones = [
						"America/Vancouver"
					];
					interval = 1;
				};
			};
		}];
	};
}
