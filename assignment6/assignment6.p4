#include <core.p4>
#include <v1model.p4>

/*
 * Define the headers the program will recognize
 */
typedef bit<48> macAddr_t;


const bit<8> EXECUTEORDER = 0x45;    // 'E'
const bit<8> SELL = 0x53; // 'S'
const bit<8> BUY = 0x42; // 'B'

const bit<16> ORDER = 0x1234;

header order_t {
	bit<64> orderID;
	bit<32> orderBookID;
	bit<8> side;
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
register<bit<32>>(48) buyr;
register<bit<32>>(48) sellr;

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



	action sell() {
		
		bit<32> sellcount;
		sellr.read(sellcount,hdr.order.orderBookID);
		bit<32> buycount;
		buyr.read(buycount,hdr.order.orderBookID);
		sellcount = sellcount + 1;
		sellr.write(hdr.order.orderBookID, sellcount);

		
		if (sellcount < buycount) {
			hdr.order.decision = BUY;
		} else {
			hdr.order.decision = SELL;
		}
		send_back();
	}
	action buy() {
		bit<32> sellcount;
		sellr.read(sellcount, hdr.order.orderBookID);
		bit<32> buycount;
		buyr.read(buycount,hdr.order.orderBookID);
		
		buycount = buycount + 1;
		buyr.write(hdr.order.orderBookID, buycount);

		
		if (sellcount < buycount) {
			hdr.order.decision = BUY;
		} else {
			hdr.order.decision = SELL;
		}
		send_back();
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

        if (hdr.order.isValid()) {
            calculate.apply();
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
