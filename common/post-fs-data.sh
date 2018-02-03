#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
# This script will be executed in post-fs-data mode
# More info in the main Magisk thread

#Variables
MODPATH=${0%/*}
MODDIR=$(dirname $MODPATH)
COREPATH=$(dirname $MODPATH)/.core
ORIGDIR=/sbin/.core/mirror
PROPFILE=$MODPATH/system.prop
REMPATCH=false
NEWPATCH=false
OREONEW=<OREONEW>
MODS=""

#Functions
cp_mv() {                   
  if [ -z $4 ]; then install -D "$2" "$3"; else install -D -m "$4" "$2" "$3"; fi
  [ "$1" == "-m" ] && rm -f $2
}
patch_cfgs() {
  case $1 in
    *.conf) if [ "$2" == "libraryonly" ]; then
              [ ! "$(sed -n "/^libraries {/,/^}/ {/^ *$3 {/,/}/p}" $1)" ] && sed -i "s|^libraries {|libraries {\n  $3 {\n    path $4\n  }|" $1
            elif [ "$2" == "effectonly" ]; then
              [ ! "$(sed -n "/^effects {/,/^}/ {/^ *$4 {/,/}/p}" $1)" ] && sed -i "s|^effects {|effects {\n  $4 {\n    library $3\n    uuid $5\n  }|" $1
            elif [ "$2" == "outsp" ]; then
              $OREONEW && [ ! "$(sed -n "/^output_session_processing {/,/^}/ {/music {/,/^    }/ {/$3 {/,/}/p}}" $1)" ] && sed -i "/output_session_processing {/,/^}/ {/music {/,/^    }/ s/music {/music {\n        $3 {\n        }/}" $1
            else
              [ ! "$(sed -n "/^libraries {/,/^}/ {/^ *$2 {/,/}/p}" $1)" ] && sed -i "s|^libraries {|libraries {\n  $2 {\n    path $4\n  }|" $1
              [ ! "$(sed -n "/^effects {/,/^}/ {/^ *$3 {/,/}/p}" $1)" ] && sed -i "s|^effects {|effects {\n  $3 {\n    library $2\n    uuid $5\n  }|" $1
            fi;;
    *) if [ "$2" == "libraryonly" ]; then
         [ ! "$(sed -n "/<libraries>/,/<\/libraries>/ {/^ *<library name=\"$3\" path=\"$(basename $4)\"\/>/p}" $1)" ] && sed -i "/<libraries> a\        <library name=\"$3\" path=\"$(basename $4)\"\/>" $1
       elif [ "$2" == "effectonly" ]; then
         [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$4\" library=\"$3\" uuid=\"$5\"\/>/p}" $1)" ] && sed -i "/<effects>/ a\        <effect name=\"$4\" library=\"$(basename $3)\" uuid=\"$5\"\/>" $1
       elif [ "$2" == "outsp" ]; then
         $OREONEW && [ ! "$(sed -n "/<postprocess>/,/<\/postprocess>/ {/<stream type=\"music\">/,/<\/stream>/ {/^ *<apply effect=\"$3\"\/>/p}}" $1)" ] && sed -i "/<postprocess>/,/<\/postprocess>/ {/<stream type=\"music\">/,/<\/stream>/ s/<stream type=\"music\">/<stream type=\"music\">\n            <apply effect=\"$3\"\/>/}" $1
       else
         [ ! "$(sed -n "/<libraries>/,/<\/libraries>/ {/^ *<library name=\"$2\" path=\"$(basename $4)\"\/>/p}" $1)" ] && sed -i "/<libraries> a\        <library name=\"$2\" path=\"$(basename $4)\"\/>" $1
         [ ! "$(sed -n "/<effects>/,/<\/effects>/ {/^ *<effect name=\"$3\" library=\"$2\" uuid=\"$5\"\/>/p}" $1)" ] && sed -i "/<effects>/ a\        <effect name=\"$3\" library=\"$(basename $2)\" uuid=\"$5\"\/>" $1
       fi;;
  esac
}
grep_prop() {
  REGEX="s/^$1=//p"
  shift
  FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  sed -n "$REGEX" $FILES 2>/dev/null | head -n 1
}
main () {
  DIR=$1
  LAST=false; NUM=1
  #Some loop shenanigans so it'll run once or twice depending on supplied DIR
  until $LAST; do
    [ "$1" == "$MODDIR/*/system" -o $NUM -ne 1 ] && LAST=true
    [ $NUM -ne 1 ] && DIR=$MODDIR/*/system
    for MOD in $(find $DIR -maxdepth 0 -type d); do
      $LAST && [ "$MOD" == "$MODPATH/system" ] && continue
      FILES=$(find $MOD -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_policy*.conf" -o -name "*audio_policy*.xml" -o -name "*mixer_paths*.xml")
      [ -z "$FILES" ] && continue
      MODNAME=$(basename $(dirname $MOD))
      $LAST && [ ! "$(grep "$MODNAME" $COREPATH/aml/mods/modlist)" ] && echo "$MODNAME" >> $COREPATH/aml/mods/modlist
      if [ "$MODNAME" == "ainur_sauron" ]; then
        cp_mv -c $MODDIR/$MODNAME/.aml.sh $MODPATH/.scripts/ainur_sauron.sh
        LIBDIR="$(dirname $(find $MODDIR/$MODNAME/system -type f -name "lib*.so" | head -n 1) | sed -e "s|$MODDIR/$MODNAME||" -e "s|/system/vendor|/vendor|")"
        . $MODPATH/.scripts/$MODNAME.sh
        for FILE in ${FILES}; do
          $LAST && cp_mv -m $FILE $COREPATH/aml/mods/$MODNAME/$(echo "$FILE" | sed "s|$MOD|system|")
        done
      elif [ "$MODNAME" == "Udb_Remover" ]; then
        $LAST && { for FILE in ${FILES}; do
                     cp_mv -m $FILE $COREPATH/aml/mods/$MODNAME/$(echo "$FILE" | sed "s|$MOD|system|")
                   done; }
        . $MODPATH/.scripts/$MODNAME.sh
      else
        for FILE in ${FILES}; do
          NAME=$(echo "$FILE" | sed "s|$MOD|system|")
          case $FILE in
            *audio_effects*) for AUDMOD in $(ls $MODPATH/.scripts); do
                               LIB=$(echo "$AUDMOD" | sed -r "s|(.*)~.*.sh|\1|")
                               UUID=$(echo "$AUDMOD" | sed -r "s|.*~(.*).sh|\1|")
                               if [ "$(sed -n "/^libraries {/,/^}/ {/$LIB.so/p}" $FILE)" ] && [ "$(sed -n "/^effects {/,/^}/ {/uuid $UUID/p}" $FILE)" ] && [ "$(find $MODDIR/$MODNAME/system -type f -name "$LIB.so")" ] && [ "$AUDMOD" != "ainur_sauron" ] && [ "$AUDMOD" != "Udb_Remover" ]; then
                                 LIBDIR="$(dirname $(find $MODDIR/$MODNAME/system -type f -name "$LIB.so" | head -n 1) | sed -e "s|$MODDIR/$MODNAME||" -e "s|/system/vendor|/vendor|")"
                                 . $MODPATH/.scripts/$AUDMOD
                               fi
                             done;;
          esac
          $LAST && cp_mv -m $FILE $COREPATH/aml/mods/$MODNAME/$NAME
        done
      fi
      if $LAST && [ -f $(dirname $MOD)/system.prop ]; then
        while read PROP; do
          TPROP=$(echo "$PROP" | sed -r "s/(.*)=.*/\1/")
          if [ ! "$(grep "$TPROP" $PROPFILE)" ]; then
            echo "$PROP" >> $PROPFILE
          elif [ "$(grep "^$TPROP" $PROPFILE)" ] && [ ! "$(grep "^$PROP" $PROPFILE)" ]; then
            sed -i "s|^$TPROP|^#$TPROP|" $PROPFILE
            echo "#$PROP" >> $PROPFILE
          fi
        done < $(dirname $MOD)/system.prop
        cp_mv -m $(dirname $MOD)/system.prop $COREPATH/aml/mods/$MODNAME/system.prop
      fi
    done
    $LAST && [ -s $PROPFILE ] || rm -f $PROPFILE
    NUM=$((NUM+1))
  done
}

