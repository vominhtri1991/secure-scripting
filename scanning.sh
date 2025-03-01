#!/usr/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.cfg"
receive_email=$(cat $CONFIG_FILE)
HOST_KNOWN=$(cat ${SCRIPT_DIR}/HOST_KNOWN.cfg)
SUBNET_LIST="${SCRIPT_DIR}/subnet.cfg"
NEW_DEVICE="${SCRIPT_DIR}/new_device.txt"
echo $NEW_DEVICE

sending_email()
{
	# Cấu hình thông tin email
	TO=$receive_email
	SUBJECT=${1}
	BODY=${2}
	ATTACHMENT="${3}"
	BOUNDARY="===============`date +%s`=="
	FILENAME=$(basename "$ATTACHMENT")
	MIMETYPE=$(file --mime-type -b "$ATTACHMENT")

	{	
  	# Các header của email
  	echo "From: $FROM"
  	echo "To: $TO"
  	echo "Subject: $SUBJECT"
  	echo "MIME-Version: 1.0"
  	echo "Content-Type: multipart/mixed; boundary=\"$BOUNDARY\""
  	echo ""
  	# Không cần preamble để tránh gây nhầm lẫn

  	# Phần 1: Nội dung email dạng text
  	echo "--$BOUNDARY"
  	echo "Content-Type: text/plain; charset=utf-8"
  	echo "Content-Transfer-Encoding: 7bit"
  	echo ""
  	echo "$BODY"
  	echo ""

  	# Phần 2: Đính kèm
  	echo "--$BOUNDARY"
  	echo "Content-Type: $MIMETYPE; name=\"$FILENAME\""
  	echo "Content-Transfer-Encoding: base64"
  	echo "Content-Disposition: attachment; filename=\"$FILENAME\""
  	echo ""
  	base64 "$ATTACHMENT"
  	echo ""

  	# Kết thúc MIME
  	echo "--$BOUNDARY--"
	} | msmtp "$TO"

}

arp_scanning()
{
	> $NEW_DEVICE
	while read -r subnet; do
    		echo "Scanning: $subnet"

    		scan_output=$(sudo arp-scan "$subnet" | tail -n +3)

    		echo "$scan_output" | awk '/^([0-9]+\.){3}[0-9]+/ {print $1, $2}' | while read -r ip mac; do
        	if ! echo "$HOST_KNOWN" | grep -qi "$mac"; then
			OPEN_PORTS=$(timeout 9s nmap -p- --open -T4 "$ip" | awk '/^[0-9]+\/tcp/ {print $1}' | tr '\n' ' ')
            		echo "New device  connect to network $subnet: IP $ip, MAC $mac, Open Ports: $OPEN_PORTS"
            		echo "$ip $mac Open Ports: $OPEN_PORTS" >> $NEW_DEVICE
        	fi
    		done

	done < $SUBNET_LIST


}	

result_action()
{
	if [ -s $NEW_DEVICE ]; then
		sending_email "NEW DEVICES IS CONNECTING TO NETWORK!!!" "We scan and detect new devices alredy connected to your network. Check detail include IP + MAC address and opening ports in attachment file" "$NEW_DEVICE"
	fi
}
	
arp_scanning
result_action

