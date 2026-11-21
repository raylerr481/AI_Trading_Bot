//+------------------------------------------------------------------+
//| Infinity_Impulse_XAUUSD_MT4  v1.02                               |
//| Ruptura de Bollinger + EMA en oro (M5)                           |
//| v1.01: barra nueva real, precios normalizados, stop level,       |
//| filtro de spread, deteccion de simbolo, logs de error, limite    |
//| por direccion, SL/TP adaptativo (ATR), bloqueo rapido de         |
//| ganancia, trailing, extension de TP y add-ons apalancados        |
//| financiados SOLO con ganancia ya asegurada.                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "1.02"
#property strict

#define EA_VER   "1.02"
#define MAXT     64

//--- Simbolo y mercado
input string          InpSymbol            = "";          // Simbolo ("" = autodetectar oro: XAUUSD, GOLD...)
input ENUM_TIMEFRAMES InpTF                = PERIOD_M5;   // Temporalidad
input int             InpMagic             = 202660;      // Magic Number (distinto de v1.00)
input int             InpSlippagePts       = 30;          // Deslizamiento maximo (puntos)

//--- Riesgo
input double          InpRiskPercent       = 1.0;         // Riesgo por operacion (% del balance)
input double          InpRiskUSDOverride   = 0.0;         // Si >0: riesgo fijo en USD por operacion (ej. 5 en cuenta de 500)
input double          InpMinLotRiskMult    = 1.5;         // Si el lote minimo arriesga mas de N veces lo previsto, NO opera
input double          InpMaxTotalRiskPct   = 2.0;         // Riesgo abierto total maximo (% balance, cuenta solo lo que aun no esta asegurado)

//--- Senal (igual que v1.00)
input int             InpEMAPeriod         = 50;
input int             InpBBPeriod          = 20;
input double          InpBBDeviation       = 2.0;
input double          InpMinAdx            = 0.0;         // 0 = sin filtro ADX. Prueba 18-22 en el probador
input bool            InpUseHours          = false;       // Filtro de horario (hora del servidor)
input int             InpHourStart         = 8;
input int             InpHourEnd           = 20;

//--- SL/TP adaptativo
input int             InpAtrPeriod         = 14;
input double          InpSlAtr             = 1.5;         // SL = ATR x este valor
input double          InpMinSLPts          = 300;         // SL minimo en puntos (con 2 decimales = $3)
input double          InpMaxSLPts          = 900;         // SL maximo en puntos
input double          InpRewardRisk        = 2.0;         // TP = SL x este valor

//--- Filtros de ejecucion
input double          InpMaxSpreadPts      = 50;          // Spread maximo (puntos)
input double          InpMaxSpreadPctSL    = 20.0;        // Spread maximo como % del SL
input int             InpMaxScouts         = 2;           // Posiciones base simultaneas (sin add-ons)
input int             InpMaxPerDirection   = 1;           // Base por direccion
input int             InpMaxRetriesBar     = 3;           // Reintentos de orden por vela
input int             InpEntryWindowSec    = 90;          // Solo entra durante los primeros N segundos de la vela

//--- Proteccion rapida de ganancia
input bool            InpLockEnabled       = true;
input double          InpLockTriggerR      = 0.40;        // Se activa cuando el pico llega a 0.40R
input double          InpLockKeepPct       = 55.0;        // Asegura este % del pico favorable
input double          InpLockBufferPts     = 15;          // Colchon sobre entrada (cubre spread y comision)
input bool            InpTrailEnabled      = true;
input double          InpTrailStartR       = 1.0;         // Trailing ATR desde 1R
input double          InpTrailAtr          = 1.0;         // Distancia del trailing (ATR)
input double          InpMinStepAtr        = 0.05;        // Paso minimo para modificar SL (ATR)
input int             InpModifyIntervalSec = 5;           // Segundos minimos entre modificaciones por orden

//--- TP adaptativo
input bool            InpTpExtendEnabled   = true;
input double          InpTpExtendAtPct     = 80.0;        // Si el precio recorre este % hacia el TP...
input double          InpTpExtendAdx       = 22.0;        // ...y ADX >= este valor, se extiende el TP
input double          InpTpExtendAtr       = 1.0;         // Extension (ATR)
input int             InpTpExtendMax       = 2;           // Extensiones maximas por orden
input double          InpTpExtendLockR     = 1.0;         // Al extender, SL asegura al menos 1R

