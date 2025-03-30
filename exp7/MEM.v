`include "mycpu_top.h"
module MEM(
    input clk,
    input reset,

    input [`EXE_TO_MEM_BUS_WIDTH-1:0] exe_to_mem_bus,
    output [`MEM_TO_WB_BUS_WIDTH-1:0] mem_to_wb_bus,

    //data bram interface
    input  wire [31:0] data_sram_rdata,

    // pipeline control
    input wire wb_allow_in,
    output wire mem_allow_in,
    input wire exe_to_mem_valid,
    output wire mem_to_wb_valid
);
// pipeline control
reg mem_valid;
wire mem_ready_go = 1'b1;

assign mem_to_wb_valid = mem_valid && mem_ready_go;
assign mem_allow_in = !mem_valid || (mem_ready_go && wb_allow_in) ;// 到后面这个条件，其实隐含了exe_valid = 1

always @(posedge clk) begin
    if(reset) begin
        mem_valid = 1'b0;
    end else if(mem_allow_in) begin
        mem_valid = exe_to_mem_valid;
    end
end

// pipeline reg
// exe_to_mem_bus
reg [`EXE_TO_MEM_BUS_WIDTH-1:0] mem_reg;

always @(posedge clk) begin
    mem_reg <= exe_to_mem_bus;
end


wire [31:0] alu_result;
wire [31:0] final_result;

wire res_from_mem;
wire gr_we;
wire [4:0] dest;
wire [31:0] mem_pc;

assign {
    alu_result,
    res_from_mem,
    gr_we,
    dest,
    mem_pc
} = mem_reg;

// output mem_to_wb_bus
// 1 + 5 + 32 + 32 = 70
assign mem_to_wb_bus = {
    gr_we,
    dest,
    final_result,
    mem_pc
};

// MEM stage
wire [31:0] mem_result;

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

endmodule //MEM
