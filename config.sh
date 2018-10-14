##########################################################################################
#
# Magisk Module Template Config Script
# by topjohnwu
#
##########################################################################################

##########################################################################################
# Installation Message
##########################################################################################

# Set what you want to show when installing your mod

print_modname() {
  ui_print "*******************************"
  ui_print "   TWRP A/B Retention Script   "
  ui_print "  by osm0sis @ xda-developers  "
  ui_print "*******************************"
}

##########################################################################################
# Custom Functions
##########################################################################################

# This file (config.sh) will be sourced by the main flash script after util_functions.sh
# If you need custom logic, please add them here as functions, and call these functions in
# update-binary. Refrain from adding code directly into update-binary, as it will make it
# difficult for you to migrate your modules to newer template versions.
# Make update-binary as clean as possible, try to only do function calls in it.

find_alt_boot_image() {
  BOOTIMAGE=
  case $SLOT in
    _a) ALTSLOT=_b;;
    _b) ALTSLOT=_a;;
  esac
  if [ ! -z $ALTSLOT ]; then
    BOOTIMAGE=`find_block boot$ALTSLOT ramdisk$ALTSLOT`
  else
    BOOTIMAGE=`find_block boot ramdisk boot_a kern-a android_boot kernel lnx bootimg`
  fi
  if [ -z $BOOTIMAGE ]; then
    # Lets see what fstabs tells me
    BOOTIMAGE=`grep -v '#' /etc/*fstab* | grep -E '/boot[^a-zA-Z]' | grep -oE '/dev/[a-zA-Z0-9_./-]*' | head -n 1`
  fi
}

type flash_boot_image >/dev/null || flash_boot_image() { flash_image "$@"; }

[ -z $APK ] && APK=/data/adb/magisk.apk
[ -f $APK ] || APK=/data/magisk/magisk.apk
[ -f $APK ] || APK=$(echo /data/app/$(strings /data/adb/magisk.db | grep 5requestor | cut -c11-)*/*.apk)
[ -f $APK ] || APK=$(echo /data/app/com.topjohnwu.magisk*/*.apk)

PACKAGE=${APK##*/}
PACKAGE=${APK%.apk}

echo $ZIP | grep "^/data" | grep $PACKAGE >/dev/null || abort "*** Flashable manually from Magisk Manager only! ***"
