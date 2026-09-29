#ifndef __STRATEGY_SPECTRUM_MQH__
#define __STRATEGY_SPECTRUM_MQH__

#define STRATEGY_COUNT 8

string StrategyName(int id)
{
   if(id==0) return "TREND_FOLLOWING";
   if(id==1) return "MEAN_REVERSION";
   if(id==2) return "MOMENTUM";
   if(id==3) return "VOLATILITY_BREAKOUT";
   if(id==4) return "SESSION_BIAS";
   if(id==5) return "DIVERGENCE";
   if(id==6) return "STRICT_RANGE";
   if(id==7) return "FRACTAL_HTF";
   return "UNKNOWN";
}

struct StrategyAudit
{
   int trades;
   int wins;
   int losses;
   double net;
   double gross_profit;
   double gross_loss;
   double win_rate;
   double profit_factor;
   double expectancy;
   double avg_win;
   double avg_loss;
   double max_drawdown;
   double payoff;
   int max_consecutive_losses;
   double score;
   int validation_trades;
   int validation_wins;
   double validation_net;
   double validation_pf;
   double validation_expectancy;
   double validation_drawdown;
   double validation_score;
};

void ResetAudit(StrategyAudit &a)
{
   a.trades=0; a.wins=0; a.losses=0; a.net=0.0;
   a.gross_profit=0.0; a.gross_loss=0.0; a.win_rate=0.0;
   a.profit_factor=0.0; a.expectancy=0.0; a.avg_win=0.0;
   a.avg_loss=0.0; a.max_drawdown=0.0; a.payoff=0.0;
   a.max_consecutive_losses=0; a.score=0.0;
   a.validation_trades=0; a.validation_wins=0; a.validation_net=0.0;
   a.validation_pf=0.0; a.validation_expectancy=0.0; a.validation_drawdown=0.0;
   a.validation_score=0.0;
}

double ATRv(string s,int tf,int shift,int p=14){ return iATR(s,tf,p,shift); }
double ADXv(string s,int tf,int shift,int p=14){ return iADX(s,tf,p,PRICE_CLOSE,MODE_MAIN,shift); }
double RSIv(string s,int tf,int shift,int p=14){ return iRSI(s,tf,p,PRICE_CLOSE,shift); }
double EMAv(string s,int tf,int shift,int p){ return iMA(s,tf,p,0,MODE_EMA,PRICE_CLOSE,shift); }

