SKIPUNZIP=1

type flash_image >/dev/null 2>&1 || flash_image() { flash_boot_image "$@"; }

type find_magisk_apk >/dev/null 2>&1 || find_magisk_apk() { find_manager_apk; }
type find_manager_apk >/dev/null 2>&1 || find_manager_apk() {
  local DBAPK
  [ -z $APK ] && APK=/data/adb/magisk.apk
  [ -f $APK ] || APK=/data/magisk/magisk.apk
  [ -f $APK ] || APK=/data/app/com.topjohnwu.magisk*/*.apk
  [ -f $APK ] || APK=/data/app/*/com.topjohnwu.magisk*/*.apk
  if [ ! -f $APK ]; then
    DBAPK=$(magisk --sqlite "SELECT value FROM strings WHERE key='requester'" 2>/dev/null | cut -d= -f2)
    [ -z $DBAPK ] && DBAPK=$(strings /data/adb/magisk.db | grep -oE 'requester..*' | cut -c10-)
    [ -z $DBAPK ] || APK=/data/user_de/*/$DBAPK/dyn/*.apk
    [ -f $APK ] || [ -z $DBAPK ] || APK=/data/app/$DBAPK*/*.apk
  fi
  [ -f $APK ] || ui_print "! Unable to detect Magisk app APK for BootSigner"
}

bootsign_test() {
  if [ -f $APK ]; then
    eval $BOOTSIGNER -verify < $BOOTIMAGE && BOOTSIGNED=true
    $BOOTSIGNED && ui_print "- Image is signed with AVB 1.0"
  fi
}

unpack_slot() {
  name=boot
  $RECOVERYMODE && name=recovery

  find_boot_image

  ui_print "- Unpacking $name$SLOT image"
  $MAGISKBIN/magiskboot --unpack "$BOOTIMAGE" || abort "! Unable to unpack image"

  bootsign_test
}

# current SLOT should already be set by mount_partitions() in module backend
[ -z $SLOT ] && abort "! Flashable on A/B slot devices only"

# resolve APK for BOOTSIGNER functionality
find_magisk_apk

# we need RECOVERYMODE resolved for find_boot_image()
getvar RECOVERYMODE
find_block recovery$SLOT >/dev/null 2>&1 && RECOVERYMODE=true
[ -z $RECOVERYMODE ] && RECOVERYMODE=false

# ensure we're in a working scratch directory
[ -z $TMPDIR ] && TMPDIR=/dev/tmp
rm -rf $TMPDIR
mkdir -p $TMPDIR
cd $TMPDIR

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

  bootsign_test

  ui_print "- Replacing recovery$SLOT with TWRP backup"
else
  unpack_slot

  ui_print "- Replacing ramdisk with TWRP backup"
  mv -f ramdisk.cpio.orig ramdisk.cpio

  ui_print "- Repacking boot image"
  $MAGISKBIN/magiskboot --repack "$BOOTIMAGE" || abort "! Unable to repack image"

  $MAGISKBIN/magiskboot --cleanup
fi

blockdev --setrw "$BOOTIMAGE" 2>/dev/null
flash_image new-boot.img "$BOOTIMAGE"

cd /
$BOOTMODE || recovery_cleanup
rm -rf $TMPDIR $MODPATH new-boot.img

ui_print "- Done"
exit 0

