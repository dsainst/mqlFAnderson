//+------------------------------------------------------------------+
//|                                                  FF_Anderson.mq4 |
//|                        Copyright 2016, BlackSteel, FairForex.org |
//|                                            https://fairforex.org |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, BlackSteel, FairForex.org"
#property link      "https://fairforex.org"
#property version   "2.121"
#property strict

enum lot_calc_mode {by_deposit, by_origin};

//--- input parameters
//extern double RISK_PERCENT    = 0.02;
extern bool   StopOpen        = false;
extern double Exchange_Rate   = 1;  //курс валюты депозита к доллару
extern int    Enchance        = 0;
extern int    Correct_Zone    = 30;
extern bool   FilterHeavy     = true;
extern lot_calc_mode   CalcLotMode = by_deposit;
extern double Load            = 1;
extern bool   UseSLTP         = true;
extern int    Key             = 0;
extern int    ExecLimit       = 10;
extern int    TimeSlip        = 5;
extern int    Slippage        = 5;
extern bool   Debug           = false;
extern bool   HideMap         = false;
extern int    LoopSleep       = 100;
extern string Providers_A     = "Multiplier";
extern double NewWay          = 1;
extern double LuckyLuck       = 1;
extern double Train           = 1;
extern double Stone           = 1;
extern string Providers_B     = "Multiplier";
extern double NightTrain      = 1;
extern double Salt            = 1;
extern double RSB             = 1;
extern double Escort          = 1;
extern double HDFX            = 1;
extern string Providers_C     = "Multiplier";
extern double Quantum         = 1;
extern double Shato           = 1;
extern double RobinGood       = 1;
extern double Formula         = 1;
extern double Premiera        = 1;
extern double Pompea          = 1;
extern double Harvard         = 1;
extern double Astra           = 1;
extern string Providers_noSL  = "Multiplier";
extern double G_Lot           = 1;
extern double ForInvest       = 0;
extern double Digger          = 0;

double   deltaEnchance;
double   deltaSlippage;
int      a1 = 127863;
int      a2 = 287519203;

struct MasterOrder
{
	int			ticket;
	int			provider;
	string		symbol;
	int			type;
	double		lots;
	double		openprice;
	datetime    opentime;
	double		tpprice;
	double		slprice;
	double      closeprice;
	datetime    closetime;
	datetime    expiration;
	int         action;
};
struct Master 
{
   int		validation;
	int		ordersCount;
	double	balance;
	double	equity;
};
struct SymbolInfo {
   string name;
   int      digits;
   int      stoplevel;
   int      freezelevel;
   double   deltastop;
   double   deltafreeze;
   double   ask;
   double   bid;
   double   point;
   double   tickvalue;
   double   contract;
   double   minlot;
   double   maxlot;
   double   steplot;
};
#define MAX_ORDER_COUNT 200
#define ACT_NONE		   0
#define ACT_OPEN		   1
#define ACT_MOD			2
#define ACT_DEL			3


MasterOrder masterOrders[MAX_ORDER_COUNT];
Master      master;
bool        prevValid;
datetime    curtime;
datetime    lastmod; 
bool        dllinit = false;
string      prefix, suffix;

#include "Look.mq4"
#include "ProviderMap.mqh"
Map ticketMap(MAX_ORDER_COUNT);

Look info(10, clrWhite, 10, 16);
bool   showinfo;
string symbolName;
double kdpi;
color  colors[7] = {clrDodgerBlue, clrRed, clrNONE, clrNONE, clrNONE, clrNONE, clrWhite};
string poseTick[4] = {"/", "-", "|", "\\"};
int tickStep = 0;
int DrawHistoryDays = 2;
int netTime = 0;
int netStatus;
int currentDay;
string msgTerminalInfo = "";

// history orders
struct infoStruct {
   string name;
   double   floatDD;
   double   lots;
   double   today;
   double   week;
   double   month;
};
infoStruct infoOrders[PROVIDER_COUNT];
double summFloatDD;
double summToday;
double summWeek;
double summMonth;
double summLots;
int historyTicket[100];


