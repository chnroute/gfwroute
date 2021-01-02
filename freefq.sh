#!/bin/sh

rootdir=$(dirname $0)

type=$1
[ -n "$type" ] || type=ss
date=$2
[ -n "$date" ] && date=$(date '+%s' -d$date)
[ -n "$date" ] || date=$(date '+%s')

wgetopt='-q --dns-timeout=10 --connect-timeout=10 --read-timeout=30 --tries=3 --show-progress --progress=dot'

urlgeoip="https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=$LICENSE_KEY&suffix=tar.gz"

urlhome=https://www.freefq.com
case $type in
    ss|ssr) path=free-$type;;
    v2ray) path=$type;;
    *) echo unknown $type; exit 1;;
esac
url=$urlhome/$path/
wget $wgetopt $url -O index.txt || exit 0
echo
path=$(iconv -f gbk -t utf8 index.txt | dos2unix | sed 's/[<>]/\n/g' | \
    grep 'href="/'$path'/.*\.html' | sed -E 's/^.*href="([^"]*)".*/\1/' | \
    grep -P '\d{4}/\d{2}/\d{2}' | sort -ru | head -n 1)
url=$urlhome/$path
rm -f index.txt
wget $wgetopt $url -O index.txt || exit 0
echo
iconv -f gbk -t utf8 index.txt | dos2unix >index1.txt
mv -f index1.txt index.txt
url=$(grep -P 'href=.*file/(free-ss|free-ssr|v2ray).*\.htm' index.txt|cut -d\" -f 2)
rm -f index.txt
wget $wgetopt $url -O index.txt || exit 0
echo
iconv -f gbk -t utf8 index.txt | dos2unix >index1.txt
mv -f index1.txt index.txt
sed -r -e 's@[<>]@\n@g' index.txt | grep -P '(ss|ssr|vmess|trojan)://[\x20-\x7f]' | grep -Ev '^账号|^ssr链接|^Address' | sed -E 's/ \t/|/g' > $type-list.txt
sed -E -i -e 's@<.*data="@@' -e 's@".*>@@' $type-list.txt
if [ "$type" = "v2ray" ]; then
    if [ ! -f geoip.tar.gz ]; then
        wget $wgetopt $urlgeoip -O geoip.tar.gz
    fi
    if [ ! -f ./GeoLite2-City/GeoLite2-City.mmdb ]; then
        tar xf geoip.tar.gz --transform='s/_[0-9]*//g'  --wildcards '*.mmdb'
    fi
    if [ -f ./GeoLite2-City/GeoLite2-City.mmdb ]; then
        python3 $rootdir/getcity.py $type-list.txt > $type-list1.txt
        mv $type-list1.txt $type-list.txt
    fi
    grep -P '^vmess' $type-list.txt > vmess-list.txt
    grep -P '^trojan' $type-list.txt > trojan-list.txt
fi
base64 $type-list.txt > subscribe-$type.txt
mv -f index.txt orig-$type-list.txt
echo ok
