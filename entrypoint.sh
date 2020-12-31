#! /bin/bash
set -ex
if [[ -z "${SERVER_PORT}" ]]; then
  SERVER_PORT="2333"
fi
echo ${SERVER_PORT}

if [[ -z "${SNI_BUG}" ]]; then
  SNI_BUG="youtube.com"
fi
echo ${SNI_BUG}

if [[ -z "${VER}" ]]; then
  VER="latest"
fi
echo ${VER}

if [[ -z "${UUID}" ]]; then
  UUID="ffc17112-b755-499d-be9f-91a828bd3197"
fi
echo ${UUID}

if [[ -z "${AlterID}" ]]; then
  AlterID="64"
fi
echo ${AlterID}

if [[ -z "${V2_Path}" ]]; then
  V2_Path="/static"
fi
echo ${V2_Path}

if [[ -z "${V2_QR_Path}" ]]; then
  V2_QR_Path="qr_img"
fi
echo ${V2_QR_Path}

rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
date -R


if [ "$VER" = "latest" ]; then
  V2RAY_URL="https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip"
else
  V_VER="v$VER"
  V2RAY_URL="https://github.com/v2fly/v2ray-core/releases/download/$V_VER/v2ray-linux-64.zip"
fi

mkdir /v2raybin
cd /v2raybin
echo ${V2RAY_URL}
wget --no-check-certificate -qO 'v2ray.zip' ${V2RAY_URL}
unzip v2ray.zip
rm -rf v2ray.zip

C_VER="v2.2.1"
mkdir /caddybin
cd /caddybin
CADDY_URL="https://github.com/caddyserver/caddy/releases/download/$C_VER/caddy_${C_VER}_linux_amd64.tar.gz"
echo ${CADDY_URL}
wget --no-check-certificate -qO 'caddy.tar.gz' ${CADDY_URL}
tar xvf caddy.tar.gz
rm -rf caddy.tar.gz
chmod +x caddy

cd /wwwroot
tar xvf wwwroot.tar.gz
rm -rf wwwroot.tar.gz

cat <<-EOF > /v2raybin/config.json
{
  "policy": null,
  "log": {
    "access": "",
    "error": "",
    "loglevel": "warning"
  },
    "inbound":{
        "protocol":"vmess",
        "listen":"127.0.0.1",
        "port":$SERVER_PORT,
        "settings":{
            "clients":[
                {
                    "id":"${UUID}",
                    "level":1,
                    "alterId":${AlterID}
                }
            ]
        },
        "streamSettings":{
           	 "network":"ws",
	    	"security": "tls",
            	"tlsSettings": {
          	"allowInsecure": true,
          	"serverName": $SNI_BUG
        },
            "wsSettings":{
                "path":"${V2_Path}"
		"connectionReuse": true,
		"headers": {
            		"Host": "youtube.com"
         	 }
            }
        }
    },
    "outbound":{
        "protocol":"freedom",
        "settings":{
		"domainStrategy": "IPIfNonMatch",
		    "rules": []
        }
    }
}
EOF

echo /v2raybin/config.json
cat /v2raybin/config.json

cat <<-EOF > /caddybin/Caddyfile
http://0.0.0.0:$SERVER_PORT
{
	root /wwwroot
	index index.html
	timeouts none
	proxy ${V2_Path} localhost:$SERVER_PORT {
		websocket
		header_upstream -Origin
	}
}
EOF

cat <<-EOF > /v2raybin/vmess.json
{
    "v": "2",
    "ps": "${AppName}.herokuapp.com",
    "add": "${AppName}.herokuapp.com",
    "port":$SERVER_PORT,
    "id": "${UUID}",
    "aid": "${AlterID}",
    "net": "ws",
    "type": "none",
    "host": "",
    "path": "${V2_Path}",
    "tls": "tls"
}
EOF

if [ "$AppName" = "no" ]; then
  echo "不生成二维码"
else
  mkdir /wwwroot/${V2_QR_Path}
  vmess="vmess://$(cat /v2raybin/vmess.json | base64 -w 0)"
  Linkbase64=$(echo -n "${vmess}" | tr -d '\n' | base64 -w 0)
  echo "${Linkbase64}" | tr -d '\n' > /wwwroot/${V2_QR_Path}/index.html
  echo -n "${vmess}" | qrencode -s 6 -o /wwwroot/${V2_QR_Path}/v2.png
fi

cd /v2raybin
./v2ray -config config.json &
cd /caddybin
./caddy -conf="Caddyfile"