#import "FF_Anderson.dll"
bool ff_Init(Master& master, MasterOrder& masterOrders[], int length, bool debug);
bool ff_GetMasters();
void ff_DeInit();
int ff_getDpi();
#import


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   /*if (AccountNumber() != a1+(Key^a2)) {
      Print("Init error: wrong key");
      return(INIT_FAILED);
   }*/
   int pos = StringFind(Symbol(), "EURUSD");
   if (pos == -1) {
      Print("Init error: pls set EA on EURUSD");
      return(INIT_FAILED);
   }
   prefix = (pos==0)? "": StringSubstr(Symbol(), 0, pos);
   suffix = StringSubstr(Symbol(), pos + 6);
   Print ("prefix: '", prefix, "', suffix: '",suffix,"'");
   if (Digits != 5) {
      Print("Init error: Pls use 5 digits account");
      return(INIT_FAILED);
   }
   // проверка терминальных настроек
   if (!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED)) 
   msgTerminalInfo = "Import dll is not allowed";
         
   if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      msgTerminalInfo += " auto-trade not allowed, press auto-trade button";
   }
      
   prevValid = true;
   master.validation = false;
   for (int i=0; i<MAX_ORDER_COUNT; i++) {  //Выделяем память под строку (надо сделать один раз в начале)
      StringInit(masterOrders[i].symbol, 16);  
   }
   ticketMap.load("ticketmap.dat");
   if (!ff_Init(master, masterOrders, MAX_ORDER_COUNT, Debug)) { 
      Print("Init error: second initialization!");
      dllinit = false;
      return(INIT_FAILED);
   }
   
   // включаем визуализацию 
   
	int mqlOptimization       = IsOptimization();
	int mqlTester             = IsTesting();
	int mqlVisualMode         = IsVisualMode();
   showinfo    = (mqlOptimization || (mqlTester && !mqlVisualMode)) ? false : true; 
   if (showinfo) InitLook();
   
   // просчет истории
   updateMonth();
   
   dllinit = true;
   if (!EventSetMillisecondTimer(1000)) {Print("Init error: cant set timer"); return(INIT_FAILED);}
   providerWeight[1] = G_Lot;
   //providerWeight[2] = LongWay;
   providerWeight[3] = Salt;
   providerWeight[4] = RSB;
   providerWeight[5] = Train;
   providerWeight[6] = NewWay;
   providerWeight[7] = ForInvest;
   providerWeight[8] = LuckyLuck;
   providerWeight[9] = Quantum;
   providerWeight[10] = Stone;
   providerWeight[11] = Formula;
   providerWeight[12] = Escort;
   providerWeight[14] = Digger;
   providerWeight[15] = Premiera;
   providerWeight[16] = NightTrain;
   providerWeight[17] = Shato;
   providerWeight[18] = Pompea;
   providerWeight[19] = Astra;
   providerWeight[20] = HDFX;
   providerWeight[21] = Harvard;
   providerWeight[22] = RobinGood;
   Print("Init succeeded");
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   EventKillTimer();
   netTime = (int)TimeCurrent();
   netStatus = 2;
   string msgAlert = "Please, wait...";
   while (!IsStopped()) {
      resetInfo(); // обнуляем floatDD - текущую просадку --->>>
      if(currentDay!=Day()) {
         Print("update history info window");
         currentDay=Day();
         updateMonth();
         Print("update month");
      }
      int fresh = ff_GetMasters();  //Обновляем данные
      if (fresh) {
         netTime = (int)TimeCurrent();
         netStatus = 1;
         msgAlert = "All OK!";
      } else if (!fresh && ((int)TimeCurrent() - netTime) > 15) {
         netStatus = 0;
         msgAlert = "Please, restart!";
      }
      
      if (master.validation != prevValid) {
         prevValid = master.validation;
         string s = (master.validation)? "Master valid": "Master invalid";
         Print(s);
      }
      
      //открываем и модифицируем то, что есть
      int magicNumber;
      //Print("OrdersTotal: ", OrdersTotal());
      bool stopNew = false;
      ticketMap.ticktack();
      //Перебираем клиентские ордера на соответствие мастеру
      for (int i = 0; i < OrdersTotal(); i++) {
         if (!OrderSelect(i, SELECT_BY_POS)) {
            stopNew = true; //Если селектятся не все ордера, то нельзя открывать новые
            Print("dirty select!");
            continue;
         }
         magicNumber=OrderMagicNumber();
         
         calcFloatDD(magicNumber,OrderSwap()+OrderCommission()+OrderProfit(),OrderLots()); // рассчитываем текущую просадку --->>>
         
         if (magicNumber == 0) continue; //Обрабатываем только ордера советника
         
         int ticket = OrderTicket();
         int masterTicket = ticketMap.getValue(ticket);
         if (masterTicket < 0) {
            if (magicNumber>100)
               masterTicket = magicNumber;
            else if ((masterTicket = ticketMap.key_restore(OrderComment(), ticket)) == 0) {
               Print("ticketMap error: cant find client ticket: ", ticket);
               //OrderDel(ticket); //Для отладки: удалить потеряшки
               continue;}
         }
         int master_index = findMaster(masterTicket);
         if (master_index < 0)  {//Если ордера на мастере нет - то удаляем
            if (master.validation) OrderDel(ticket);
            //else Print("Master not valid!");
            continue;
         } else { //Возможно надо модифицировать или удалить
            switch(masterOrders[master_index].action) {
               case ACT_NONE: break;
               case ACT_OPEN: masterOrders[master_index].action = ACT_MOD; //Ордер уже открыт
               case ACT_MOD: if (UseSLTP && fresh) OrderMod(master_index); break;
               case ACT_DEL: OrderDel(ticket, masterOrders[master_index].closeprice); break;
               default: Print("wrong master action: ", masterOrders[master_index].action);
            }
         }
      } //end order select loop
      int closeTicket;
      while(closeTicket=ticketMap.checkOnClose()>0) { // onClose
         updateMonth();
         Print("onClose order ",closeTicket);
      }
      
      //Перебор ордеров на клиенте завершен, смотрим, что осталось на мастере для открытия
      if (stopNew) return; //Если селект грязный - новые ордера не открываем
      for (int mi = 0; mi < master.ordersCount; mi++) { //Перебираем мастер ордера на предмет октрытия
         if (!StopOpen && masterOrders[mi].action == ACT_OPEN) OrderOpen(mi);//Пробуем открыть ордер
      }
      
      ShowInfoWindow(msgAlert,netStatus,msgTerminalInfo); // выводим в инфоокно --->>>
      Sleep(LoopSleep);
   }
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if (dllinit) {
      Print("Deinit start");
      ticketMap.save("ticketmap.dat");
      ff_DeInit();
   }
   Print("-----= Deinited =-----");
}
//+----------------- Utils ------------------------------------------+
string symbols[100];
int   symbol_count;
string cur_symbol;
MqlTick symbol_tick;
double mpo[2];
double mpc[2];
int    sign[2] = {1,-1};
double symbolPoint;
double deltaFreeze;
double deltaSLTP;
double deltaMax;

