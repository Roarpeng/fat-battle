#!/bin/bash
# Query authoritative NS for the domain's A record
NS=$(dig +short A ns1.dpdns.org @223.5.5.5 | head -1)
echo "NS1_IP=$NS"
if [ -n "$NS" ]; then
  echo "--- A record from authoritative NS ---"
  dig +short A roarpeng.dpdns.org "@$NS"
fi
echo "--- via alidns ---"
dig +short A roarpeng.dpdns.org @223.5.5.5
echo "--- local resolve ---"
getent hosts roarpeng.dpdns.org || echo "no local record"
