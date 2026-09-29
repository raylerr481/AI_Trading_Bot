#property strict
#property version   "1.35"
#property description "Bitey IA adaptive strategy-spectrum EA. Research-first, local Risk Gate authoritative."

#include <AI_Bridge.mqh>
#include <Market_Regime.mqh>
#include <Trading_Metrics.mqh>
#include <Strategy_Spectrum.mqh>

enum AIIntegrationMode
{
   AI_OFF=0,
   AI_ASSIST=1,
   AI_FILTER=2
};

input AIIntegrationMode InpAIMode=AI_ASSIST;
input string InpAIEndpoint="https://bitey-ia-suprabrain.onrender.com/api/v2/trading/analyze";
input string InpAIAuthToken="";
input int InpAITimeoutMs=5000;
input double InpAIMinConfidence=0.60;

input int InpAuditBars=1500;
input int InpAuditHorizonBars=15;
input double InpAuditSLMult=1.30;
input double InpAuditTPMult=2.60;
input int InpAuditRefreshBars=20;

input bool InpAllowBuy=true;
input bool InpAllowSell=true;
input double InpRiskPct=0.25;
input int InpMaxTrades=1;
input int InpMaxSpreadPoints=30;
input double InpMaxSpreadATRRatio=0.20;
input int InpATRPeriod=14;
input double InpMinATRPoints=20.0;
input int InpADXPeriod=14;
input double InpADXMin=20.0;
input int InpRSIPeriod=14;
input int InpFastEMA=8;
input int InpSlowEMA=21;
input int InpMacroEMA=200;
input double InpSLMult=1.30;
input double InpTPMult=2.60;
input int InpStartHour=7;
input int InpEndHour=20;
input int InpCooldownBars=3;
input int InpMagicNumber=8883200;
input bool InpWriteCSV=true;
input string InpCSVFile="AI_Trading_Bot_v1.35_Bitey.csv";
input bool InpAutoReport=true;
input bool InpEnableExecution=false;
input string InpAdaptiveReportFile="BiteyAdaptiveReport.tch";
input bool InpEnableSBTReport=true;
input string InpSBTEndpoint="";
input string InpSBTToken="";
input int InpSBTTimeoutMs=5000;

TradingMetrics g_metrics;
StrategyAudit g_audits[STRATEGY_COUNT];
int g_best_strategy=-1;
int g_last_audit_bars=-1;
datetime g_last_bar=0;
datetime g_last_entry_time=0;
MarketRegime g_regime=REGIME_UNKNOWN;

string TFName()
{
   if(Period()==PERIOD_M1) return "M1";
   if(Period()==PERIOD_M5) return "M5";
   if(Period()==PERIOD_M15) return "M15";
   if(Period()==PERIOD_M30) return "M30";
   if(Period()==PERIOD_H1) return "H1";
   if(Period()==PERIOD_H4) return "H4";
   if(Period()==PERIOD_D1) return "D1";
   return IntegerToString(Period());
}

bool NewBar()
{
   if(Time[0]==g_last_bar) return false;
   g_last_bar=Time[0];
   return true;
}

double SpreadPoints()
{
   return (Ask-Bid)/Point;
}

int OpenTrades()
{
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderSymbol()==Symbol())
         if(OrderMagicNumber()==InpMagicNumber && (OrderType()==OP_BUY || OrderType()==OP_SELL)) n++;
   return n;
}

bool SessionOK()
{
   int h=TimeHour(TimeCurrent());
   return (h>=InpStartHour && h<InpEndHour);
}

bool CooldownOK()
{
   if(g_last_entry_time==0) return true;
   int bars_since=iBarShift(Symbol(),Period(),g_last_entry_time,false);
   return (bars_since<0 || bars_since>=InpCooldownBars);
}