//--- Add-ons apalancados (piramidacion financiada)
input bool            InpAddOnEnabled      = true;
input double          InpAddOnMinR         = 1.0;         // Base debe ir en +1R
input double          InpAddOnMinLockR     = 0.30;        // y su SL ya debe asegurar >= 0.30R
input double          InpAddOnFundingPct   = 100.0;      // Riesgo del add-on <= este % de lo ya asegurado
input double          InpAddOnMaxLotMult   = 1.5;         // Lote del add-on <= base x este valor
input double          InpAddOnSlMult       = 0.8;         // SL del add-on = SL base x este valor
input double          InpAddOnTpAtr        = 2.5;         // TP del add-on (ATR)
input double          InpAddOnMinAdx       = 20.0;
input int             InpAddOnPerScout     = 1;
input int             InpMaxAddOns         = 2;

//--- Variables globales
string   g_sym = "";
int      g_dig = 2;
double   g_pt  = 0.01;
datetime g_lastBar = 0;
int      g_pending = -1;     // -1 ninguna, OP_BUY u OP_SELL
int      g_tries = 0;
datetime g_lastAddCheck = 0;
datetime g_lastPanel = 0;
datetime g_lastSummary = 0;
datetime g_lastSkipLog = 0;
int      g_tk[MAXT];
double   g_peak[MAXT];
double   g_risk[MAXT];
datetime g_lastMod[MAXT];
int      g_wins = 0, g_losses = 0;
double   g_net = 0.0;
int      g_opened = 0, g_addons = 0, g_locks = 0, g_ext = 0;
int      g_signals = 0, g_buySig = 0, g_sellSig = 0, g_entryFails = 0;
string   g_skipName[16];
int      g_skipCnt[16];
int      g_skipN = 0;

//+------------------------------------------------------------------+
string ErrText(int e)
{
   switch(e)
   {
      case 2:   return "COMMON_ERROR";
      case 4:   return "SERVER_BUSY";
      case 6:   return "NO_CONNECTION";
      case 8:   return "TOO_FREQUENT";
      case 128: return "TRADE_TIMEOUT";
      case 129: return "INVALID_PRICE";
      case 130: return "INVALID_STOPS";
      case 131: return "INVALID_VOLUME";
      case 132: return "MARKET_CLOSED";
      case 133: return "TRADE_DISABLED";
      case 134: return "NOT_ENOUGH_MONEY";
      case 135: return "PRICE_CHANGED";
      case 136: return "OFF_QUOTES";
      case 137: return "BROKER_BUSY";
      case 138: return "REQUOTE";
      case 139: return "ORDER_LOCKED";
      case 145: return "MODIFY_DENIED_TOO_CLOSE";
      case 146: return "TRADE_CONTEXT_BUSY";
      case 147: return "EXPIRATION_DENIED";
      case 148: return "TOO_MANY_ORDERS";
      case 4106: return "UNKNOWN_SYMBOL";
      case 4108: return "INVALID_TICKET";
      case 4109: return "TRADE_NOT_ALLOWED_IN_EA";
   }
   return "ERR_" + IntegerToString(e);
}

bool SymbolOk(string s)
{
   if(s == "") return(false);
   SymbolSelect(s, true);
   return(MarketInfo(s, MODE_POINT) > 0.0 && MarketInfo(s, MODE_TICKSIZE) > 0.0);
}

string DetectSymbol()
{
   if(InpSymbol != "" && SymbolOk(InpSymbol)) return(InpSymbol);
   string u = Symbol();
   StringToUpper(u);
   if((StringFind(u, "XAU") >= 0 || StringFind(u, "GOLD") >= 0) && SymbolOk(Symbol())) return(Symbol());
   string c[] = {"XAUUSD", "XAUUSD.m", "XAUUSDm", "XAUUSD.", "XAUUSD.a", "XAUUSD.pro", "GOLD", "GOLDm", "GOLD."};
   for(int i = 0; i < ArraySize(c); i++)
      if(SymbolOk(c[i])) return(c[i]);
   return("");
}

//--- dinero por 1.0 de precio por 1 lote
double ValPerUnit()
{
   double ts = MarketInfo(g_sym, MODE_TICKSIZE);
   double tv = MarketInfo(g_sym, MODE_TICKVALUE);
   if(ts <= 0.0 || tv <= 0.0) return(0.0);
   return(tv / ts);
}

double MinStopDist()
{
   double lv = MathMax(MarketInfo(g_sym, MODE_STOPLEVEL), MarketInfo(g_sym, MODE_FREEZELEVEL));
   return(lv * g_pt);
}