//Нормализует лот с учетом минимального значения и допустимого шага
double normLot(double lots, string symbol) {
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   int steps = int(round(lots/lot_step));
   lots = steps * lot_step;
   lots = MathMax(lots, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));
   return(MathMin(lots, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX)));
}
//Нормализует цену
double normPrice(double price, string symbol)
{
   return(NormalizeDouble(price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
}
//нормализует размер депозита под условия как на мастер счете
double normDepo(string symbol) {
   return(AccountBalance() * 
      (100000/SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE)) *
      (SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)/0.01) * Exchange_Rate
   );
}
//Проверяем возможность работы по символу, и обновляем структуру symbol_tick
bool checkSymbol(string symbol) {
   bool found = false;
   for (int i=0; i<symbol_count; i++) {
      if (symbol == symbols[i]) {found = true; break;}
   }
   if (!found) 
      if (!SymbolSelect(symbol, true)) return false;  //Пытаемся выбрать символ, если символа нет,
      else {symbols[symbol_count] = symbol; symbol_count++;}
   if (!(bool)MarketInfo(symbol, MODE_TRADEALLOWED)) return false;  //проверяем, разрешена ли торговля по символу
   if (!SymbolInfoTick(symbol, symbol_tick)) return false;  //получаем текущую информацию по символу (надо проверить, нужнен ли маркет рефреш)
   cur_symbol = symbol;
   mpo[OP_BUY]  = symbol_tick.ask;
   mpo[OP_SELL] = symbol_tick.bid;
   mpc[OP_BUY]  = symbol_tick.bid;
   mpc[OP_SELL] = symbol_tick.ask;
   symbolPoint = MarketInfo(symbol, MODE_POINT);
   deltaFreeze = MarketInfo(symbol, MODE_FREEZELEVEL) * symbolPoint;
   deltaSLTP   = MarketInfo(symbol, MODE_STOPLEVEL) * symbolPoint;
   deltaMax    = fmax(deltaFreeze, deltaSLTP);
   return true; 
}