#Script logic
#Determine if an audio mod was removed
while read LINE; do
  [ ! -d $MODDIR/$LINE ] && { export MODS="${MODS} $LINE"; REMPATCH=true; }
done < $COREPATH/aml/mods/modlist
#Determine if an audio mod has been added/changed
DIR=$(find $MODDIR/* -type d -maxdepth 0 | sed -e "s|$MODDIR/lost\+found ||g" -e "s|$MODDIR/aml ||g")
[ "$(find $DIR -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_policy*.conf" -o -name "*audio_policy*.xml" -o -name "*mixer_paths*.xml" | head -n 1)" ] && NEWPATCH=true
#Main method
if $REMPATCH; then
  if [ -f $MODPATH/system.prop ]; then > $MODPATH/system.prop; else touch $MODPATH/system.prop; fi
  for MODNAME in ${MODS}; do
    rm -rf $COREPATH/aml/mods/$MODNAME
    sed -i "/$MODNAME/d" $COREPATH/aml/mods/modlist
  done
  if $BOOTMODE && [ -L /system/vendor ]; then 
    FILES="$(find $ORIGDIR/system $ORIGDIR/vendor -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_policy*.conf" -o -name "*audio_policy*.xml" -o -name "*mixer_paths*.xml")"
    for FILE in ${FILES}; do
      NAME=$(echo "$FILE" | sed -e "s|$ORIGDIR||" -e "s|/system/||")
      cp_mv -c $FILE $MODPATH/system/$NAME
    done
  else
    FILES="$(find -L $ORIGDIR/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" -o -name "*audio_policy*.conf" -o -name "*audio_policy*.xml" -o -name "*mixer_paths*.xml")"
    for FILE in ${FILES}; do
      NAME=$(echo "$FILE" | sed "s|$ORIGDIR||")
      cp_mv -c $FILE $MODPATH$NAME
    done
  fi
  if [ -f $ORIGDIR/system/etc/audio_effects.conf ] && [ ! -f $ORIGDIR/system/vendor/etc/audio_effects.conf ]; then
    cp_mv -c $ORIGDIR/system/etc/audio_effects.conf $MODPATH/system/vendor/etc/audio_effects.conf
  fi
  for FILE in $MODPATH/system/etc/audio_effects.conf $MODPATH/system/vendor/etc/audio_effects.conf; do
    if [ -f $FILE ] && [ ! "$(grep '^ *# *music_helper {' $FILE)" ] && [ "$(grep '^ *music_helper {' $FILE)" ]; then
      sed -i "/effects {/,/^}/ {/music_helper {/,/}/ s/^/#/g}" $FILE
    fi
  done
  for FILE in $MODPATH/system/etc/audio_effects.xml $MODPATH/system/vendor/etc/audio_effects.xml; do
    if [ -f $FILE ] && [ ! "$(grep '^ *<\!--<stream type=\"music\">' $FILE)" ] && [ "$(grep '^ *<stream type=\"music\">' $FILE)" ]; then
      sed -i "/^ *<postprocess>$/,/<\/postprocess>/ {/<stream type=\"music\">/,/<\/stream>/ s/<stream type=\"music\">/<\!--<stream type=\"music\">/; s/<\/stream>/<\/stream>-->/}" $FILE
    fi
  done
  main "$COREPATH/aml/mods/*/system"
elif $NEWPATCH; then
  main "$MODDIR/*/system"
fi