double SpreadPx()
{
   return(MarketInfo(g_sym, MODE_ASK) - MarketInfo(g_sym, MODE_BID));
}

bool HourOk()
{
   if(!InpUseHours) return(true);
   int h = TimeHour(TimeCurrent());
   if(InpHourStart <= InpHourEnd) return(h >= InpHourStart && h < InpHourEnd);
   return(h >= InpHourStart || h < InpHourEnd);
}

//--- lotes: redondea hacia ABAJO. Devuelve 0 si no cabe en el riesgo permitido.
double CalcLots(double slDist, double riskMoney, bool allowMinLot)
{
   double v = ValPerUnit();
   if(v <= 0.0 || slDist <= 0.0 || riskMoney <= 0.0) return(0.0);
   double step = MarketInfo(g_sym, MODE_LOTSTEP);
   double minl = MarketInfo(g_sym, MODE_MINLOT);
   double maxl = MarketInfo(g_sym, MODE_MAXLOT);
   if(step <= 0.0) step = 0.01;
   double lots = riskMoney / (slDist * v);
   lots = MathFloor(lots / step + 1e-9) * step;
   if(lots < minl)
   {
      if(allowMinLot && minl * slDist * v <= riskMoney * InpMinLotRiskMult) lots = minl;
      else return(0.0);
   }
   if(lots > maxl) lots = maxl;
   return(NormalizeDouble(lots, 2));
}

bool MarginOk(int cmd, double lots)
{
   ResetLastError();
   double m = AccountFreeMarginCheck(g_sym, cmd, lots);
   if(m <= 0.0 || GetLastError() == 134) return(false);
   return(true);
}

//--- seguimiento de tickets
int TrkFind(int tk, bool create)
{
   int freeIdx = -1;
   for(int i = 0; i < MAXT; i++)
   {
      if(g_tk[i] == tk) return(i);
      if(g_tk[i] == 0 && freeIdx < 0) freeIdx = i;
   }
   if(!create || freeIdx < 0) return(-1);
   g_tk[freeIdx] = tk;
   g_peak[freeIdx] = 0.0;
   g_risk[freeIdx] = 0.0;
   g_lastMod[freeIdx] = 0;
   return(freeIdx);
}

double GetRisk(int tk, int idx, double atr)
{
   if(g_risk[idx] > 0.0) return(g_risk[idx]);
   string k = "INFR_" + IntegerToString(tk);
   double r = 0.0;
   if(GlobalVariableCheck(k)) r = GlobalVariableGet(k);
   if(r <= 0.0)
   {
      r = MathMax(InpMinSLPts * g_pt, atr * InpSlAtr);
      GlobalVariableSet(k, r);
   }
   g_risk[idx] = r;
   return(r);
}

bool IsLev(string cm)
{
   return(StringFind(cm, "LEV") >= 0);
}

int CountOrders(int cmd, int levMode)   // cmd -1 = todas; levMode 0 base, 1 add-on, 2 todas
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != g_sym || OrderMagicNumber() != InpMagic) continue;
      int t = OrderType();
      if(t != OP_BUY && t != OP_SELL) continue;
      if(cmd >= 0 && t != cmd) continue;
      bool lv = IsLev(OrderComment());
      if(levMode == 0 && lv) continue;
      if(levMode == 1 && !lv) continue;
      n++;
   }
   return(n);
}

//--- riesgo abierto aun no asegurado (dinero)
double OpenRiskMoney()
{
   double v = ValPerUnit();
   double sum = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != g_sym || OrderMagicNumber() != InpMagic) continue;
      int t = OrderType();
      if(t != OP_BUY && t != OP_SELL) continue;
      double dir = (t == OP_BUY ? 1.0 : -1.0);
      double atRisk = dir * (OrderOpenPrice() - OrderStopLoss());
      if(OrderStopLoss() <= 0.0) atRisk = MarketInfo(g_sym, MODE_ASK) * 0.01;
      if(atRisk > 0.0) sum += atRisk * OrderLots() * v;
   }
   return(sum);
}

double RiskMoneyForEntry()
{
   if(InpRiskUSDOverride > 0.0) return(InpRiskUSDOverride);
   return(AccountBalance() * InpRiskPercent / 100.0);
}

