//+------------------------------------------------------------------+
//|                                           Util_Extract_Numbers.mq5 |
//+------------------------------------------------------------------+
//[EA]提取字串中的數位
input string mystring="3,5,6,7,9,11,14,15,18,22,32,123,1024";
int MyTimesPosArray[][2]; //定義陣列，其中[n][0]逗號位置,[n][1]數字子串
int cnt,i,j;

int OnInit()
   {
      int myArrayRange = 0, mycnt, mylastpos=1;
      int myLen=StringLen(mystring); //字串長度
      for (cnt=0;cnt<myLen;cnt++) //統計數字子串數量
         {
            mycnt=StringFind(mystring,",",cnt);
            myArrayRange=myArrayRange+1;
            cnt=mycnt;
            if (mycnt==-1) break;
         }
      ArrayResize(MyTimesPosArray,myArrayRange); //定義陣列邊界
      ArrayInitialize(MyTimesPosArray,0); //初始化陣列
      
      i = 0;
      for (cnt=0;cnt<myLen;cnt++) //根據子串數量，計算子串起點
         {
            mycnt=StringFind(mystring,",",cnt);
            MyTimesPosArray[i][0]=mycnt;
            i=i+1;
            cnt=mycnt;
            if (mycnt==-1) 
               {
                  MyTimesPosArray[i-1][0]=myLen;
                  break;
               }
         }
      for (cnt=0;cnt<myArrayRange;cnt++) //根據陣列元素，尋找對應位置賦值
         {
            int prevPos = (cnt == 0) ? -1 : MyTimesPosArray[cnt-1][0];
            int mySubLen = MyTimesPosArray[cnt][0] - prevPos - 1;
            
            string mySub = StringSubstr(mystring, prevPos + 1, mySubLen);
            MyTimesPosArray[cnt][1] = (int)StringToInteger(mySub);
         }
      for (cnt=0;cnt<myArrayRange;cnt++) //列印陣列
         {
            Print("陣列值:"+IntegerToString(MyTimesPosArray[cnt][0])+"  子串:"+IntegerToString(MyTimesPosArray[cnt][1]));
         }
      return(INIT_SUCCEEDED);
   }

void OnTick()
   {
      // ...
   }
