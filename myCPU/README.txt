
�ļ��޸���������lab13:

IF_stage.v: ���tlb_flush����ȡָ�߼�

ID_stage.v: ���TLBָ��ִ���ź������߼�

EXE_stage.v: 
��1��ִ��TLBPָ��
��2�����MTC0��TLBPд������

WB_stage.v: 
��1����TLBָ��ִ���źŸ�tlbģ����cp0ģ��
��2��ʵ��tlbģ����cp0ģ�黥��

cp0.v: ���TLB������ؼĴ���

tlb.v: TLBģ��

==================================================================

�ļ��޸���������lab11:

IF_stage.v: 
��1���޸�SRAM�ӿ�Ϊ��SRAM�ӿ�
��2���޸������߼�fs_ready_go
��3�������Ӧ���汣���ױ��ź�fs_bd��fs_inst��nextpc

ID_stage.v: �������ⷢ��ʱIF��ָ��

EXE_stage.v: 
��1���޸�SRAM�ӿ�Ϊ��SRAM�ӿ�
��2���޸������߼�es_ready_go

MEM_stage.v: 
��1���޸�SRAM�ӿ�Ϊ��SRAM�ӿ�
��2���޸������߼�ms_ready_go

cpu_axi_interface.v: ��SRAM-AIXת����