//--- abre una orden. Devuelve ticket (>0) o -error
int OpenOrder(int cmd, double lots, double slDist, double tpDist, string comment)
{
   RefreshRates();
   double ask = MarketInfo(g_sym, MODE_ASK);
   double bid = MarketInfo(g_sym, MODE_BID);
   double price = (cmd == OP_BUY ? ask : bid);
   double sl = (cmd == OP_BUY ? price - slDist : price + slDist);
   double tp = (cmd == OP_BUY ? price + tpDist : price - tpDist);
   price = NormalizeDouble(price, g_dig);
   sl = NormalizeDouble(sl, g_dig);
   tp = NormalizeDouble(tp, g_dig);
   ResetLastError();
   int tk = OrderSend(g_sym, cmd, lots, price, InpSlippagePts, sl, tp, comment, InpMagic, 0, (cmd == OP_BUY ? clrBlue : clrRed));
   if(tk > 0)
   {
      int idx = TrkFind(tk, true);
      if(idx >= 0) { g_risk[idx] = slDist; g_lastMod[idx] = TimeCurrent(); }
      GlobalVariableSet("INFR_" + IntegerToString(tk), slDist);
      return(tk);
   }
   int err = GetLastError();
   Print("ORDER_SEND_FAIL | ", (cmd == OP_BUY ? "BUY" : "SELL"), " lots=", DoubleToString(lots, 2), " price=", DoubleToString(price, g_dig),
         " sl=", DoubleToString(sl, g_dig), " tp=", DoubleToString(tp, g_dig), " err=", err, " ", ErrText(err));
   return(-err);
}

void CountSkip(string reason)
{
   for(int i = 0; i < g_skipN; i++)
      if(g_skipName[i] == reason) { g_skipCnt[i]++; return; }
   if(g_skipN < 16) { g_skipName[g_skipN] = reason; g_skipCnt[g_skipN] = 1; g_skipN++; }
}

string SkipSummary()
{
   if(g_skipN == 0) return("none");
   string r = "";
   for(int i = 0; i < g_skipN; i++) r += g_skipName[i] + "=" + IntegerToString(g_skipCnt[i]) + " ";
   return(r);
}

void SkipLog(string reason)
{
   CountSkip(reason);
   if(TimeCurrent() - g_lastSkipLog < 30) return;
   g_lastSkipLog = TimeCurrent();
   Print("ENTRY_SKIP | reason=", reason, " spreadPts=", DoubleToString(SpreadPx() / g_pt, 0));
}

//--- intenta una entrada. 1 = abierta, 0 = descartada, -1 = reintentar
int TryEnter(int cmd)
{
   if(!IsTradeAllowed() || !IsExpertEnabled()) { SkipLog("TRADE_NOT_ALLOWED"); return(0); }
   if(!HourOk()) { SkipLog("HOUR_FILTER"); return(0); }
   if(CountOrders(-1, 0) >= InpMaxScouts) return(0);
   if(CountOrders(cmd, 0) >= InpMaxPerDirection) return(0);

   double atr = iATR(g_sym, InpTF, InpAtrPeriod, 1);
   if(atr <= 0.0) { SkipLog("NO_ATR"); return(0); }
   if(InpMinAdx > 0.0 && iADX(g_sym, InpTF, 14, PRICE_CLOSE, MODE_MAIN, 1) < InpMinAdx) { SkipLog("ADX_LOW"); return(0); }

   double slDist = MathMax(InpMinSLPts * g_pt, MathMin(InpMaxSLPts * g_pt, atr * InpSlAtr));
   double tpDist = slDist * InpRewardRisk;
   double minStop = MinStopDist();
   if(slDist < minStop + g_pt || tpDist < minStop + g_pt) { SkipLog("BELOW_STOP_LEVEL"); return(0); }

   double spread = SpreadPx();
   if(spread > InpMaxSpreadPts * g_pt) { SkipLog("SPREAD_ABS"); return(0); }
   if(spread > slDist * InpMaxSpreadPctSL / 100.0) { SkipLog("SPREAD_PCT_OF_SL"); return(0); }

   double riskMoney = RiskMoneyForEntry();
   double lots = CalcLots(slDist, riskMoney, true);
   if(lots <= 0.0) { SkipLog("LOT_EXCEEDS_RISK"); return(0); }
   double newRisk = lots * slDist * ValPerUnit();
   double cap = AccountBalance() * InpMaxTotalRiskPct / 100.0;
   if(OpenRiskMoney() + newRisk > cap) { SkipLog("TOTAL_RISK_CAP"); return(0); }
   if(!MarginOk(cmd, lots)) { SkipLog("MARGIN"); return(0); }

   int r = OpenOrder(cmd, lots, slDist, tpDist, "Inf Sc v" + EA_VER);
   if(r > 0)
   {
      g_opened++;
      Print("ENTRY_OPEN | ticket=", r, " ", (cmd == OP_BUY ? "BUY" : "SELL"), " lots=", DoubleToString(lots, 2),
            " slPts=", DoubleToString(slDist / g_pt, 0), " tpPts=", DoubleToString(tpDist / g_pt, 0),
            " atrPts=", DoubleToString(atr / g_pt, 0), " riskUSD=", DoubleToString(newRisk, 2),
            " spreadPts=", DoubleToString(spread / g_pt, 0));
      return(1);
   }
   g_entryFails++;
   int e = -r;
   if(e == 4 || e == 6 || e == 8 || e == 128 || e == 129 || e == 135 || e == 136 || e == 137 || e == 138 || e == 146) return(-1);
   return(0);
}

