`include "mycpu_top.h"
// 支持指令：    inst_add_w; inst_sub_w; inst_slt; inst_sltu; inst_nor; inst_and; inst_or; inst_xor; inst_slli_w; inst_srli_w; inst_srai_w;
//              inst_addi_w; inst_ld_w; inst_st_w; inst_jirl; inst_b; inst_bl; inst_beq; inst_bne; inst_lu12i_w;
module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

reg         valid; // add for inst valid
always @(posedge clk) begin
    if(reset) begin
        valid = 1'b0;
    end else begin
        valid = 1'b1;
    end
end

// IF
wire [`IF_TO_ID_BUS_WIDTH-1:0] if_to_id_bus;
wire if_to_id_valid;

// ID
wire [`ID_TO_IF_BUS_WIDTH-1:0] id_to_if_bus;
wire [`ID_TO_EXE_BUS_WIDTH-1:0] id_to_exe_bus;
wire id_allow_in;
wire id_to_exe_valid;

// EXE
wire [`EXE_TO_MEM_BUS_WIDTH-1:0] exe_to_mem_bus;
wire exe_allow_in;
wire exe_to_mem_valid;

// MEM
wire [`MEM_TO_WB_BUS_WIDTH-1:0] mem_to_wb_bus;
wire mem_allow_in;
wire mem_to_wb_valid;

// WB
wire [`WB_TO_ID_BUS_WIDTH-1:0] wb_to_id_bus;
wire wb_allow_in;

// hazard
wire exe_valid; //为什么是wire不是reg，因为这里相当于从reg连线出来，这边接收的是wire，起点是reg
wire exe_rf_we;
wire [4:0] exe_rf_waddr;

wire mem_valid;
wire mem_rf_we;
wire [4:0] mem_rf_waddr;

wire wb_valid;
wire wb_rf_we;
wire [4:0] wb_rf_waddr;


IF i_IF(
    .clk(clk),
    .reset(reset),
    .inst_sram_en(inst_sram_en),
    .inst_sram_we(inst_sram_we),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .if_to_id_bus(if_to_id_bus),
    .id_to_if_bus(id_to_if_bus),
    .id_allow_in(id_allow_in),
    .if_to_id_valid(if_to_id_valid)
);


ID i_ID(
    .clk(clk),
    .reset(reset),
    .if_to_id_bus(if_to_id_bus),
    .wb_to_id_bus(wb_to_id_bus),
    .id_to_exe_bus(id_to_exe_bus),
    .id_to_if_bus(id_to_if_bus),
    .exe_allow_in(exe_allow_in),
    .id_allow_in(id_allow_in),
    .if_to_id_valid(if_to_id_valid),
    .id_to_exe_valid(id_to_exe_valid),
    .exe_valid(exe_valid),
    .exe_rf_we(exe_rf_we),
    .exe_rf_waddr(exe_rf_waddr),
    .mem_valid(mem_valid),
    .mem_rf_we(mem_rf_we),
    .mem_rf_waddr(mem_rf_waddr),
    .wb_valid(wb_valid)
);

EXE i_EXE(
    .clk(clk),
    .reset(reset),
    .id_to_exe_bus(id_to_exe_bus),
    .exe_to_mem_bus(exe_to_mem_bus),
    .mem_allow_in(mem_allow_in),
    .exe_allow_in(exe_allow_in),
    .id_to_exe_valid(id_to_exe_valid),
    .exe_to_mem_valid(exe_to_mem_valid),
    .data_sram_en(data_sram_en),
    .data_sram_we(data_sram_we),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .gr_we(exe_rf_we),
    .exe_valid(exe_valid),
    .dest(exe_rf_waddr)
);

MEM i_MEM(
    .clk(clk),
    .exe_to_mem_bus(exe_to_mem_bus),
    .mem_to_wb_bus(mem_to_wb_bus),
    .data_sram_rdata(data_sram_rdata),
    .wb_allow_in(wb_allow_in),
    .mem_allow_in(mem_allow_in),
    .exe_to_mem_valid(exe_to_mem_valid),
    .mem_to_wb_valid(mem_to_wb_valid),
    .gr_we(mem_rf_we),
    .mem_valid(mem_valid),
    .dest(mem_rf_waddr)
);

WB i_WB(
    .clk(clk),
    .reset(reset),
    .mem_to_wb_bus(mem_to_wb_bus),
    .wb_to_id_bus(wb_to_id_bus),
    .wb_allow_in(wb_allow_in),
    .mem_to_wb_valid(mem_to_wb_valid),
    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .gr_we(wb_rf_we),
    .wb_valid(wb_valid),
    .dest(wb_rf_waddr)
);

endmodule
