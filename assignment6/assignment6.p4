#include <core.p4>
#include <v1model.p4>

/*
 * Define the headers the program will recognize
 */
typedef bit<48> macAddr_t;


const bit<8> EXECUTE = 0x45;    // 'E'
const bit<8> ADD = 0x41; // 'A'

const bit<8> SELL = 0x53; // 'S'
const bit<8> BUY = 0x42; // 'B'



const bit<16> ORDER = 0x1234;

header order_t {
	bit<8> messageType; // 'E' 'A'
	bit<64> orderID;
	bit<32> orderBookID;
	bit<8> side;
	bit<32> price;
	bit<8> decision;
}



/*
 * Standard Ethernet header
 */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}





/*
 * All headers, used in the program needs to be assembled into a single struct.
 * We only need to declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */
struct headers {
	ethernet_t ethernet;
	order_t order; 
}

/*
 * All metadata, globally used in the program, also  needs to be assembled
 * into a single struct. As in the case of the headers, we only need to
 * declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */

struct metadata {
    /* In our case it is empty */
}

/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            ORDER : parse_order;
            default : accept;
        }
    }

    state parse_order {
        packet.extract(hdr.order);
        transition accept; 
    }

}

/*************************************************************************
 ************   C H E C K S U M    V E R I F I C A T I O N   *************
 *************************************************************************/
control MyVerifyChecksum(inout headers hdr,
                         inout metadata meta) {
    apply { }
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
register<bit<32>>(10) buyr;
register<bit<32>>(10) sellr;


register<bit<32>>(100) buyprice;
register<bit<32>>(100) sellprice;


control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
	action send_back() {
	    
	    macAddr_t tmp;
	    tmp = hdr.ethernet.dstAddr;
	    hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
	    hdr.ethernet.srcAddr = tmp;
	    standard_metadata.egress_spec = standard_metadata.ingress_port;
	}
	
	action execute(bit<8> count, out bit<32> price_r) {
		bit<32> sellcount;
		sellr.read(sellcount,hdr.order.orderBookID);
		bit<32> buycount;
		buyr.read(buycount,hdr.order.orderBookID);
		bit<32> price_r;
		hdr.order.messageType = EXECUTE;
		if (hdr.order.side == BUY) {
			sellprice.read(hdr.order.orderBookID*10 + count, price_r);
			if (price_r < hdr.order.price) {
				hdr.order.decision = 1;
			} 
		}
				
		else if (hdr.order.side == SELL) {
			buyprice.read(hdr.order.orderBookID*10 + count, price_r);
			if (price_r > hdr.order.price) {
				hdr.order.decision = 1;
			} 
		} else {
			hdr.order.decision = 0;
		}
		
	}
	

	action sell() {
		hdr.order.messageType = ADD;
		bit<32> sellcount;
		sellr.read(sellcount,hdr.order.orderBookID);
		bit<32> buycount;
		buyr.read(buycount,hdr.order.orderBookID);
		sellcount = sellcount + 1;
		sellr.write(hdr.order.orderBookID, sellcount);

		sellprice.write(hdr.order.orderBookID*10 + sellcount, hdr.order.price);
		
		
		if (sellcount < buycount) {
			hdr.order.decision = BUY;
		} else {
			hdr.order.decision = SELL;
		}
		send_back();
		execute(0);
	}
	action buy() {
		hdr.order.messageType = ADD;
		bit<32> sellcount;
		sellr.read(sellcount, hdr.order.orderBookID);
		bit<32> buycount;
		buyr.read(buycount,hdr.order.orderBookID);
		
		buycount = buycount + 1;
		buyr.write(hdr.order.orderBookID, buycount);
		
		buyprice.write(hdr.order.orderBookID*10 + buycount, hdr.order.price);
		
		
		if (sellcount < buycount) {
			hdr.order.decision = BUY;
		} else {
			hdr.order.decision = SELL;
		}
		send_back();
		execute(0);
	}
	
	
	action operation_drop() {
		mark_to_drop(standard_metadata);
	    }

    table calculate {
        key = {
            hdr.order.side : exact;
        }
        actions = {
            
            buy;
            sell;
            NoAction;
            operation_drop;
        }
       
        default_action = sell();
        const entries = {
        	SELL : sell();
        	BUY : buy();
        }
    }

    apply {
	bit<8> price_r;
        if (hdr.order.isValid()) {
        	calculate.apply();
		execute(0);
		execute(1);
		execute(2);
		execute(3);
		execute(4);
		execute(5);
		execute(6);
		execute(7);
		execute(8);
		execute(9);
	       	if (price_r > hdr.order.price) {
	       	
	       	}
		
        } else {
            operation_drop();
        }
    }
}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
 *************   C H E C K S U M    C O M P U T A T I O N   **************
 *************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 ***********************  D E P A R S E R  *******************************
 *************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.order);
    }
}

/*************************************************************************
 ***********************  S W I T T C H **********************************
 *************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