bool checkMarket() {
   return (IsConnected() && !IsTradeContextBusy() && IsTradeAllowed());
}

int findMaster(int master_ticket) {
   for (int mi = 0; mi < master.ordersCount; mi++) {
      if (masterOrders[mi].ticket == master_ticket) { //Нашли, ордер на мастере
         return mi;
      }
   }
   return -1;
}
void OrderOpen(int master_index) {
   if (ticketMap.getKey(masterOrders[master_index].ticket) > 0) {
      for(int k=0;k<100;k++){ // запоминаем тикет
         if (historyTicket[k]==masterOrders[master_index].ticket) break;
         if (historyTicket[k]==0) {
            historyTicket[k]=masterOrders[master_index].ticket;
            Print("update month");
            updateMonth();
         }
      }
      return; //Защита от повторного открытия
   }
   int provIndex = getProviderIndex(masterOrders[master_index].provider);
   if (provIndex < 0 || providerWeight[provIndex] <= 0) {
      masterOrders[master_index].action = ACT_NONE;
      //Print("unknown provider: , masterOrders[mi].provider);
      return; //Если не знаем этого провайдера - пропускаем
   }
   if (!checkMarket()) return;  //Если рынок закрыт, нет смысла дальше что либо делать
   if (!checkSymbol(masterOrders[master_index].symbol)) return; //Если символ отсутствует или не готов - пропускаем
   int type = masterOrders[master_index].type;
   int sn = sign[type%2];
   double want_price = normPrice(masterOrders[master_index].openprice - sn * Enchance * symbolPoint, cur_symbol);
   master.balance = fmax(master.balance, 1000);
   double o_lots = (CalcLotMode == by_deposit)? AccountBalance()*Exchange_Rate/master.balance: 1;
   o_lots *= masterOrders[master_index].lots * Load * providerWeight[provIndex];
   if (FilterHeavy && o_lots < SymbolInfoDouble(cur_symbol, SYMBOL_VOLUME_MIN)) {
      masterOrders[master_index].action = ACT_NONE; 
      return; //Выходим если ордер меньше минимально возможного
   }
   o_lots = normLot(o_lots, cur_symbol);
   int ticket = 0;
   string comment = "BL_" + ((HideMap)? "": IntegerToString(masterOrders[master_index].ticket)+"_") + providerName[provIndex];
   double openslip = sn * (masterOrders[master_index].openprice - mpo[type]);
   if ((TimeCurrent() - masterOrders[master_index].opentime < TimeSlip &&  openslip >  -ExecLimit * symbolPoint) || openslip >=0) {
      Print("market open, time shift: ", (int)(TimeCurrent() - masterOrders[master_index].opentime));
      ticket = OrderSend(cur_symbol, type, o_lots, mpo[type], Slippage, 0, 0, comment, provIndex);
   } else if (sn * (mpo[type] - want_price) > deltaMax) {
      Print("try send limit, time shift: ", (int)(TimeCurrent() - masterOrders[master_index].opentime), ", slippage: ", sn * (mpo[type]-masterOrders[master_index].openprice));
      ticket = OrderSend(cur_symbol, type + 2, o_lots, want_price, Slippage,
            0, 0, comment, provIndex);
   }
   if (ticket == 0) 
      return;
   if (ticket > 0) {
      ticketMap.set(ticket, masterOrders[master_index].ticket);
      masterOrders[master_index].action = ACT_MOD;
   } else {
      Print("OrderSend error: ", GetLastError());
      Print("symbol: ", cur_symbol, ", type: ", type, ", mpo: ", mpo[type], ", want: ", want_price);
   }
}

