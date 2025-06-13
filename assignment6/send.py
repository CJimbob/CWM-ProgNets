#!/usr/bin/python

from scapy.all import Ether, IP, sendp, get_if_hwaddr, get_if_list, TCP, Raw, UDP
import sys
import re
from scapy.all import *

class Order(Packet):
    name = "Order"
    fields_desc = [
    	StrFixedLenField('messageType', 'A', length=1),
        StrFixedLenField("orderID", "12345678", length=8),
        IntField("orderBookID", "1234"),
        StrFixedLenField("side", "B", length=1),  # 'B' or 'S'
        IntField('price', '0'),
        StrFixedLenField('decision', '1', length=1)
    ]
    
bind_layers(Ether, Order, type=0x1234)

class NumParseError(Exception):
    pass

class OpParseError(Exception):
    pass

class Token:
    def __init__(self,type,value = None):
        self.type = type
        self.value = value

def num_parser(s, i, ts):
    pattern = "^\s*([0-9]+)\s*"
    match = re.match(pattern,s[i:])
    if match:
        ts.append(Token('num', match.group(1)))
        return i + match.end(), ts
    raise NumParseError('Expected number literal.')


def op_parser(s, i, ts):
    pattern = "^\s*([-+&|^])\s*"
    match = re.match(pattern,s[i:])
    if match:
        ts.append(Token('num', match.group(1)))
        return i + match.end(), ts
    raise NumParseError("Expected binary operator '-', '+', '&', '|', or '^'.")
    
def make_seq(p1, p2):
    def parse(s, i, ts):
        i,ts2 = p1(s,i,ts)
        return p2(s,i,ts2)
    return parse
    


if __name__ == '__main__':

	while True:
		print("Enter order in format: <messageType> <orderID> <orderBookID> <side> <price>")
		s = input('> ')
		if s.strip().lower() == "quit":
		    break
		try:
		    tokens = s.strip().split()
		    if len(tokens) != 5:
		        raise ValueError("Expected 5 tokens: <messageType> <orderID> <orderBookID> <side> <price>")

		    messageType, orderID, orderBookID, side, price = tokens
		    

		    pkt = Ether(dst="e4:5f:01:84:8c:86", src="0c:37:96:5f:8a:29", type=0x1234) / \
		          Order(messageType=messageType, orderID=orderID, orderBookID=int(orderBookID), side=side, price=int(price), decision=0) 
		    pkt.show()
		    resp = srp1(pkt, iface='enx0c37965f8a29', timeout=2, verbose=False)
		    if resp and Order in resp:
		        print("Received response:")
		        resp[Order].show()
		    else:
		        print("No order response received")

		except Exception as e:
		    print(f"Error: {e}")
