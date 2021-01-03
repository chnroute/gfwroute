#!/usr/bin/env python3

import sys
import json
import socket
import base64
import pprint
import urllib.parse
import geoip2.database

def get_city(addr):
    iplist = list()
    for i in (1,2,3,4,5):
        try:
            iplist = list({addr[-1][0] for addr in socket.getaddrinfo(addr, 0, 0, 0, 0)})
        except socket.gaierror:
            pass

    if len(iplist) <= 0:
        return '未知'

    addr = iplist.pop()

    client = geoip2.database.Reader(r'./GeoLite2-City/GeoLite2-City.mmdb')
    try:
        response = client.city(addr)
    except geoip2.errors.AddressNotFoundError:
        return '未知'

    city = response.country.names['zh-CN']

    if len(response.subdivisions) > 0:
        if 'zh-CN' in response.subdivisions[0].names:
            city += ' ' + response.subdivisions[0].names['zh-CN']
        else:
            city += ' ' + response.subdivisions[0].names['en']

    if response.city.names:
        if 'zh-CN' in response.city.names:
            city += ' ' + response.city.names['zh-CN']
        else:
            city += ' ' + response.city.names['en']
    return city

def decode_trojan(text):
    pos = text.find('@')
    pos2 = text.find(':')
    addr = text[pos +1:pos2]
    city = get_city(addr)
    pos = text.find('#')
    print('trojan://' + text[:pos] + '#' + urllib.parse.quote(city))
    pass

def decode_vmess(text):
    code = base64.b64decode(text).decode('UTF-8')
    jo = json.loads(code)
    #pprint.pprint(jo['add'])
    jo['ps'] = get_city(jo['add'])
    #pprint.pprint(jo['ps'])
    print('vmess://' + base64.b64encode(json.dumps(jo).encode('UTF-8')).decode('UTF-8'))
    pass

def main():
    for filename in sys.argv[1:]:
        fo = open(filename, 'r')
        while True:
            line = fo.readline()
            if not line:
                break
            pos = line.find('://')
            if pos < 0:
                continue
            schema = line[:pos]
            if schema == 'trojan':
                decode_trojan(line[pos+3:])
            elif schema == 'vmess':
                decode_vmess(line[pos+3:])
            else:
                pass
        fo.close()
    pass

if __name__ == '__main__':
    main()

