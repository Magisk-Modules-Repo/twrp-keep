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

  ui_print "- Unpacking $(basename $BOOTIMAGE) image"
  $MAGISKBIN/magiskboot --unpack "$BOOTIMAGE" || abort "! Unable to unpack image"

  eval $BOOTSIGNER -verify < $BOOTIMAGE && BOOTSIGNED=true
  $BOOTSIGNED && ui_print "- Image is signed with AVB 1.0"
}

$BOOTMODE || abort "*** Flashable manually from Magisk Manager only! ***"

# current SLOT should already be set by mount_partitions() in module backend
[ -z $SLOT ] && abort "! Flashable on A/B slot devices only"

# resolve APK for BOOTSIGNER functionality
find_manager_apk

# we need RECOVERYMODE resolved for find_boot_image()
getvar RECOVERYMODE
find_block recovery$SLOT >/dev/null 2>&1 && RECOVERYMODE=true
[ -z $RECOVERYMODE ] && RECOVERYMODE=false

unpack_slot

$MAGISKBIN/magiskboot --cpio ramdisk.cpio "extract twres $TMPDIR" 2>/dev/null || abort "! TWRP ramdisk not found"

if $RECOVERYMODE; then
  ui_print "- Backing up TWRP image"
  dd if="$BOOTIMAGE" of=new-boot.img bs=1048576
else
  ui_print "- Backing up TWRP ramdisk"
  cp -f ramdisk.cpio ramdisk.cpio.orig
fi

$MAGISKBIN/magiskboot --cleanup

# switch to alternate SLOT for remaining partition actions
case $SLOT in
  _a) SLOT=_b;;
  _b) SLOT=_a;;
esac

if $RECOVERYMODE; then
  find_boot_image

  eval $BOOTSIGNER -verify < $BOOTIMAGE && BOOTSIGNED=true
  $BOOTSIGNED && ui_print "- Image is signed with AVB 1.0"

  ui_print "- Replacing recovery$SLOT with TWRP backup"
else
  unpack_slot

  ui_print "- Replacing ramdisk with TWRP backup"
  mv -f ramdisk.cpio.orig ramdisk.cpio

  ui_print "- Repacking boot image"
  $MAGISKBIN/magiskboot --repack "$BOOTIMAGE" || abort "! Unable to repack image"

  $MAGISKBIN/magiskboot --cleanup
fi

blockdev --setrw "$BOOTIMAGE"
flash_image new-boot.img "$BOOTIMAGE"

rm -rf $TMPDIR $MODPATH new-boot.img

ui_print "- Done"
exit 0