double LotsForRisk(double sl_points)
{
   if(sl_points<=0.0) return 0.0;

   double risk_money=AccountBalance()*InpRiskPct/100.0;
   double tick_value=MarketInfo(Symbol(),MODE_TICKVALUE);
   double tick_size=MarketInfo(Symbol(),MODE_TICKSIZE);
   if(tick_value<=0.0 || tick_size<=0.0) return 0.0;

   double loss_per_lot=(sl_points*Point/tick_size)*tick_value;
   if(loss_per_lot<=0.0) return 0.0;

   double raw=risk_money/loss_per_lot;
   double step=MarketInfo(Symbol(),MODE_LOTSTEP);
   double minlot=MarketInfo(Symbol(),MODE_MINLOT);
   double maxlot=MarketInfo(Symbol(),MODE_MAXLOT);
   if(step<=0.0) step=0.01;

   raw=MathFloor(raw/step)*step;
   raw=MathMax(minlot,MathMin(maxlot,raw));
   return NormalizeDouble(raw,2);
}

void WriteCSVHeader()
{
   if(!InpWriteCSV) return;
   int h=FileOpen(InpCSVFile,FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(h==INVALID_HANDLE) return;

   if(FileSize(h)==0)
      FileWrite(h,"time","symbol","tf","regime","hurst","best_strategy","best_score",
                "balance","equity","dd_pct","floating_pl","open_trades","closed_trades",
                "win_rate","profit_factor","expectancy","spread_points","atr_points","adx",
                "ai_ok","ai_action","ai_confidence","ai_risk_allowed","ai_strategy","ai_reason");

   FileClose(h);
}

void WriteCSV(AITradingSignal &ai,bool ai_ok)
{
   if(!InpWriteCSV) return;
   int h=FileOpen(InpCSVFile,FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(h==INVALID_HANDLE) return;

   FileSeek(h,0,SEEK_END);
   FileWrite(h,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),Symbol(),TFName(),
             RegimeName(g_regime),g_metrics.hurst,g_metrics.best_strategy,g_metrics.best_strategy_score,
             g_metrics.balance,g_metrics.equity,g_metrics.drawdown_pct,g_metrics.floating_pl,
             g_metrics.open_trades,g_metrics.closed_trades,g_metrics.win_rate,g_metrics.profit_factor,
             g_metrics.expectancy,g_metrics.spread_points,g_metrics.atr_points,g_metrics.adx,
             ai_ok,ai.action,ai.confidence,ai.risk_allowed,ai.strategy,ai.reason);
   FileClose(h);
}

void WriteAdaptiveReport()
{
   if(!InpAutoReport) return;

   int h=FileOpen(InpAdaptiveReportFile,FILE_TXT|FILE_WRITE|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;

   FileWrite(h,"BITEY_ADAPTIVE_REPORT_V1");
   FileWrite(h,"time=",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
   FileWrite(h,"symbol=",Symbol());
   FileWrite(h,"timeframe=",TFName());
   FileWrite(h,"regime=",RegimeName(g_regime));
   FileWrite(h,"hurst=",DoubleToString(g_metrics.hurst,6));
   FileWrite(h,"best_strategy=",g_metrics.best_strategy);
   FileWrite(h,"best_score=",DoubleToString(g_metrics.best_strategy_score,6));
   FileWrite(h,"balance=",DoubleToString(g_metrics.balance,2));
   FileWrite(h,"equity=",DoubleToString(g_metrics.equity,2));
   FileWrite(h,"drawdown_pct=",DoubleToString(g_metrics.drawdown_pct,4));
   FileWrite(h,"profit_factor=",DoubleToString(g_metrics.profit_factor,6));
   FileWrite(h,"expectancy=",DoubleToString(g_metrics.expectancy,6));

   for(int s=0;s<STRATEGY_COUNT;s++)
   {
      FileWrite(h,"strategy=",StrategyName(s),
                "|trades=",IntegerToString(g_audits[s].trades),
                "|wins=",IntegerToString(g_audits[s].wins),
                "|losses=",IntegerToString(g_audits[s].losses),
                "|win_rate=",DoubleToString(g_audits[s].win_rate,4),
                "|profit_factor=",DoubleToString(g_audits[s].profit_factor,6),
                "|expectancy=",DoubleToString(g_audits[s].expectancy,6),
                "|max_drawdown=",DoubleToString(g_audits[s].max_drawdown,6),
                "|score=",DoubleToString(g_audits[s].score,6),
                "|oos_trades=",IntegerToString(g_audits[s].validation_trades),
                "|oos_wins=",IntegerToString(g_audits[s].validation_wins),
                "|oos_pf=",DoubleToString(g_audits[s].validation_pf,6),
                "|oos_expectancy=",DoubleToString(g_audits[s].validation_expectancy,6),
                "|oos_drawdown=",DoubleToString(g_audits[s].validation_drawdown,6));
   }

   FileWrite(h,"NOTE=Research artifact only; not encrypted and not a profitability guarantee.");
   FileClose(h);
}

string JsonSafe(string value)
{
   StringReplace(value,"\\","\\\\");
   StringReplace(value,"\"","\\\"");
   return value;
}

void SendSBTReport(AITradingSignal &ai,bool ai_ok)
{
   if(!InpEnableSBTReport || InpSBTEndpoint=="") return;

   string url=InpSBTEndpoint;
   if(StringSubstr(url,StringLen(url)-1,1)=="/")
      url=StringSubstr(url,0,StringLen(url)-1);
   url=url+"/api/v1/mt4/bitey-report";

   string headers="Content-Type: application/json\\r\\n";
   if(InpSBTToken!="")
      headers=headers+"X-MT4-Token: "+InpSBTToken+"\\r\\n";

   string body="{";
   body+="\"source\":\"AI_Trading_Bot_v1.35_Bitey\",";
   body+="\"symbol\":\""+JsonSafe(Symbol())+"\",";
   body+="\"timeframe\":\""+JsonSafe(TFName())+"\",";
   body+="\"timestamp\":\""+JsonSafe(TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS))+"\",";
   body+="\"mode\":\""+IntegerToString(InpAIMode)+"\",";
   body+="\"execution_enabled\":"+string(InpEnableExecution?"true":"false")+",";
   body+="\"regime\":\""+JsonSafe(RegimeName(g_regime))+"\",";
   body+="\"hurst\":"+DoubleToString(g_metrics.hurst,6)+",";
   body+="\"best_strategy\":\""+JsonSafe(g_metrics.best_strategy)+"\",";
   body+="\"best_score\":"+DoubleToString(g_metrics.best_strategy_score,6)+",";
   body+="\"metrics\":{";
   body+="\"balance\":"+DoubleToString(g_metrics.balance,2)+",";
   body+="\"equity\":"+DoubleToString(g_metrics.equity,2)+",";
   body+="\"drawdown_pct\":"+DoubleToString(g_metrics.drawdown_pct,4)+",";
   body+="\"profit_factor\":"+DoubleToString(g_metrics.profit_factor,6)+",";
   body+="\"expectancy\":"+DoubleToString(g_metrics.expectancy,6)+",";
   body+="\"win_rate\":"+DoubleToString(g_metrics.win_rate,4)+",";
   body+="\"closed_trades\":"+IntegerToString(g_metrics.closed_trades)+",";
   body+="\"open_trades\":"+IntegerToString(g_metrics.open_trades)+",";
   body+="\"spread_points\":"+DoubleToString(g_metrics.spread_points,2)+",";
   body+="\"atr_points\":"+DoubleToString(g_metrics.atr_points,2)+",";
   body+="\"adx\":"+DoubleToString(g_metrics.adx,4)+"},";
   body+="\"ai\":{";
   body+="\"ok\":"+string(ai_ok?"true":"false")+",";
   body+="\"action\":\""+JsonSafe(ai.action)+"\",";
   body+="\"confidence\":"+DoubleToString(ai.confidence,6)+",";
   body+="\"risk_allowed\":"+string(ai.risk_allowed?"true":"false")+",";
   body+="\"strategy\":\""+JsonSafe(ai.strategy)+"\",";
   body+="\"reason\":\""+JsonSafe(ai.reason)+"\"},";
   body+="\"risk_gate\":{\"execution_enabled\":"+string(InpEnableExecution?"true":"false")+",\"local_authority\":true},";
   body+="\"report_type\":\"live_snapshot\"";
   body+="}";

   char data[];
   char result[];
   StringToCharArray(body,data,0,StringLen(body));
   ResetLastError();
   int code=WebRequest("POST",url,headers,InpSBTTimeoutMs,data,result,headers);
   if(code<200 || code>=300)
      Print("Bitey SBT report unavailable code=",IntegerToString(code)," err=",IntegerToString(GetLastError()));
}

void UpdateRadar(AITradingSignal &ai,bool ai_ok)
{
   string text="BITEY IA / SBT TRADING RADAR\\n";
   text+="--------------------------------\\n";
   text+=Symbol()+" "+TFName()+" | "+RegimeName(g_regime)+" | H="+DoubleToString(g_metrics.hurst,3)+"\\n";
   text+="Best: "+g_metrics.best_strategy+" | Score="+DoubleToString(g_metrics.best_strategy_score,2)+"\\n";
   text+="PF="+DoubleToString(g_metrics.profit_factor,2)+" | Exp="+DoubleToString(g_metrics.expectancy,4);
   text+=" | Win="+DoubleToString(g_metrics.win_rate,1)+"% | DD="+DoubleToString(g_metrics.drawdown_pct,2)+"%\\n";
   text+="Trades="+IntegerToString(g_metrics.closed_trades)+" | Equity="+DoubleToString(g_metrics.equity,2)+"\\n";
   text+="AI: "+(ai_ok ? ai.action : "OFFLINE")+" | Conf="+DoubleToString(ai.confidence*100.0,1)+"%";
   text+=" | Risk="+(ai.risk_allowed ? "ALLOW" : "BLOCK")+"\\n";
   text+="SBT: "+(InpSBTEndpoint=="" ? "NOT CONFIGURED" : "REPORT ENABLED");
   Comment(text);
}

void RefreshAudit()
{
   if(Bars<InpAuditBars+30) return;
   if(g_last_audit_bars>=0 && MathAbs(Bars-g_last_audit_bars)<InpAuditRefreshBars) return;

   for(int i=0;i<STRATEGY_COUNT;i++)
      AuditStrategy(Symbol(),Period(),i,InpAuditBars,InpAuditHorizonBars,
                    InpAuditSLMult,InpAuditTPMult,g_audits[i]);

   g_best_strategy=-1;
   SelectBestStrategy(g_audits,g_best_strategy);

   if(g_best_strategy>=0)
   {
      g_metrics.best_strategy=StrategyName(g_best_strategy);
      g_metrics.best_strategy_score=g_audits[g_best_strategy].score;
   }

   g_last_audit_bars=Bars;
   WriteAdaptiveReport();

   if(InpAutoReport)
   {
      Print("Bitey walk-forward audit: best=",g_metrics.best_strategy,
            " score=",DoubleToString(g_metrics.best_strategy_score,3));
      for(int s=0;s<STRATEGY_COUNT;s++)
         Print("  ",StrategyName(s),
               " trainExp=",DoubleToString(g_audits[s].expectancy,5),
               " trainPF=",DoubleToString(g_audits[s].profit_factor,2),
               " OOS trades=",g_audits[s].validation_trades,
               " OOS win=",DoubleToString(g_audits[s].validation_trades>0 ? 100.0*g_audits[s].validation_wins/g_audits[s].validation_trades : 0.0,1),
               "% OOS PF=",DoubleToString(g_audits[s].validation_pf,2),
               " OOS exp=",DoubleToString(g_audits[s].validation_expectancy,5),
               " OOS DD=",DoubleToString(g_audits[s].validation_drawdown,5));
      for(int s=0;s<STRATEGY_COUNT;s++)
         Print("  ",StrategyName(s),
               " trades=",g_audits[s].trades,
               " win=",DoubleToString(g_audits[s].win_rate,1),
               "% PF=",DoubleToString(g_audits[s].profit_factor,2),
               " exp=",DoubleToString(g_audits[s].expectancy,5),
               " DD=",DoubleToString(g_audits[s].max_drawdown,5),
               " score=",DoubleToString(g_audits[s].score,3));
   }
}

void RefreshMarketState()
{
   double atr=iATR(Symbol(),Period(),InpATRPeriod,1);
   double adx=iADX(Symbol(),Period(),InpADXPeriod,PRICE_CLOSE,MODE_MAIN,1);
   double fast=iMA(Symbol(),Period(),InpFastEMA,0,MODE_EMA,PRICE_CLOSE,1);
   double slow=iMA(Symbol(),Period(),InpSlowEMA,0,MODE_EMA,PRICE_CLOSE,1);
   double macro=iMA(Symbol(),Period(),InpMacroEMA,0,MODE_EMA,PRICE_CLOSE,1);
   double macro_prev=iMA(Symbol(),Period(),InpMacroEMA,0,MODE_EMA,PRICE_CLOSE,2);

   double atr_points=(Point>0.0 ? atr/Point : 0.0);
   g_regime=DetectMarketRegime(atr_points,adx,fast,slow,macro,macro_prev,
                                InpMinATRPoints,InpADXMin);

   g_metrics.last_regime=(int)g_regime;
   g_metrics.hurst=EstimateHurst(Symbol(),Period(),1,64);
}

bool LocalSignal(int &dir,int &score,int &score_gap)
{
   dir=0; score=0; score_gap=0;
   if(g_best_strategy<0) return false;

   int candidate=StrategySignal(Symbol(),Period(),1,g_best_strategy);
   if(candidate==0) return false;

   if(g_regime==REGIME_UPTREND && candidate<0) return false;
   if(g_regime==REGIME_DOWNTREND && candidate>0) return false;
   if(g_regime==REGIME_RANGE && (g_best_strategy==0 || g_best_strategy==3)) return false;

   dir=candidate;
   score=(int)MathRound(g_audits[g_best_strategy].score);

   double second=-999999.0;
   for(int i=0;i<STRATEGY_COUNT;i++)
      if(i!=g_best_strategy && g_audits[i].trades>=10)
         second=MathMax(second,g_audits[i].score);

   if(second>-999999.0)
      score_gap=(int)MathRound(g_audits[g_best_strategy].score-second);

   return true;
}

bool AIAllows(int dir,AITradingSignal &ai,bool &ai_ok)
{
   ai_ok=false;
   ai.action="HOLD";
   ai.confidence=0.0;
   ai.risk_allowed=false;
   ai.strategy="none";
   ai.reason="AI disabled.";

   if(InpAIMode==AI_OFF) return true;

   double atr=iATR(Symbol(),Period(),InpATRPeriod,1);
   double atr_points=(Point>0.0 ? atr/Point : 0.0);
   double spread=SpreadPoints();
   double ratio=(atr_points>0.0 ? spread/atr_points : 999.0);
   double adx=iADX(Symbol(),Period(),InpADXPeriod,PRICE_CLOSE,MODE_MAIN,1);
   double rsi=iRSI(Symbol(),Period(),InpRSIPeriod,PRICE_CLOSE,1);
   double fast=iMA(Symbol(),Period(),InpFastEMA,0,MODE_EMA,PRICE_CLOSE,1);
   double slow=iMA(Symbol(),Period(),InpSlowEMA,0,MODE_EMA,PRICE_CLOSE,1);
   double macro=iMA(Symbol(),Period(),InpMacroEMA,0,MODE_EMA,PRICE_CLOSE,1);
   double macro_prev=iMA(Symbol(),Period(),InpMacroEMA,0,MODE_EMA,PRICE_CLOSE,2);
   double htf_fast=iMA(Symbol(),PERIOD_H4,InpFastEMA,0,MODE_EMA,PRICE_CLOSE,1);
   double htf_slow=iMA(Symbol(),PERIOD_H4,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE,1);

   string htf=(htf_fast>htf_slow ? "UP" : (htf_fast<htf_slow ? "DOWN" : "FLAT"));
   int local_score=(g_best_strategy>=0 ? (int)MathRound(g_audits[g_best_strategy].score) : 0);
   int gap=0;

   for(int k=0;k<STRATEGY_COUNT;k++)
      if(k!=g_best_strategy && g_audits[k].trades>=10)
         gap=MathMax(gap,local_score-(int)MathRound(g_audits[k].score));

   ai_ok=AIAnalyzeSnapshot(
      InpAIEndpoint,InpAIAuthToken,Symbol(),TFName(),
      Bid,Ask,spread,ratio,atr_points,adx,rsi,fast,slow,macro,
      macro-macro_prev,Close[1],Close[2],local_score,gap,htf,
      RegimeName(g_regime),InpAITimeoutMs,ai);

   if(InpAIMode==AI_ASSIST) return true;

   if(!ai_ok) return false;
   if(!ai.risk_allowed || ai.confidence<InpAIMinConfidence) return false;
   if(dir>0 && ai.action!="BUY") return false;
   if(dir<0 && ai.action!="SELL") return false;

   return true;
}

void TryTrade()
{
   if(!InpEnableExecution) return;
   if(OpenTrades()>=InpMaxTrades) return;
   if(!SessionOK() || !CooldownOK()) return;
   if(SpreadPoints()>InpMaxSpreadPoints) return;

   double atr=iATR(Symbol(),Period(),InpATRPeriod,1);
   if(atr<=0.0 || atr/Point<InpMinATRPoints) return;
   if(SpreadPoints()/(atr/Point)>InpMaxSpreadATRRatio) return;

   int dir,score,gap;
   if(!LocalSignal(dir,score,gap)) return;
   if(dir>0 && !InpAllowBuy) return;
   if(dir<0 && !InpAllowSell) return;

   AITradingSignal ai;
   bool ai_ok=false;
   if(!AIAllows(dir,ai,ai_ok)) return;

   double sl_dist=InpSLMult*atr;
   double tp_dist=InpTPMult*atr;
   double lots=LotsForRisk(sl_dist/Point);
   if(lots<=0.0) return;

   int ticket=-1;
   ResetLastError();

   if(dir>0)
      ticket=OrderSend(Symbol(),OP_BUY,lots,Ask,5,Ask-sl_dist,Ask+tp_dist,
                       "BiteyIA_v1.35",InpMagicNumber,0,clrNONE);
   else
      ticket=OrderSend(Symbol(),OP_SELL,lots,Bid,5,Bid+sl_dist,Bid-tp_dist,
                       "BiteyIA_v1.34",InpMagicNumber,0,clrNONE);

   if(ticket>0) g_last_entry_time=TimeCurrent();

   WriteCSV(ai,ai_ok);
}

int OnInit()
{
   MetricsInit(g_metrics);
   WriteCSVHeader();
   RefreshMarketState();
   RefreshAudit();
   MetricsRefresh(g_metrics,Symbol(),Period());

   Print("Bitey IA v1.34 initialized. Best=",g_metrics.best_strategy,
         " score=",DoubleToString(g_metrics.best_strategy_score,3),
         " regime=",RegimeName(g_regime),
         " AI mode=",IntegerToString(InpAIMode));

   return INIT_SUCCEEDED;
}

void OnTick()
{
   MetricsRefresh(g_metrics,Symbol(),Period());
   RefreshMarketState();

   if(!NewBar()) return;

   RefreshAudit();
   AITradingSignal radar_ai;
   bool radar_ok=false;
   if(InpAIMode!=AI_OFF) radar_ok=AIAnalyzeSnapshot(InpAIEndpoint,InpAIAuthToken,Symbol(),TFName(),Bid,Ask,SpreadPoints(),(g_metrics.atr_points>0.0?SpreadPoints()/g_metrics.atr_points:999.0),g_metrics.atr_points,g_metrics.adx,iRSI(Symbol(),Period(),InpRSIPeriod,PRICE_CLOSE,1),iMA(Symbol(),Period(),InpFastEMA,0,MODE_EMA,PRICE_CLOSE,1),iMA(Symbol(),Period(),InpSlowEMA,0,MODE_EMA,PRICE_CLOSE,1),iMA(Symbol(),Period(),InpMacroEMA,0,MODE_EMA,PRICE_CLOSE,1),0,Close[1],Close[2],(int)MathRound(g_metrics.best_strategy_score),0,"FLAT",RegimeName(g_regime),InpAITimeoutMs,radar_ai);
   UpdateRadar(radar_ai,radar_ok);
   SendSBTReport(radar_ai,radar_ok);
   TryTrade();

   Print("BiteyIA | regime=",RegimeName(g_regime),
         " best=",g_metrics.best_strategy,
         " score=",DoubleToString(g_metrics.best_strategy_score,3),
         " equity=",DoubleToString(g_metrics.equity,2),
         " DD=",DoubleToString(g_metrics.drawdown_pct,2),
         "% PF=",DoubleToString(g_metrics.profit_factor,2),
         " expectancy=",DoubleToString(g_metrics.expectancy,4),
         " H=",DoubleToString(g_metrics.hurst,3));
}
