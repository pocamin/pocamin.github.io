//+------------------------------------------------------------------+
//|                                             RoNz Auto SL n TP.mq4|
//|                              Copyright 2014-2015, Rony Nofrianto |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014-2015, Rony Nofrianto"
#property link "https://www.mql5.com/en/users/ronz"
#property version   "2.02"
#property strict
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/* 
   v1.0
   + Auto SL and TP
   
   v1.22
   + Correcting Min Stop Level
   
   v2.0
   + Added modes for SL and TP (Hidden or Placed)
   + Added profit lock
   + Added stepping Trailing Stop
   
   v2.01
   + Added option to enable/disable alert when closed by hidden sl/tp
   
   v2.03
   + Fixed initial locking profit
   + Fixed trailing stop
   
   v2.04
   + Fixed trailing stop step
   + Rearrange lock profit to a function
  
  NOTE:
  + First of all, your orders SL and TP must be set to 0, then this EA will set appropriate SL and TP.
  + To disable SL, TP, Profit Lock, and Trailing Stop, set its value to 0.
*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_CHARTSYMBOL
  {
   CurrentChartSymbol=0,//Current Chart Only
   AllOpenOrder=1,//All Opened Orders
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_SLTP_MODE
  {
   Server=0,//Place SL n TP
   Client=1,//Hidden SL n TP
  };
string STR_OPTYPE[]={"Buy","Sell","Buy Limit","Sell Limit","Buy Stop","Sell Stop"};

input int   TakeProfit=500;
input int   StopLoss=250;
input ENUM_SLTP_MODE SLnTPMode=Client;
input int   LockProfitAfter=100;//Target Pips to Lock Profit
input int   ProfitLock=60;//Profit To Lock
input int   TrailingStop=50;//Trailing Stop
input int   TrailingStep=10;//Trailing Stop Step
input ENUM_CHARTSYMBOL  ChartSymbolSelection=AllOpenOrder;
input bool   inpEnableAlert=false;//Enable Alert
//+------------------------------------------------------------------+
//| Hitung Posisi Terbuka                                            |
//+------------------------------------------------------------------+
int CalculateCurrentOrders()
  {
   int buys=0,sells=0;
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(ChartSymbolSelection==CurrentChartSymbol && OrderSymbol()!=Symbol()) continue;
      if(OrderType()==OP_BUY)
         buys++;
      if(OrderType()==OP_SELL)
         sells++;
     }

   if(buys>0) return(buys);
   else       return(-sells);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool LockProfit(int TiketOrder,int TargetPoints,int LockedPoints)
  {
   if(TargetPoints==0 || LockedPoints==0) return false;

   if(OrderSelect(TiketOrder,SELECT_BY_TICKET,MODE_TRADES)==false) return false;

   double CurrentSL=(OrderStopLoss()!=0)?OrderStopLoss():OrderOpenPrice();
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);
   double minstoplevel=MarketInfo(OrderSymbol(),MODE_STOPLEVEL);
   double ask=MarketInfo(OrderSymbol(),MODE_ASK);
   double bid=MarketInfo(OrderSymbol(),MODE_BID);
   double PSL=0;

   if((OrderType()==OP_BUY) && (bid-OrderOpenPrice()>=TargetPoints*point) && (CurrentSL<=OrderOpenPrice()))
     {
      PSL=NormalizeDouble(OrderOpenPrice()+(LockedPoints*point),digits);
     }
   else if((OrderType()==OP_SELL) && (OrderOpenPrice()-ask>=TargetPoints*point) && (CurrentSL>=OrderOpenPrice()))
     {
      PSL=NormalizeDouble(OrderOpenPrice()-(LockedPoints*point),digits);
     }
   else
      return false;

   Print(STR_OPTYPE[OrderType()]," #",OrderTicket()," ProfitLock: OP=",OrderOpenPrice()," CSL=",CurrentSL," PSL=",PSL," LP=",LockedPoints);

   if(OrderModify(OrderTicket(),OrderOpenPrice(),PSL,OrderTakeProfit(),0,clrRed))
      return true;
   else
      return false;


   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SteppingTrailingStop(int TiketOrder,int JumlahPoin,int Step=1)
  {
   if(JumlahPoin==0) return false;

   if(OrderSelect(TiketOrder,SELECT_BY_TICKET,MODE_TRADES)==false) return false;

   double CurrentSL=(OrderStopLoss()!=0)?OrderStopLoss():OrderOpenPrice();
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);
   double minstoplevel=MarketInfo(OrderSymbol(),MODE_STOPLEVEL);
   double ask=MarketInfo(OrderSymbol(),MODE_ASK);
   double bid=MarketInfo(OrderSymbol(),MODE_BID);
   double TSL=0;

    JumlahPoin=JumlahPoin+(int)minstoplevel;

   if((OrderType()==OP_BUY) && (bid-OrderOpenPrice()>JumlahPoin*point))
     {
      if(CurrentSL<OrderOpenPrice())
         CurrentSL=OrderOpenPrice();

      if((bid-CurrentSL)>=JumlahPoin*point)
         TSL=NormalizeDouble(CurrentSL+(Step*point),digits);
     }

   else if((OrderType()==OP_SELL) && (OrderOpenPrice()-ask>JumlahPoin*point))
     {
      if(CurrentSL>OrderOpenPrice())
         CurrentSL=OrderOpenPrice();

      if((CurrentSL-ask)>=JumlahPoin*point)
         TSL=NormalizeDouble(CurrentSL-(Step*point),digits);
     }

   if(TSL==0)
      return false;

   Print(STR_OPTYPE[OrderType()]," #",OrderTicket()," TrailingStop: OP=",OrderOpenPrice()," CSL=",CurrentSL," TSL=",TSL," TS=",JumlahPoin," Step=",Step);
   bool res=OrderModify(OrderTicket(),OrderOpenPrice(),TSL,OrderTakeProfit(),0,clrRed);
   if(res == true) return true;
   else return false;

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SetSLnTP()
  {
   double SL,TP;
   SL=TP=0.00;

   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(ChartSymbolSelection==CurrentChartSymbol && OrderSymbol()!=Symbol()) continue;

      double point=MarketInfo(OrderSymbol(),MODE_POINT);
      double minstoplevel=MarketInfo(OrderSymbol(),MODE_STOPLEVEL);
      double ask=MarketInfo(OrderSymbol(),MODE_ASK);
      double bid=MarketInfo(OrderSymbol(),MODE_BID);
      int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);

      //Print("Check SL & TP : ",OrderSymbol()," SL = ",OrderStopLoss()," TP = ",OrderTakeProfit());

      double ClosePrice=0;
      int Points=0;
      color CloseColor=clrNONE;

      //Get Points
      if(OrderType()==OP_BUY)
        {
         CloseColor=clrBlue;
         ClosePrice=bid;
         Points=(int)((ClosePrice-OrderOpenPrice())/point);
        }
      else if(OrderType()==OP_SELL)
        {
         CloseColor=clrRed;
         ClosePrice=ask;
         Points=(int)((OrderOpenPrice()-ClosePrice)/point);
        }

      //Set Server SL and TP
      if(SLnTPMode==Server)
        {
         if(OrderType()==OP_BUY)
           {
            SL=(StopLoss>0)?NormalizeDouble(OrderOpenPrice()-((StopLoss+minstoplevel)*point),digits):0;
            TP=(TakeProfit>0)?NormalizeDouble(OrderOpenPrice()+((TakeProfit+minstoplevel)*point),digits):0;
           }
         else if(OrderType()==OP_SELL)
           {
            SL=(StopLoss>0)?NormalizeDouble(OrderOpenPrice()+((StopLoss+minstoplevel)*point),digits):0;
            TP=(TakeProfit>0)?NormalizeDouble(OrderOpenPrice()-((TakeProfit+minstoplevel)*point),digits):0;
           }

         if(OrderStopLoss()==0.0 && OrderTakeProfit()==0.0)
            bool res=OrderModify(OrderTicket(),OrderOpenPrice(),SL,TP,0,Blue);
         else if(OrderTakeProfit()==0.0)
            bool res=OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),TP,0,Blue);
         else if(OrderStopLoss()==0.0)
            bool res=OrderModify(OrderTicket(),OrderOpenPrice(),SL,OrderTakeProfit(),0,Red);
        }
      //Hidden SL and TP
      else if(SLnTPMode==Client)
        {
         if((TakeProfit>0 && Points>=TakeProfit) || (StopLoss>0 && Points<=-StopLoss))
           {
            if(OrderClose(OrderTicket(),OrderLots(),ClosePrice,3,CloseColor))
              {
               if(inpEnableAlert)
                 {
                  if(OrderProfit()>0)
                     Alert("Closed by Virtual TP #",OrderTicket()," Profit=",OrderProfit()," Points=",Points);
                  if(OrderProfit()<0)
                     Alert("Closed by Virtual SL #",OrderTicket()," Loss=",OrderProfit()," Points=",Points);
                 }
              }
           }
        }

      if(LockProfitAfter>0 && ProfitLock>0 && Points>=LockProfitAfter)
        {
         if(Points<=LockProfitAfter+TrailingStop)
            LockProfit(OrderTicket(),LockProfitAfter,ProfitLock);
         else if(Points>=LockProfitAfter+TrailingStop)
                         SteppingTrailingStop(OrderTicket(),TrailingStop,TrailingStep);
        }
      else if(LockProfitAfter==0)
         SteppingTrailingStop(OrderTicket(),TrailingStop,TrailingStep);

     }

   return false;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
  {

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(Bars<100 || IsTradeAllowed()==false)
      return;

   if(CalculateCurrentOrders()!=0)
      SetSLnTP();

   OrderTest();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OrderTest()
  {
   if(!IsTesting()) return;
   if(CalculateCurrentOrders()!=0) return;
   if(Volume[0]>1) return;
   double MA[3];

   MA[0]=iMA(NULL,0,10,0,MODE_EMA,PRICE_CLOSE,0);
   MA[1]=iMA(NULL,0,20,0,MODE_EMA,PRICE_CLOSE,0);
   MA[2]=iMA(NULL,0,100,0,MODE_EMA,PRICE_CLOSE,0);

   if((MA[0]<MA[1]) && MA[0]>MA[2])
      int ticket=OrderSend(NULL,OP_BUY,MarketInfo(Symbol(),MODE_MINLOT),Ask,3,0,0);
   if((MA[0]>MA[1]) && MA[0]<MA[2])
      int ticket=OrderSend(NULL,OP_SELL,MarketInfo(Symbol(),MODE_MINLOT),Bid,3,0,0);
  }
//+------------------------------------------------------------------+