bool Better(int type, double cand, double cur)
{
   if(cur <= 0.0) return(true);
   if(type == OP_BUY) return(cand > cur);
   return(cand < cur);
}

bool ModifyOrd(int tk, double sl, double tp, string why)
{
   sl = NormalizeDouble(sl, g_dig);
   tp = NormalizeDouble(tp, g_dig);
   ResetLastError();
   if(OrderModify(tk, OrderOpenPrice(), sl, tp, 0, clrNONE))
   {
      Print("ORDER_MODIFY | ticket=", tk, " why=", why, " sl=", DoubleToString(sl, g_dig), " tp=", DoubleToString(tp, g_dig));
      return(true);
   }
   int err = GetLastError();
   if(err != 1) Print("ORDER_MODIFY_FAIL | ticket=", tk, " why=", why, " err=", err, " ", ErrText(err));
   return(false);
}

//--- SL/TP adaptativo, bloqueo rapido, trailing, extension de TP
void ManagePositions()
{
   double atr = iATR(g_sym, InpTF, InpAtrPeriod, 1);
   if(atr <= 0.0) return;
   double adx = iADX(g_sym, InpTF, 14, PRICE_CLOSE, MODE_MAIN, 1);
   double bid = MarketInfo(g_sym, MODE_BID);
   double ask = MarketInfo(g_sym, MODE_ASK);
   double minStop = MinStopDist();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != g_sym || OrderMagicNumber() != InpMagic) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      int tk = OrderTicket();
      double open = OrderOpenPrice();
      double sl = OrderStopLoss();
      double tp = OrderTakeProfit();
      double dir = (type == OP_BUY ? 1.0 : -1.0);
      double price = (type == OP_BUY ? bid : ask);
      int idx = TrkFind(tk, true);
      if(idx < 0) continue;
      double risk = GetRisk(tk, idx, atr);
      double fav = dir * (price - open);
      if(fav > g_peak[idx]) g_peak[idx] = fav;
      double peak = g_peak[idx];
      if(TimeCurrent() - g_lastMod[idx] < InpModifyIntervalSec) continue;

      double newSL = sl, newTP = tp;
      string why = "";
      double buf = (ask - bid) + InpLockBufferPts * g_pt;

      if(InpLockEnabled && peak >= risk * InpLockTriggerR)
      {
         double cand = open + dir * MathMax(buf, peak * InpLockKeepPct / 100.0);
         if(Better(type, cand, newSL)) { newSL = cand; why = "FASTLOCK"; }
      }
      if(InpTrailEnabled && fav >= risk * InpTrailStartR)
      {
         double cand2 = price - dir * atr * InpTrailAtr;
         if(Better(type, cand2, newSL)) { newSL = cand2; why = "TRAIL"; }
      }
      if(InpTpExtendEnabled && tp > 0.0)
      {
         double total = dir * (tp - open);
         double rem = dir * (tp - price);
         string kx = "INFX_" + IntegerToString(tk);
         int ext = (GlobalVariableCheck(kx) ? (int)GlobalVariableGet(kx) : 0);
         if(total > 0.0 && rem <= total * (1.0 - InpTpExtendAtPct / 100.0) && adx >= InpTpExtendAdx && ext < InpTpExtendMax)
         {
            newTP = tp + dir * atr * InpTpExtendAtr;
            double cand3 = open + dir * risk * InpTpExtendLockR;
            if(Better(type, cand3, newSL)) newSL = cand3;
            why = (why == "" ? "TPEXT" : why + "+TPEXT");
            GlobalVariableSet(kx, ext + 1);
            g_ext++;
         }
      }
      // validar distancia al mercado
      if(newSL != sl)
      {
         bool valid = (type == OP_BUY ? newSL <= bid - minStop : newSL >= ask + minStop);
         if(!valid) newSL = sl;
         else if(sl > 0.0 && MathAbs(newSL - sl) < atr * InpMinStepAtr && newTP == tp) newSL = sl;
      }
      if(newSL != sl || newTP != tp)
      {
         if(ModifyOrd(tk, newSL, newTP, why) && newSL != sl) g_locks++;
         g_lastMod[idx] = TimeCurrent();
      }
   }
}