void OrderMod(int master_index) {
   double tp = OrderTakeProfit();
   double sl = OrderStopLoss();
   double newtp = masterOrders[master_index].tpprice;
   double newsl = masterOrders[master_index].slprice;
   if (fabs(newtp - tp) <= 0.00001 && fabs(newsl - sl) <= 0.00001) return; //Нечего менять
   
   if (!checkMarket()) {Print("Market closed!");   return;}  //Если рынок закрыт, нет смысла дальше что либо делать
   if (!checkSymbol(OrderSymbol())) return; //Если символ отсутствует или не готов - пропускаем
   int type = OrderType();
   if (type > OP_SELL) return;
   int sn = sign[type%2];
   int ticket = OrderTicket();
   double mop = masterOrders[master_index].openprice;
   double deltaCZ = Correct_Zone * symbolPoint;
   //double newtp = normPrice((fabs(mop-mtp) > deltaCZ)? mtp: mop - sn * deltaCZ, cur_symbol);
   //double newsl = normPrice((fabs(mop-msl) > deltaCZ)? msl: mop + sn * deltaCZ, cur_symbol);
   //if (newsl == 0) 
      //newsl = normPrice(OrderOpenPrice() - sn * (fmin(AccountBalance() * RISK_PERCENT / ( SymbolInfoDouble(cur_symbol, SYMBOL_TRADE_TICK_VALUE) * OrderLots()), 5000) * symbolPoint), cur_symbol);
   if (fabs(newtp - tp) > symbolPoint || fabs(newsl - sl) > symbolPoint) {//Если есть что изменить - изменяем
      if (!OrderModify(ticket, OrderOpenPrice(), newsl, newtp, 0)) {
         Print("OrderMod error, ticket: ", ticket, " error: ", GetLastError());
         Print("symbol: ", OrderSymbol(), ", type: ", type, ", tp: ", tp, " -> ", newtp, ", sl: ", sl, " -> ", newsl);
      }
   }
}

void OrderDel(int ticket, double closePriceMaster = 0) {
   if (!checkMarket()) {Print("Market closed!");   return;}  //Если рынок закрыт, нет смысла дальше что либо делать
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      Print("OrderDel error, ticket: ", ticket, " not found!");
      return;}
   if (OrderCloseTime() > 0) {
      Print("OrderDel error, Ticket=", ticket, ", CloseTime=", OrderCloseTime());
      return;} //Если ордер уже закрыт - выходим
   if (!checkSymbol(OrderSymbol())) {
      Print("OrderDel error, cant select symbol: ", OrderSymbol());
      return;}
   bool res;
   if (OrderType()<2) {
      int type = OrderType();
      int sn = sign[type%2];
      double closeSP = sn*(mpc[type]-closePriceMaster);
      
      if (closePriceMaster && closeSP<0) return;
      res = OrderClose(ticket, OrderLots(), mpc[OrderType()], Slippage);
   } else {
      res = OrderDelete(ticket);
   }
   if (!res) Print("OrderDel error, ticket: ", ticket, " error: ", GetLastError());
   else {
      ticketMap.del(ticket);
      updateInfoWindow(OrderMagicNumber(),OrderSwap()+OrderCommission()+OrderProfit());
   }
}


