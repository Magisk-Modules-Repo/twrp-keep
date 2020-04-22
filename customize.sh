##########################################################################################
#
# Magisk Module Installer Script
#
##########################################################################################

##########################################################################################
# Installation Message
##########################################################################################

# Set what you want to display when installing your module

print_modname() {
  ui_print "*******************************"
  ui_print "   TWRP A/B Retention Script   "
  ui_print "  by osm0sis @ xda-developers  "
  ui_print "*******************************"
}

##########################################################################################
# Custom Functions
##########################################################################################

type flash_image >/dev/null 2>&1 || flash_image() { flash_boot_image "$@"; }

type find_manager_apk >/dev/null 2>&1 || find_manager_apk() {
  [ -z $APK ] && APK=/data/adb/magisk.apk
  [ -f $APK ] || APK=/data/magisk/magisk.apk
  [ -f $APK ] || APK=/data/app/com.topjohnwu.magisk*/*.apk
  if [ ! -f $APK ]; then
    DBAPK=`magisk --sqlite "SELECT value FROM strings WHERE key='requester'" 2>/dev/null | cut -d= -f2`
    [ -z $DBAPK ] && DBAPK=`strings /data/adb/magisk.db | grep 5requester | cut -c11-`
    [ -z $DBAPK ] || APK=/data/user_de/*/$DBAPK/dyn/*.apk
    [ -f $APK ] || [ -z $DBAPK ] || APK=/data/app/$DBAPK*/*.apk
  fi
  [ -f $APK ] || ui_print "! Unable to detect Magisk Manager APK"
}

unpack_slot() {
  find_boot_image

  ui_print "- Unpacking boot$SLOT image"
  $MAGISKBIN/magiskboot --unpack "$BOOTIMAGE" || abort "! Unable to unpack boot image"

  eval $BOOTSIGNER -verify < $BOOTIMAGE && BOOTSIGNED=true
  $BOOTSIGNED && ui_print "- Boot image is signed with AVB 1.0"
}

##########################################################################################
# Install
##########################################################################################

$BOOTMODE || abort "*** Flashable manually from Magisk Manager only! ***"

print_modname

# leave this message for credit since we hijack the rest of the install from the backend ;)
ui_print "******************************"
ui_print "Powered by Magisk (@topjohnwu)"
ui_print "******************************"

# current SLOT should already be set by mount_partitions() in module backend
[ -z $SLOT ] && abort "! Flashable on A/B slot devices only"

# resolve APK for BOOTSIGNER functionality
find_manager_apk

# we need RECOVERYMODE resolved for find_boot_image()
getvar RECOVERYMODE
[ -z $RECOVERYMODE ] && RECOVERYMODE=false

unpack_slot

$MAGISKBIN/magiskboot --cpio ramdisk.cpio "extract twres $TMPDIR" 2>/dev/null || abort "! TWRP ramdisk not found"

ui_print "- Backing up TWRP ramdisk"
cp -f ramdisk.cpio ramdisk.cpio.orig

$MAGISKBIN/magiskboot --cleanup

# switch to alternate SLOT for remaining partition actions
case $SLOT in
  _a) SLOT=_b;;
  _b) SLOT=_a;;
esac

unpack_slot

ui_print "- Replacing ramdisk with TWRP backup"
mv -f ramdisk.cpio.orig ramdisk.cpio

ui_print "- Repacking boot image"
$MAGISKBIN/magiskboot --repack "$BOOTIMAGE" || abort "! Unable to repack boot image"

$MAGISKBIN/magiskboot --cleanup

flash_image new-boot.img "$BOOTIMAGE"

rm -rf $TMPDIR new-boot.img

ui_print "- Done"
exit 0