//--- add-ons apalancados financiados con ganancia asegurada
void TryAddOns()
{
   if(!InpAddOnEnabled) return;
   if(CountOrders(-1, 1) >= InpMaxAddOns) return;
   double atr = iATR(g_sym, InpTF, InpAtrPeriod, 1);
   if(atr <= 0.0) return;
   if(iADX(g_sym, InpTF, 14, PRICE_CLOSE, MODE_MAIN, 1) < InpAddOnMinAdx) return;
   double spread = SpreadPx();
   if(spread > InpMaxSpreadPts * g_pt) return;
   if(!IsTradeAllowed() || !IsExpertEnabled() || !HourOk()) return;
   double bid = MarketInfo(g_sym, MODE_BID);
   double ask = MarketInfo(g_sym, MODE_ASK);
   double v = ValPerUnit();
   double minStop = MinStopDist();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != g_sym || OrderMagicNumber() != InpMagic) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      if(IsLev(OrderComment())) continue;
      int tk = OrderTicket();
      int idx = TrkFind(tk, true);
      if(idx < 0) continue;
      double risk = GetRisk(tk, idx, atr);
      double dir = (type == OP_BUY ? 1.0 : -1.0);
      double open = OrderOpenPrice();
      double sl = OrderStopLoss();
      double price = (type == OP_BUY ? bid : ask);
      double lots0 = OrderLots();
      if(sl <= 0.0) continue;
      double fav = dir * (price - open);
      double lockedPx = dir * (sl - open);
      if(fav < risk * InpAddOnMinR) continue;
      if(lockedPx < risk * InpAddOnMinLockR) continue;
      string ka = "INFA_" + IntegerToString(tk);
      int done = (GlobalVariableCheck(ka) ? (int)GlobalVariableGet(ka) : 0);
      if(done >= InpAddOnPerScout) continue;

      double lockedMoney = lockedPx * lots0 * v;
      double fund = lockedMoney * InpAddOnFundingPct / 100.0;
      double slDist = MathMax(InpMinSLPts * g_pt * InpAddOnSlMult, MathMin(InpMaxSLPts * g_pt, risk * InpAddOnSlMult));
      if(slDist < minStop + g_pt) continue;
      double lots = CalcLots(slDist, fund, false);
      if(lots <= 0.0) { continue; }
      double capLots = NormalizeDouble(MathFloor(lots0 * InpAddOnMaxLotMult / MarketInfo(g_sym, MODE_LOTSTEP) + 1e-9) * MarketInfo(g_sym, MODE_LOTSTEP), 2);
      if(lots > capLots) lots = capLots;
      if(lots < MarketInfo(g_sym, MODE_MINLOT)) continue;
      if(spread > slDist * InpMaxSpreadPctSL / 100.0) continue;
      if(!MarginOk(type, lots)) continue;
      double tpDist = MathMax(atr * InpAddOnTpAtr, minStop + g_pt);

      int r = OpenOrder(type, lots, slDist, tpDist, "Inf LEV v" + EA_VER);
      if(r > 0)
      {
         GlobalVariableSet(ka, done + 1);
         g_addons++;
         Print("ADDON_OPEN | ticket=", r, " parent=", tk, " ", (type == OP_BUY ? "BUY" : "SELL"), " lots=", DoubleToString(lots, 2),
               " lockedUSD=", DoubleToString(lockedMoney, 2), " riskUSD=", DoubleToString(lots * slDist * v, 2),
               " slPts=", DoubleToString(slDist / g_pt, 0));
         return;   // un add-on por revision
      }
      GlobalVariableSet(ka, done + 1);   // evita reintentos infinitos si falla
   }
}

