`include "mycpu_top.h"
module ID(
    input clk,
    input reset,
    // bus
    input [`IF_TO_ID_BUS_WIDTH-1:0] if_to_id_bus,
    input [`WB_TO_ID_BUS_WIDTH-1:0] wb_to_id_bus,
    output [`ID_TO_EXE_BUS_WIDTH-1:0] id_to_exe_bus,
    output [`ID_TO_IF_BUS_WIDTH-1:0] id_to_if_bus,

    // bypass
    input [`EXE_TO_ID_BYPASS_WIDTH-1:0] exe_to_id_bypass_bus,
    input [`MEM_TO_ID_BYPASS_WIDTH-1:0] mem_to_id_bypass_bus,

    // pipeline control
    input wire exe_allow_in,
    output wire id_allow_in,
    input wire if_to_id_valid,
    output wire id_to_exe_valid,

    // hazard detection
    input wire exe_valid,
    input wire mem_valid,
    input wire wb_valid
);
// pipeline control
reg id_valid;
wire id_ready_go; 
wire br_cancle;

assign id_to_exe_valid = id_valid && id_ready_go;
assign id_allow_in = !id_valid || (id_ready_go && exe_allow_in); //允许进入：当前流水级为空，或者当前流水级的东西下一周期可以流走（下一周期空了）

always @(posedge clk) begin
    if(reset) begin
        id_valid <= 1'b0;
    end else if(br_cancle) begin // 上一周期计算出br_cancle，他是wire，下一周期还能保持吗
        id_valid <= 1'b0;
    end 
    else if(id_allow_in) begin
        id_valid <= if_to_id_valid; // allow_in 说明该级流水线下一周期就要流走了
    end
end

// pipeline reg
reg [`IF_TO_ID_BUS_WIDTH-1:0] id_reg;

always @(posedge clk) begin
    if(if_to_id_valid && id_allow_in) begin // 握手成功
        id_reg <= if_to_id_bus;
    end
end

wire [31:0] inst;
wire [31:0] id_pc;

assign {
    inst,
    id_pc
} = id_reg;

// output id_to_if_bus
// 1 + 32 = 33
wire        br_taken;
wire [31:0] br_target;

assign id_to_if_bus = {
    br_taken,
    br_target,
    br_cancle
};

// output id_to_exe_bus: pc, rj_value, imm, rkd_value, mem_we(MEM), res_from_mem(MEM)
// 32 + 32 + 32 + 32 + 12 + 1 + 1 + 1 + 1 + 1 + 5 = 150
wire [11:0] alu_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        gr_we;
wire        mem_we;
wire        res_from_mem;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire        res_until_mem; // 在mem阶段才能得到指令的执行结果

assign id_to_exe_bus = {
    id_pc,
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
};

// wb_to_id_bus:
wire wb_rf_we;
wire [4:0] wb_rf_waddr;
wire [31:0] wb_rf_wdata;

assign {
    wb_rf_we,
    wb_rf_waddr,
    wb_rf_wdata
} = wb_to_id_bus;


// ID stage
wire        load_op;
wire        dst_is_r1;
wire        src_reg_is_rd;
wire        rj_eq_rd; // error

wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
// wire        rf_we   ;
// wire [ 4:0] rf_waddr;
// wire [31:0] rf_wdata;

assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];

assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;
    
assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/ {{20{i12[11]}}, i12[11:0]} ; //这里不用ui5，在alu里面取低5位来实现类似的效果

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_until_mem = inst_ld_w;
assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = id_valid && (~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b) && |(dest); // 需要id_valid？ 如果dest为0，不写入
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (wb_rf_we   ),
    .waddr  (wb_rf_waddr),
    .wdata  (wb_rf_wdata)
    );



assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && id_valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (id_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign br_cancle = id_valid && id_ready_go && br_taken;


// bypass
wire exe_res_until_mem;
wire exe_rf_we;
wire [4:0] exe_rf_waddr;
wire [31:0] exe_rf_wdata;

wire mem_rf_we;
wire [4:0] mem_rf_waddr;
wire [31:0] mem_rf_wdata;

assign {exe_res_until_mem, exe_rf_wdata, exe_rf_we, exe_rf_waddr} = exe_to_id_bypass_bus;
assign {mem_rf_wdata, mem_rf_we, mem_rf_waddr} = mem_to_id_bypass_bus;

// hazard detection
wire rf_raddr1_valid; // src is rj
wire rf_raddr2_valid; // src is rk || rd
assign rf_raddr1_valid = id_valid && (!inst_b && !inst_bl && !inst_lu12i_w);
assign rf_raddr2_valid = id_valid && (inst_add_w || inst_sub_w || inst_slt 
                                    || inst_sltu || inst_and || inst_or 
                                    || inst_nor || inst_xor || inst_st_w 
                                    || inst_beq || inst_bne); //st需要读出rd寄存器， beq和bne需要比较rj和ed寄存器的值

assign rf_raddr1_hazard = (rf_raddr1_valid && ((exe_valid && exe_rf_we && (exe_rf_waddr == rf_raddr1))));
assign rf_raddr2_hazard = (rf_raddr2_valid && ((exe_valid && exe_rf_we && (exe_rf_waddr == rf_raddr2))));

assign id_ready_go = ~((rf_raddr1_hazard || rf_raddr2_hazard) && exe_valid && exe_res_until_mem);

// bypass
assign rj_value  =  (exe_valid && exe_rf_we && (exe_rf_waddr == rf_raddr1)) ? exe_rf_wdata:
                    (mem_valid && mem_rf_we && (mem_rf_waddr == rf_raddr1)) ? mem_rf_wdata:
                    (wb_valid && wb_rf_we && (wb_rf_waddr == rf_raddr1)) ? wb_rf_wdata:
                    rf_rdata1;

assign rkd_value =  (exe_valid && exe_rf_we && (exe_rf_waddr == rf_raddr2)) ? exe_rf_wdata:
                    (mem_valid && mem_rf_we && (mem_rf_waddr == rf_raddr2)) ? mem_rf_wdata:
                    (wb_valid && wb_rf_we && (wb_rf_waddr == rf_raddr2)) ? wb_rf_wdata:
                    rf_rdata2;

endmodule //ID