void InitLook()
{
	kdpi = ff_getDpi()/72.0;
	ObjectsDeleteAll();

	info.Init();
	info.SetHeader(0, StringConcatenate("legion.fairforex.org"));
	info.Set("Init...");
	
	info.DrawHistory();
	info.ResizeBox();
}
void ShowInfoWindow(string msg="", int status = 3, string msgTerm="")
{
   if (showinfo) {
      if (tickStep>3) tickStep = 0;
      
	   info.SetHeader(0, StringFormat("%-14s %35s","legion.fairforex.org",poseTick[tickStep]));
	
      info.Set(msg, status);
      info.Set("");
      
      // рисуем инфо об ордерах --- >>> 
      info.Set(StringFormat("%-12s %8s %8s %8s %8s %8s","name","floatDD","lots","today","week","month"));
      info.Set("---------------------------------------------------------");
      for (int i=0;i<PROVIDER_COUNT;i++) {
         if (providerName[i] != "")
            info.Set(StringFormat("%-12s %8.2f %8.2f %8.2f %8.2f %8.2f",providerName[i],infoOrders[i].floatDD,infoOrders[i].lots,infoOrders[i].today,infoOrders[i].week,infoOrders[i].month));
      }
      info.Set("---------------------------------------------------------");
      info.Set(StringFormat("%-12s %8.2f %8.2f %8.2f %8.2f %8.2f","Total:",summFloatDD,summLots,summToday,summWeek,summMonth));
      // рисуем инфо об ордерах --- <<<
      if (msgTerm != "") {
         info.Set("");
         info.Set(msgTerm);
      }
      info.ResizeBox();
      tickStep++;
	}
}

void updateMonth(){
   resetInfo(true);
   datetime startweek = TimeCurrent() - DayOfWeek()*24*60*60 - Hour()*60*60 - Minute()*60 - Seconds();
   for (int i = OrdersHistoryTotal()-1; i>=0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS,MODE_HISTORY)) continue; //если ордер не заселектился -> пропускаем
      int magic = OrderMagicNumber();
      if (magic>=PROVIDER_COUNT || OrderType()>OP_SELL) continue; // если не наш провайдер или отложка -> пропускаем
      datetime closetime = OrderCloseTime();
      double profit = OrderSwap() + OrderCommission() + OrderProfit();
      if (closetime > startweek) {
         //считаем за неделю
         infoOrders[magic].week += profit;
         summWeek += profit;
      }
      if (TimeYear(closetime) != Year() || TimeMonth(closetime) != Month()) continue; // если не наш год и месяц -> пропускаем
      //считаем за месяц
      infoOrders[magic].month += profit;
      summMonth += profit;
      if (TimeDay(closetime) != Day()) continue; //если не наш день -> пропускаем
      // просчитываем за сегодня
      infoOrders[magic].today += profit;
      summToday += profit;
   }
}

void updateInfoWindow(int magic, double profit) {
   if (profit) {
      // суммируем просадку
      infoOrders[magic].today += profit;
      summToday += profit;
      infoOrders[magic].week += profit;
      summWeek += profit;
      infoOrders[magic].month += profit;
      summMonth += profit;
   }
}

void calcFloatDD(int magic, double profit,double lots){
   if (profit && lots) {
      // суммируем просадку
      infoOrders[magic].floatDD += profit;
      infoOrders[magic].lots += lots;
      summFloatDD += profit;
      summLots += lots;
   }
}

void resetInfo(int clear_all=false){
   if (clear_all) {
      for(int i=0; i<PROVIDER_COUNT;i++){
         infoOrders[i].floatDD = 0;
         infoOrders[i].lots = 0;
         infoOrders[i].today = 0;
         infoOrders[i].week = 0;
         infoOrders[i].month = 0;
         summFloatDD = 0;
         summToday = 0;
         summWeek = 0;
         summMonth = 0;
      }
   } else {
      for(int i=0; i<PROVIDER_COUNT;i++){
         infoOrders[i].floatDD = 0;
         infoOrders[i].lots = 0;
         summFloatDD = 0;
         summLots = 0;
      }
   }
}