int StrategySignal(string s,int tf,int shift,int id)
{
   double c=iClose(s,tf,shift), p=iClose(s,tf,shift+1);
   double atr=ATRv(s,tf,shift), adx=ADXv(s,tf,shift), rsi=RSIv(s,tf,shift);
   double fast=EMAv(s,tf,shift,8), slow=EMAv(s,tf,shift,21);
   double macro=EMAv(s,tf,shift,200);
   if(atr<=0.0) return 0;

   if(id==0)
   {
      if(fast>slow && c>macro && adx>=22.0) return 1;
      if(fast<slow && c<macro && adx>=22.0) return -1;
   }
   if(id==1)
   {
      if(rsi<=30.0 && c<fast-0.5*atr) return 1;
      if(rsi>=70.0 && c>fast+0.5*atr) return -1;
   }
   if(id==2)
   {
      if(c>p && c>iClose(s,tf,shift+3) && rsi>=55.0) return 1;
      if(c<p && c<iClose(s,tf,shift+3) && rsi<=45.0) return -1;
   }
   if(id==3)
   {
      double hi=iHigh(s,tf,iHighest(s,tf,MODE_HIGH,20,shift+1));
      double lo=iLow(s,tf,iLowest(s,tf,MODE_LOW,20,shift+1));
      if(c>hi && adx>=20.0) return 1;
      if(c<lo && adx>=20.0) return -1;
   }
   if(id==4)
   {
      datetime barTime=iTime(s,tf,shift);
      int h=TimeHour(barTime);
      // Use the actual daily open for the same historical day.
      // This avoids comparing against an arbitrary 20-bar reference.
      int dayShift=iBarShift(s,PERIOD_D1,barTime,false);
      if(dayShift<0) return 0;
      double dayOpen=iOpen(s,PERIOD_D1,dayShift);
      if(dayOpen<=0.0) return 0;

      if(h>=7 && h<=10 && c>dayOpen) return 1;
      if(h>=7 && h<=10 && c<dayOpen) return -1;
   }
   if(id==5)
   {
      double rsiPrev=RSIv(s,tf,shift+5);
      double cPrev=iClose(s,tf,shift+5);
      if(c<cPrev && rsi>rsiPrev+5.0 && rsi<45.0) return 1;
      if(c>cPrev && rsi<rsiPrev-5.0 && rsi>55.0) return -1;
   }
   if(id==6)
   {
      double hi=iHigh(s,tf,iHighest(s,tf,MODE_HIGH,30,shift+1));
      double lo=iLow(s,tf,iLowest(s,tf,MODE_LOW,30,shift+1));
      double width=hi-lo;
      if(width<=0.0) return 0;
      double mid=(hi+lo)/2.0;
      if(adx<20.0 && c<lo+0.20*width) return 1;
      if(adx<20.0 && c>hi-0.20*width) return -1;
      if(adx<20.0 && c<mid && rsi<45.0) return 1;
      if(adx<20.0 && c>mid && rsi>55.0) return -1;
   }
   if(id==7)
   {
      double htfFast=iMA(s,PERIOD_H4,8,0,MODE_EMA,PRICE_CLOSE,shift+1);
      double htfSlow=iMA(s,PERIOD_H4,21,0,MODE_EMA,PRICE_CLOSE,shift+1);
      double ph=iHigh(s,tf,shift+2), pc=iHigh(s,tf,shift+3);
      double pl=iLow(s,tf,shift+2), lc=iLow(s,tf,shift+3);
      if(ph>pc && ph>iHigh(s,tf,shift+1) && htfFast>htfSlow) return 1;
      if(pl<lc && pl<iLow(s,tf,shift+1) && htfFast<htfSlow) return -1;
   }
   return 0;
}

void FinalizeAudit(StrategyAudit &a)
{
   a.win_rate=(a.trades>0 ? 100.0*a.wins/a.trades : 0.0);
   a.profit_factor=(a.gross_loss>0.0 ? a.gross_profit/a.gross_loss : (a.gross_profit>0.0 ? 999.0 : 0.0));
   a.expectancy=(a.trades>0 ? a.net/a.trades : 0.0);
   a.avg_win=(a.wins>0 ? a.gross_profit/a.wins : 0.0);
   a.avg_loss=(a.losses>0 ? -a.gross_loss/a.losses : 0.0);
   a.payoff=(a.avg_loss!=0.0 ? a.avg_win/MathAbs(a.avg_loss) : 0.0);

   // Research score: profitability is required; drawdown and weak samples are penalized.
   // A strategy with non-positive expectancy cannot be promoted.
   double pf_component=MathMin(3.0,MathMax(0.0,a.profit_factor-1.0));
   double exp_component=MathMin(2.0,MathMax(0.0,a.expectancy));
   double dd_component=MathMin(3.0,MathMax(0.0,a.max_drawdown));
   double sample_component=MathMin(1.0,a.trades/50.0);
   a.score=exp_component+pf_component+sample_component-dd_component;
}

void EvaluateValidation(StrategyAudit &a)
{
   a.validation_expectancy=(a.validation_trades>0 ? a.validation_net/a.validation_trades : 0.0);
   a.validation_pf=(a.validation_net>0.0 && a.validation_expectancy>0.0 ? 1.0 : 0.0);
   // Validation score is deliberately conservative: OOS must have positive expectancy.
   a.validation_score=a.validation_expectancy;
}

