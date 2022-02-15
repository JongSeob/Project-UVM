
class cfg_lcr extends uvm_reg;
    rand uvm_reg_field bits;
    rand uvm_reg_field stop_bits;
    rand uvm_reg_field parity_en;
    rand uvm_reg_field dll; // Divisor Latch Access Bit (DLAB)

    `uvm_object_utils(cfg_lcr)

    function new(string name="cfg_lcr");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
    endfunction: new

    // Build all register field objects
    virtual function void build();
        this.bits = uvm_reg_field::type_id::create("bits", , get_full_name());
        this.stop_bits = uvm_reg_field::type_id::create("stop_bits", , get_full_name());
        this.parity_en = uvm_reg_field::type_id::create("parity_en", , get_full_name());
        this.dll = uvm_reg_field::type_id::create("dll", , get_full_name());

        // configure (parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible); 
        this.bits.configure      (this, 2, 0, "RW", 0, 2'h0, 1, 0, 1);
        this.stop_bits.configure (this, 1, 2, "RW", 0, 2'h0, 1, 0, 1);
        this.parity_en.configure (this, 1, 3, "RW", 0, 2'h0, 1, 0, 1);
        this.dll.configure       (this, 1, 7, "RW", 0, 2'h0, 1, 0, 1);
    endfunction
endclass

// These registers are grouped together to form a register block called "cfg"
class block_cfg extends uvm_reg_block;
    rand cfg_lcr lcr; // RW
    // ... TODO

    `uvm_object_utils(block_cfg)

    function new(string name = "block_cfg");
        super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction

    virtual function void build();
        //create_map(string name, uvm_reg_addr_t base_addr, int unsigned n_bytes, uvm_endianness_e endian, bit byte_addressing = 1)
        this.default_map = create_map("",0,4,UVM_LITTLE_ENDIAN,0);

        // lcr
        this.lcr = cfg_lcr::type_id::create("lcr",,get_full_name());
        this.lcr.configure(this , null , "regs_q[3]");
        this.lcr.build();
        this.default_map.add_reg(this.lcr, `UVM_REG_ADDR_WIDTH'h3, "RW", 0);

        // .... TODO

    endfunction
endclass

// The register block is placed in the top level model class definition
class reg_model extends uvm_reg_block;
    rand block_cfg cfg;

    `uvm_object_utils(reg_model)
    function new(string name = "reg_model");
        super.new(name);
    endfunction

    function void build();
        this.default_map = create_map("", 0, 4, UVM_LITTLE_ENDIAN, 0);
        this.cfg = block_cfg::type_id::create("cfg",,get_full_name());
        //                 parent , hdl_path
        this.cfg.configure(this   , "tb.dut");
        this.cfg.build();
        this.default_map.add_submap(this.cfg.default_map, `UVM_REG_ADDR_WIDTH'h0);

        add_hdl_path(""); // <- ??
    endfunction
endclass