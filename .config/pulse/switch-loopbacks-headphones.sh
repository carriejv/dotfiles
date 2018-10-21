#!/bin/sh
pacmd unload-module module-loopback
pacmd load-module module-loopback source=V-Audio.monitor sink=alsa_output.usb-Corsair_Corsair_VOID_Wireless_Gaming_Dongle-00.analog-stereo
pacmd load-module module-loopback source=V-Comms.monitor sink=alsa_output.usb-Corsair_Corsair_VOID_Wireless_Gaming_Dongle-00.analog-stereo
pacmd load-module module-loopback source=V-Music.monitor sink=alsa_output.usb-Corsair_Corsair_VOID_Wireless_Gaming_Dongle-00.analog-stereo