bool SimulateWindow(string s,int tf,int id,int first_shift,int last_shift,int horizon,
                     double sl_mult,double tp_mult,int &trades,int &wins,double &net,
                     double &gross_profit,double &gross_loss,double &max_dd)
{
   trades=0; wins=0; net=0.0; gross_profit=0.0; gross_loss=0.0; max_dd=0.0;
   double equity=0.0,peak=0.0;

   for(int shift=first_shift;shift>=last_shift && shift>=horizon+2;shift--)
   {
      int dir=StrategySignal(s,tf,shift,id);
      if(dir==0) continue;
      double entry=iClose(s,tf,shift);
      double atr=ATRv(s,tf,shift);
      if(atr<=0.0) continue;

      double slDist=sl_mult*atr,tpDist=tp_mult*atr;
      bool resolved=false,win=false;
      double result=0.0;

      for(int f=shift-1;f>=shift-horizon && f>=1;f--)
      {
         double hi=iHigh(s,tf,f),lo=iLow(s,tf,f);
         if(dir>0)
         {
            if(lo<=entry-slDist){resolved=true;result=-slDist;break;}
            if(hi>=entry+tpDist){resolved=true;win=true;result=tpDist;break;}
         }
         else
         {
            if(hi>=entry+slDist){resolved=true;result=-slDist;break;}
            if(lo<=entry-tpDist){resolved=true;win=true;result=tpDist;break;}
         }
      }
      if(!resolved) continue;

      trades++; net+=result;
      if(result>0.0){wins++;gross_profit+=result;} else gross_loss+=MathAbs(result);
      equity+=result;
      if(equity>peak) peak=equity;
      max_dd=MathMax(max_dd,peak-equity);
   }
   return trades>0;
}

bool AuditStrategy(string s,int tf,int id,int bars_to_test,int horizon,
                   double sl_mult,double tp_mult,StrategyAudit &a)
{
   ResetAudit(a);
   int available=Bars(s,tf)-horizon-25;
   if(available<80) return false;

   int total=MathMin(bars_to_test,available);
   int validation_bars=MathMax(30,total/5);
   int train_first=total;
   int train_last=validation_bars+1;

   int trades,wins;
   double net,gp,gl,dd;
   if(!SimulateWindow(s,tf,id,train_first,train_last,horizon,sl_mult,tp_mult,
                      trades,wins,net,gp,gl,dd)) return false;

   a.trades=trades;a.wins=wins;a.losses=trades-wins;a.net=net;
   a.gross_profit=gp;a.gross_loss=gl;a.max_drawdown=dd;
   FinalizeAudit(a);

   // OOS validation is the newest, untouched segment.
   int vfirst=validation_bars;
   int vlast=2;
   int vt,vw;double vn,vgp,vgl,vdd;
   if(SimulateWindow(s,tf,id,vfirst,vlast,horizon,sl_mult,tp_mult,
                     vt,vw,vn,vgp,vgl,vdd))
   {
      a.validation_trades=vt;
      a.validation_wins=vw;
      a.validation_net=vn;
      a.validation_drawdown=vdd;
      a.validation_expectancy=(vt>0 ? vn/vt : 0.0);
      a.validation_pf=(vgl>0.0 ? vgp/vgl : (vgp>0.0 ? 999.0 : 0.0));
      a.validation_score=a.validation_expectancy;
   }
   return (a.trades>=10);
}
int SelectBestStrategy(StrategyAudit &audits[],int &bestId)
{
   bestId=-1;
   double best=-999999.0;
   for(int i=0;i<STRATEGY_COUNT;i++)
   {
      if(audits[i].trades<20) continue;
      if(audits[i].expectancy<=0.0) continue;
      if(audits[i].validation_trades<8) continue;
      if(audits[i].validation_expectancy<=0.0) continue;
      if(audits[i].validation_pf<1.05) continue;

      double robust_score=audits[i].validation_expectancy
                         +0.25*audits[i].score
                         -0.10*audits[i].validation_drawdown;
      if(robust_score>best) { best=robust_score; bestId=i; }
   }
   return bestId;
}

#endif
