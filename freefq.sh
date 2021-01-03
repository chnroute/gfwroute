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

html=index.htm
list=$type-list.txt
t=.tmp
n=.new

httpget()
{
    for i in 1 2 3;
    do
        echo ">wget $1 -O $2 ..."
        rm -f $2
        if wget $wgetopt $1 -O $2 2>&1; then
            echo "\n\n=ok"
            return 0
        fi
    done
    echo -e "=\nfail"
    rm -f $2
    return 1
}

convert()
{
    echo '=convert to utf-8 ...'
    iconv -f $1 -t $2 $3 -o $3$n
    echo '=convert to unix ...'
    dos2unix -q $3$n
    mv $3$n $3
}

url=$urlhome/$path/
httpget $url $html$t || exit 0
convert gbk utf8 $html$t


sed -E -i -e 's@[<>]@\n@g' $html$t
sed -E -i -e '\@href="/'$path'/.*\.html@!d' $html$t
sed -E -i -e 's@^.*href="([^"]*)".*@\1@g' $html$t
sed -E -i -e '\@[0-9]{4}/[0-9]{2}/[0-9]{2}@!d' $html$t
path=$(cat $html$t | sort -ru | head -n 1)

url=$urlhome/$path
httpget $url $html$t || exit 0
convert gbk utf8 $html$t

sed -E -i -e '\@href=.*file/(free-ss|free-ssr|v2ray).*\.htm@!d' $html$t

url=$(cat $html$t | head -n 1 | cut -d\" -f 2)
httpget $url $html$t || exit 0
convert gbk utf8 $html$t

if cmp -s $html$t orig-$list; then
    echo '=the original page has not changed.'
    exit 0
fi

sed -E -e 's@[<>,]@\n@g' $html$t > $list$n
sed -E -i -e '\@(ss|ssr|vmess|trojan)://[a-zA-Z0-9+/=%#:-]@!d' $list$n
sed -E -i -e 's@<.*data="@@' -e 's@".*>@@' $list$n

if cmp -s $list$n $list$t; then
    echo '=the content of the original page has not changed.'
    rm -f $list$n
    exit 0
fi

mv $list$n $list$t

if [ "$type" = "v2ray" ]; then
    find . -type f -mtime +7 -delete
    if [ ! -f geoip.tar.gz ]; then
        httpget $urlgeoip geoip.tar.gz
    fi
    if [ ! -f ./GeoLite2-City/GeoLite2-City.mmdb ]; then
        echo '=unpack geoip data ...'
        tar xf geoip.tar.gz --transform='s/_[0-9]*//g'  --wildcards '*.mmdb'
    fi
    if [ -f ./GeoLite2-City/GeoLite2-City.mmdb ]; then
        echo '=get location ...'
        python3 $rootdir/getcity.py $list$t > $list
    fi
    grep -P '^vmess' $list > vmess-list.txt
    grep -P '^trojan' $list > trojan-list.txt
else
    cp $list$t $list
fi

base64 $list > subscribe-$type.txt
mv -f $html$t orig-$list
echo '=OK'
