#!/bin/sh
pacmd unload-module module-loopback
pacmd load-module module-loopback source=V-Audio.monitor sink=alsa_output.pci-0000_00_1f.3.analog-stereo
pacmd load-module module-loopback source=V-Comms.monitor sink=alsa_output.pci-0000_00_1f.3.analog-stereo
pacmd load-module module-loopback source=V-Music.monitor sink=alsa_output.pci-0000_00_1f.3.analog-stereo
