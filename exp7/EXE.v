`include "mycpu_top.h"
module EXE(
    input clk,
    input reset,

    // bus
    input [`ID_TO_EXE_BUS_WIDTH-1:0] id_to_exe_bus,
    output [`EXE_TO_MEM_BUS_WIDTH-1:0] exe_to_mem_bus,

    // bypass
    output [`EXE_TO_ID_BYPASS_WIDTH-1:0] exe_to_id_bypass_bus,

    // pipeline control
    input wire mem_allow_in,
    output wire exe_allow_in,
    input wire id_to_exe_valid,
    output wire exe_to_mem_valid,
    
    //data bram interface
    output wire        data_sram_en,
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,

    // hazard
    output reg exe_valid
);
// pipeline control
// reg exe_valid;

wire exe_ready_go = 1'b1;

assign exe_to_mem_valid = exe_valid && exe_ready_go;
assign exe_allow_in = !exe_valid || (exe_ready_go && mem_allow_in); // 到后面这个条件，其实隐含了exe_valid = 1

always @(posedge clk) begin
    if(reset) begin
        exe_valid = 1'b0;
    end else if(exe_allow_in) begin
        exe_valid = id_to_exe_valid;
    end
end

// pipeline reg 
// id_to_exe_bus
// 32 + 32 + 32 + 32 + 12 + 1 + 1 + 1 + 1 + 1 + 5 + 1 = 
wire [31:0] exe_pc;
wire [31:0] rj_value;
wire [31:0] imm;
wire [31:0] rkd_value;
wire [11:0] alu_op;
wire src1_is_pc;
wire src2_is_imm;
wire mem_we;
wire res_from_mem;
wire res_until_mem;
wire gr_we;
wire [4:0] dest;

reg [`ID_TO_EXE_BUS_WIDTH-1:0] exe_reg;

always @(posedge clk) begin
    if(id_to_exe_valid && exe_allow_in) begin
        exe_reg <= id_to_exe_bus;
    end
end

assign {
    exe_pc,
    rj_value,
    imm,
    rkd_value,
    alu_op,
    src1_is_pc,
    src2_is_imm,
    mem_we,
    res_from_mem,
    gr_we,
    dest,
    res_until_mem
} = exe_reg;


// output exe_to_mem_bus
//  32 + 1 + 1 + 5 + 32 + 1 = 72
wire [31:0] alu_result;

assign exe_to_mem_bus = {
    alu_result,
    res_from_mem,
    gr_we,
    dest,
    exe_pc
};

// bypass exe_to_id_bus
// 1 + 32 + 1 + 5 = 39
assign exe_to_id_bypass_bus = {
    res_until_mem,
    alu_result,
    gr_we,
    dest
};

// EXE stage
wire [31:0] alu_src1;
wire [31:0] alu_src2;

assign alu_src1 = src1_is_pc  ? exe_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ), // error
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
);

assign data_sram_en    = mem_we | res_from_mem; // ld || sw
assign data_sram_we    = {4{mem_we}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

endmodule //EXE
