import uvm_pkg::*;
import my_pkg::*;



class JAESIK_agent extends uvm_agent;

	`uvm_component_utils(JAESIK_agent)

	
	JAESIK_drive		m_drv;
	
	
	JAESIK_monitor	m_monitor;
	
	
	JAESIK_sequencer	m_seq;
	
	
	function new(string name, uvm_component parent=null);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		
		m_driver = m_drv::type_id::create("m_driver", this);
		
		
		m_monitor = m_monitor::type_id::create("m_monitor", this);
		
		
		m_seq = m_seq::type_id::create("m_seq", this);
		
	endfunction

endclass

	