//--- registra cierres
void TrackClosed()
{
   for(int i = 0; i < MAXT; i++)
   {
      int tk = g_tk[i];
      if(tk == 0) continue;
      if(!OrderSelect(tk, SELECT_BY_TICKET)) continue;
      if(OrderCloseTime() == 0) continue;
      double net = OrderProfit() + OrderSwap() + OrderCommission();
      string cm = OrderComment();
      double risk = (g_risk[i] > 0.0 ? g_risk[i] : 1.0);
      if(net > 0.0) g_wins++; else g_losses++;
      g_net += net;
      Print("TRADE_CLOSED | ticket=", tk, " ", (OrderType() == OP_BUY ? "BUY" : "SELL"), (IsLev(cm) ? " ADDON" : " BASE"),
            " lots=", DoubleToString(OrderLots(), 2), " net=", DoubleToString(net, 2),
            " peakR=", DoubleToString(g_peak[i] / risk, 2), " heldMin=", (int)((OrderCloseTime() - OrderOpenTime()) / 60),
            " exit=", (StringFind(cm, "[tp]") >= 0 ? "TP" : (StringFind(cm, "[sl]") >= 0 ? "SL_OR_LOCK" : "OTHER")),
            " | daySession wins=", g_wins, " losses=", g_losses, " net=", DoubleToString(g_net, 2));
      GlobalVariableDel("INFR_" + IntegerToString(tk));
      GlobalVariableDel("INFX_" + IntegerToString(tk));
      GlobalVariableDel("INFA_" + IntegerToString(tk));
      g_tk[i] = 0;
   }
}

int Signal()
{
   double ema = iMA(g_sym, InpTF, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double up  = iBands(g_sym, InpTF, InpBBPeriod, InpBBDeviation, 0, PRICE_CLOSE, MODE_UPPER, 1);
   double lo  = iBands(g_sym, InpTF, InpBBPeriod, InpBBDeviation, 0, PRICE_CLOSE, MODE_LOWER, 1);
   double c1  = iClose(g_sym, InpTF, 1);
   double o1  = iOpen(g_sym, InpTF, 1);
   if(c1 > up && c1 > ema && c1 > o1) return(OP_BUY);
   if(c1 < lo && c1 < ema && c1 < o1) return(OP_SELL);
   return(-1);
}

void Panel()
{
   if(TimeCurrent() - g_lastPanel < 5) return;
   g_lastPanel = TimeCurrent();
   string s = "INFINITY IMPULSE v" + EA_VER + " | " + g_sym + " " + EnumToString(InpTF) + "\n";
   s += "Spread: " + DoubleToString(SpreadPx() / g_pt, 0) + " pts | ATR: " + DoubleToString(iATR(g_sym, InpTF, InpAtrPeriod, 1) / g_pt, 0) + " pts\n";
   s += "Base: " + IntegerToString(CountOrders(-1, 0)) + "/" + IntegerToString(InpMaxScouts) + " | Add-ons: " + IntegerToString(CountOrders(-1, 1)) + "/" + IntegerToString(InpMaxAddOns) + "\n";
   s += "Sesion: " + IntegerToString(g_wins) + "G/" + IntegerToString(g_losses) + "P neto " + DoubleToString(g_net, 2) + "\n";
   s += "Entradas " + IntegerToString(g_opened) + " | Addons " + IntegerToString(g_addons) + " | SL movidos " + IntegerToString(g_locks) + " | TP ext " + IntegerToString(g_ext);
   Comment(s);
}

//+------------------------------------------------------------------+
int OnInit()
{
   ArrayInitialize(g_tk, 0);
   ArrayInitialize(g_peak, 0.0);
   ArrayInitialize(g_risk, 0.0);
   ArrayInitialize(g_lastMod, 0);
   g_sym = DetectSymbol();
   if(g_sym == "")
   {
      Print("INFINITY_INIT_FAIL | no se encontro simbolo de oro. Escribe el nombre exacto en InpSymbol (Observacion de mercado).");
      Alert("Infinity: simbolo de oro no encontrado. Define InpSymbol.");
      return(INIT_FAILED);
   }
   g_dig = (int)MarketInfo(g_sym, MODE_DIGITS);
   g_pt = MarketInfo(g_sym, MODE_POINT);
   g_lastBar = iTime(g_sym, InpTF, 0);   // no operar la vela en curso al cargar
   // recuperar ordenes abiertas
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == g_sym && OrderMagicNumber() == InpMagic) TrkFind(OrderTicket(), true);
   Print("INFINITY_INIT | v", EA_VER, " symbol=", g_sym, " digits=", g_dig, " point=", DoubleToString(g_pt, g_dig),
         " minSLusd=", DoubleToString(InpMinSLPts * g_pt, 2), " stopLevelPts=", DoubleToString(MarketInfo(g_sym, MODE_STOPLEVEL), 0),
         " spreadPts=", DoubleToString(SpreadPx() / g_pt, 0), " minLot=", DoubleToString(MarketInfo(g_sym, MODE_MINLOT), 2),
         " lotStep=", DoubleToString(MarketInfo(g_sym, MODE_LOTSTEP), 2), " riskUSD=", DoubleToString(RiskMoneyForEntry(), 2),
         " magic=", InpMagic);
   int nb = iBars(g_sym, InpTF);
   Print("INFINITY_DATA | mode=", (IsTesting() ? "TESTER" : "LIVE"), " tf=", EnumToString(InpTF), " bars=", nb,
         " firstBar=", (nb > 0 ? TimeToString(iTime(g_sym, InpTF, nb - 1), TIME_DATE) : "n/a"),
         " spreadPts=", DoubleToString(SpreadPx() / g_pt, 0), " maxSpreadPts=", DoubleToString(InpMaxSpreadPts, 0),
         " maxSpreadPctSL=", DoubleToString(InpMaxSpreadPctSL, 0));
   if(SpreadPx() > InpMaxSpreadPts * g_pt)
      Print("INFINITY_WARNING | el spread actual (", DoubleToString(SpreadPx() / g_pt, 0), " pts) supera InpMaxSpreadPts (", DoubleToString(InpMaxSpreadPts, 0),
            "). Si esto es el probador, fija el campo Spread en un valor realista (25-35) o no habra operaciones.");
   if(IsTesting() && nb < 20000)
      Print("INFINITY_WARNING | solo ", nb, " barras de ", EnumToString(InpTF), ": el backtest cubre poco tiempo. Descarga mas historial (F2).");
   Print("INFINITY_CONFIG | lock=", InpLockEnabled, " trigR=", DoubleToString(InpLockTriggerR, 2), " keepPct=", DoubleToString(InpLockKeepPct, 0),
         " trail=", InpTrailEnabled, " tpExtend=", InpTpExtendEnabled, " addOn=", InpAddOnEnabled, " maxScouts=", InpMaxScouts,
         " maxPerDir=", InpMaxPerDirection, " maxAddOns=", InpMaxAddOns);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Comment("");
   Print("INFINITY_DEINIT | reason=", reason, " opened=", g_opened, " addons=", g_addons, " slMoves=", g_locks, " tpExt=", g_ext,
         " wins=", g_wins, " losses=", g_losses, " net=", DoubleToString(g_net, 2));
   Print("INFINITY_DIAG | signals=", g_signals, " (buy=", g_buySig, " sell=", g_sellSig, ") entryFails=", g_entryFails, " skips: ", SkipSummary());
}

