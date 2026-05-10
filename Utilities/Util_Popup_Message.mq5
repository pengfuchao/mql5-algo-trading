//+------------------------------------------------------------------+
//|                                             Util_Popup_Message.mq5 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   string TradeInformtion="Buy";
   PlaySound("alert.wav");
   int MsgBoxInfo=MessageBox("市場發出交易指令："+TradeInformtion+"\n"+"是否交易？",
                             "交易提示視窗", MB_YESNO | MB_ICONWARNING);
   Print("返回資訊：", MsgBoxInfo);
  }
