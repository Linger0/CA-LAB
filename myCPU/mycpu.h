`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD        34
    `define FS_TO_DS_BUS_WD  66
    `define DS_TO_ES_BUS_WD  173
    `define ES_TO_MS_BUS_WD  163
    `define ES_TO_DS_BUS_WD  39
    `define ES_TO_TLB_BUS_WD 21
    `define TLB_TO_ES_BUS_WD 30
    `define MS_TO_WS_BUS_WD  120
    `define MS_TO_DS_BUS_WD  39
    `define WS_TO_RF_BUS_WD  39
    `define WS_TO_DS_BUS_WD  39
    `define WS_TO_FS_BUS_WD  67
    
    //cp0
    `define CR_INDEX    0
    `define CR_ENTRYLO0 2
    `define CR_ENTRYLO1 3
    `define CR_BADVADDR 8
    `define CR_COUNT    9
    `define CR_ENTRYHI  10
    `define CR_COMPARE  11
    `define CR_STATUS   12
    `define CR_CAUSE    13
    `define CR_EPC      14
    `define CR_CONFIG   16
    
    //excode
    `define EX_INT  5'h00
    `define EX_MOD  5'h01
    `define EX_TLBL 5'h02
    `define EX_TLBS 5'h03
    `define EX_ADEL 5'h04
    `define EX_ADES 5'h05
    `define EX_SYS  5'h08
    `define EX_BP   5'h09
    `define EX_RI   5'h0a
    `define EX_OV   5'h0c
`endif