void OnTick()
{
   if(g_sym == "") return;
   ManagePositions();
   TrackClosed();

   datetime bt = iTime(g_sym, InpTF, 0);
   if(bt > 0 && bt != g_lastBar)
   {
      g_lastBar = bt;
      g_tries = 0;
      g_pending = Signal();
      if(g_pending == OP_BUY) { g_signals++; g_buySig++; }
      if(g_pending == OP_SELL) { g_signals++; g_sellSig++; }
      if(g_pending >= 0) Print("SIGNAL | ", (g_pending == OP_BUY ? "BUY" : "SELL"), " bar=", TimeToString(bt, TIME_DATE | TIME_MINUTES));
   }
   if(g_pending >= 0)
   {
      if(TimeCurrent() - g_lastBar > InpEntryWindowSec || g_tries >= InpMaxRetriesBar) g_pending = -1;
      else
      {
         int r = TryEnter(g_pending);
         if(r >= 0) g_pending = -1;
         else g_tries++;
      }
   }
   if(TimeCurrent() - g_lastAddCheck >= 3)
   {
      g_lastAddCheck = TimeCurrent();
      TryAddOns();
   }
   if(TimeCurrent() - g_lastSummary >= 3600)
   {
      g_lastSummary = TimeCurrent();
      Print("INFINITY_SUMMARY | opened=", g_opened, " addons=", g_addons, " slMoves=", g_locks, " tpExt=", g_ext,
            " wins=", g_wins, " losses=", g_losses, " net=", DoubleToString(g_net, 2),
            " balance=", DoubleToString(AccountBalance(), 2), " equity=", DoubleToString(AccountEquity(), 2),
            " | signals=", g_signals, " skips: ", SkipSummary());
   }
   Panel();
}
//+------------------------------------------------------------------+
