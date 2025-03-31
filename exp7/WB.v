`include "mycpu_top.h"
module WB(
    input clk,
    input reset,

    // bus
    input [`MEM_TO_WB_BUS_WIDTH-1:0] mem_to_wb_bus,
    output [`WB_TO_ID_BUS_WIDTH-1:0] wb_to_id_bus,

    // pipeline control
    output wire wb_allow_in,
    input wire mem_to_wb_valid,
    
    // debug
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,

    // hazard
    output wire gr_we,
    output reg wb_valid,
    output wire [4:0] dest
);
// pipeline control
// reg wb_valid;
wire wb_ready_go = 1'b1;
wire wb_to_id_valid;

assign wb_allow_in = !wb_valid || (wb_ready_go);
assign wb_to_id_valid = wb_valid && wb_ready_go;

always @(posedge clk) begin
    if(reset) begin
        wb_valid = 1'b0;
    end else if(wb_allow_in) begin
        wb_valid = mem_to_wb_valid;
    end
end

// pipeline reg 
// wb_to_id_bus 
// 1 + 5 + 32 + 32 = 70

// wire gr_we;
// wire [4:0] dest;
wire [31:0] final_result;
wire [31:0] wb_pc;

reg [`MEM_TO_WB_BUS_WIDTH-1:0] wb_reg;

always @(posedge clk) begin
    wb_reg <= mem_to_wb_bus;
end

assign {
    gr_we,
    dest,
    final_result,
    wb_pc
} = wb_reg;

// output id_to_wb_bus
wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;

assign wb_to_id_bus = {
    rf_we,
    rf_waddr,
    rf_wdata
};

// WB stage
assign rf_we    = wb_to_id_valid ? gr_we : 1'b0;
assign rf_waddr = dest;
assign rf_wdata = final_result;

// debug interface
assign debug_wb_pc = wb_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

endmodule //WB
