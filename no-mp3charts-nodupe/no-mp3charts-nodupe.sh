#!/bin/bash
#bins needed: chroot
#bins needed (chrooted in $GLROOT/bin): find sed cksfv grep bash rescan sleep du

#
# released as a poc v20121201
#

#if you use just one dir for all SOURCE charts, this will be handy for the next part
CHRT_SDIR=/site/mp3/charts/

#if you use just one dir for all DESTINATION charts, this will be handy for the next part
CHRT_DDIR=/site/mp3/sorted/

#CHROOT_DST = chrooted destination
#CHROOT_RLS = chrooted releases (POSIX)
#SHORT_NAME = will be used for sfv/nfo
#
#CHROOT_DST^CHROOT_RLS^SHORTNAME
CHARTS="
${CHRT_DDIR}/US_TOP20_Single_Charts_NO_DUPES-NOTRADE^${CHRT_SDIR}/US_TOP20_Single_Charts_*^us20sc
${CHRT_DDIR}/German_TOP100_Single_Charts_NO_DUPES-NOTRADE^${CHRT_SDIR}/German_TOP100_Single_Charts_*^gt100sc
"


###
# end of config
###

##not needed anymore
#GLCONF=${GLROOT}/etc/glftpd.conf
##extract min_homedir out of glftpd.conf
#MINHOMEDIR="$(grep "min_homedir" "$GLCONF" | grep -E "^[[:space:]]*min_homedir" | grep -o -E "\/.+" )"

for LINE in $CHARTS; do
 CHROOT_CHARTS_DST="$(echo $LINE | cut -d'^' -f1)"
 CHROOT_CHARTS_SRC="$(echo $LINE | cut -d'^' -f2)"
 SHORTNAME="$(echo $LINE | cut -d'^' -f3)"
 SHORTNAME=${SHORTNAME,,}
 ls ${CHROOT_CHARTS_SRC} --ignore={${CHROOT_CHARTS_DST}} >/dev/null 2>&1 && CHK=TRUE || CHK=""
 if ! [[ -z $CHK ]]; then
  #rescan does have some problems with 2k+ files, so we will split it up
  for CHAR in {A..Z} _; do
   mkdir -pm755 "${CHROOT_CHARTS_DST}/${CHAR}/"
   cd "${CHROOT_CHARTS_DST}/${CHAR}/"
   echo -n "${SHORTNAME}_${CHAR}:"
   SEARCH=$CHAR
   #underscore = any non-alpha
   [[ "$CHAR" == "_" ]] &&
    SEARCH="[^a-z]"
   RLSS=$(find ${CHROOT_CHARTS_SRC} -type f -iregex ".+\/[0-9]+[_.-]$SEARCH.+\.mp3$")
   #RLSS=$(find ${CHROOT_CHARTS_SRC} -type f -name "*.mp3")
   for RLS in $RLSS; do
    #rm leading rank, replace any non-alnum to one underscore, except of "_-_" and ".mp3" :)
    DST=$(basename "$RLS" | sed 's/_-_/^/g;s/^[0-9]*\-//g;s/\[^a-Z0-9\^\]\+/_/g;s/_\+mp3$/.mp3/;s/\^/_-_/g')
    if [[ -e "$DST" ]]; then
     echo -n "-"
    else
     echo -n "+"
     ln -s "$RLS" "$DST" >/dev/null 2>&1
     chmod 644 "$DST" >/dev/null 2>&1
     #set timestamp to the RLS time
     touch -acmhr "$RLS" "$DST" >/dev/null 2>&1
     ##sfv needs to look like "file crc" ;/
     #echo -n "$DST " | tr '\n' ' ' >>${CHROOT_CHARTS_DST}/${CHAR}/${SHORTNAME}_${CHAR,,}.sfv
     #crc32 "$RLS">>${CHROOT_CHARTS_DST}/${CHAR}/${SHORTNAME}_${CHAR,,}.sfv
     /bin/cksfv "$DST" | grep -v -E "^;" >>${CHROOT_CHARTS_DST}/${CHAR}/${SHORTNAME}_${CHAR,,}.sfv
    fi
   done
   echo ""
   NFO="$(ls *.mp3|grep -c mp3) releases using $(du -chL | grep total | grep -o -E '^[0-9,.]+[KMGTPEZY]')"
   #if NFO exist with same content, do not write.
   ! [[ "$(cat ${CHROOT_CHARTS_DST}/${CHAR}/${SHORTNAME}_${CHAR,,}.nfo)" == "$NFO" ]] &&
    echo "$NFO" > ${CHROOT_CHARTS_DST}/${CHAR}/${SHORTNAME}_${CHAR,,}.nfo
   #just rescan if there is at least one mp3
   [[ $(ls ${CHROOT_CHARTS_DST}/${CHAR}/*.mp3 | tail -n 1) ]] &&
    /bin/rescan --dir=${CHROOT_CHARTS_DST}/${CHAR}/ >/dev/null 2>&1
  done
  #if NFO exist with same content, do not write.
  cd "${CHROOT_CHARTS_DST}/"
  NFO="$(ls ./*/*.mp3|grep -c mp3) releases using $(du -chL | grep total | grep -o -E '^[0-9,.]+[KMGTPEZY]')"
  ! [[ "$(cat ${CHROOT_CHARTS_DST}/${SHORTNAME}.nfo)" == "$NFO" ]] &&
   echo "$NFO" > ${CHROOT_CHARTS_DST}/${SHORTNAME}.nfo
 fi
done

exit 0

#EoF /1337? yea.. a bit.
